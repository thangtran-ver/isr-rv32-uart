//======================================================================
//  isr_top.v -- Top module: PicoRV32 + ISR instruction decoder + LED demo
//  Board : Sipeed Tang Nano 4K  (GW1NSR-LV4CQN48PC6/I5, GW1NSR-4C)
//  Clock : 27 MHz (thach anh on-board, chan 45)
//
//  Y TUONG DEMO
//  ------------
//  BSRAM chua firmware DA MA HOA bang (ISR_KEY, ISR_MODE).
//  Moi lan CPU fetch lenh (mem_instr = 1), du lieu doc ra duoc XOR voi
//  key_eff = f(PC, KEY) do isr_decoder sinh ra  ->  lenh goc.
//
//    * Firmware ma hoa DUNG key  -> CPU chay -> LED nhay ~1 Hz
//    * Firmware ma hoa SAI key   -> lenh giai ma ra rac
//                                   -> picorv32 bat 'trap' (CATCH_ILLINSN)
//                                      hoac treo o dia chi khong hop le
//                                   -> LED TAT han
//
//  Hai co che phat hien "chuong trinh khong chay":
//    1) trap   : picorv32 gap lenh khong hop le / truy cap lech
//    2) alive  : watchdog ~1.24 s -- neu CPU khong ghi vao thanh ghi LED
//                thi coi nhu da chet (bat duoc ca truong hop code rac
//                chay vao vong lap vo han ma khong trap)
//
//  DUONG TOI HAN (timing)
//  ----------------------
//  MODE 3 = 3 vong PRF noi tiep, la duong to hop dai nhat cua thiet ke.
//  O day key_eff duoc TINH TRUOC va DUA QUA THANH GHI (key_eff_q):
//    - Chu ky N   : mem_addr on dinh -> tinh key_eff (ca 1 chu ky 37 ns)
//    - Chu ky N+1 : ram_rdata ^ key_eff_q  (chi con 1 tang XOR)
//  Hop le vi picorv32 giu mem_addr / mem_instr KHONG DOI tu luc
//  mem_valid=1 cho toi khi mem_ready=1.
//
//  BAN DO BO NHO
//  -------------
//    0x0000_0000 - 0x0000_1FFF   RAM 8 KB  (.text + .data + .bss + stack)
//                                 -> fetch lenh o day duoc GIAI MA
//    0x0200_0000                 MMIO: bit[0] = LED
//    0x0200_0010                 MMIO: ghi 1 byte -> UART TX
//    0x0200_0014                 MMIO: bit[0] = UART busy (chi doc)
//
//  FILE PHU THUOC: picorv32.v, isr_ram.v, uart_tx.v, isr_decoder.v,
//                  isr_prf_round.v, isr_sbox4.v
//======================================================================
`default_nettype none

module isr_top #(
    // ---- Cau hinh ISR: doi o day roi build lai de so sanh 3 che do ----
    parameter integer ISR_MODE       = 2,               // 0=off 1=XOR 2=xorshift 3=PRF3
    parameter [31:0]  ISR_KEY        = 32'h5A5B5A5A,

    // ---- Bo nho ----
    parameter integer RAM_AW         = 11,              // 2^11 word = 8 KB
    parameter         RAM_INIT       = "D:/New folder (19)/isr_uart/fpga_project_1/firmware/firm_isr_m2.hex",

    // ---- Board ----  
    parameter integer CLK_HZ         = 27_000_000,
    parameter integer UART_BAUD      = 115200,
    parameter [0:0]   LED_ACTIVE_LOW = 1'b1,            // Tang Nano 4K: 0 = sang
    parameter [0:0]   BUS_TIMEOUT_EN = 1'b1,            // chong treo o dia  chi la
    parameter integer WD_BITS        = 26               // watchdog; 2^25/27e6 ~ 1.24 s
                                                        // (testbench ha xuong ~12)
) (
    input  wire sys_clk,        // chan 45, 27 MHz
    input  wire sys_rst_n,      // chan 15, nut S1, active-low, co pull-up
    output wire led,            // chan 10
    output wire uart_tx_pin     // chan 40 (bank 1, 3.3 V)
);

    //==================================================================
    // 1. Reset: dong bo + giu ~256 chu ky sau khi tha nut
    //==================================================================
    reg [7:0] rst_cnt = 8'd0;
    reg       resetn  = 1'b0;
    reg [1:0] rst_sync = 2'b00;

    always @(posedge sys_clk) begin
        rst_sync <= {rst_sync[0], sys_rst_n};

        if (!rst_sync[1]) begin
            rst_cnt <= 8'd0;
            resetn  <= 1'b0;
        end else if (!rst_cnt[7]) begin
            rst_cnt <= rst_cnt + 8'd1;
            resetn  <= 1'b0;
        end else begin
            resetn  <= 1'b1;
        end
    end

    //==================================================================
    // 2. CPU
    //==================================================================
    wire        trap;
    wire        mem_valid, mem_instr;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0]  mem_wstrb;
    wire        mem_ready;
    wire [31:0] mem_rdata;

    picorv32 #(
        // BAT BUOC 0: decoder lam viec theo word 32-bit.
        // Lenh nen 16-bit se pha vo can chinh -> firmware phai build
        // bang -march=rv32i (KHONG co 'c').
        .COMPRESSED_ISA       (0),

        // Bat bay loi -> co tin hieu "chuong trinh sai" ro rang
        .CATCH_ILLINSN        (1),
        .CATCH_MISALIGN       (1),

        // Cat bot cho vua 4608 LUT4 cua GW1NSR-4C
        .ENABLE_COUNTERS      (0),
        .ENABLE_COUNTERS64    (0),
        .BARREL_SHIFTER       (0),
        .TWO_STAGE_SHIFT      (1),
        .TWO_CYCLE_COMPARE    (0),
        .TWO_CYCLE_ALU        (0),
        .ENABLE_MUL           (0),
        .ENABLE_FAST_MUL      (0),
        .ENABLE_DIV           (0),
        .ENABLE_PCPI          (0),
        .ENABLE_IRQ           (0),
        .ENABLE_TRACE         (0),

        .ENABLE_REGS_16_31    (1),   // can cho ABI ilp32 chuan
        .ENABLE_REGS_DUALPORT (1),
        .REGS_INIT_ZERO       (1),

        .PROGADDR_RESET       (32'h0000_0000),
        .STACKADDR            (32'h0000_0000 + (1 << (RAM_AW + 2)))
    ) u_cpu (
        .clk        (sys_clk),
        .resetn     (resetn),
        .trap       (trap),

        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_ready  (mem_ready),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_rdata  (mem_rdata),

        // Look-ahead interface: khong dung (de trong)
        .mem_la_read (), .mem_la_write (), .mem_la_addr (),
        .mem_la_wdata(), .mem_la_wstrb (),

        // PCPI: khong dung
        .pcpi_valid (), .pcpi_insn (), .pcpi_rs1 (), .pcpi_rs2 (),
        .pcpi_wr    (1'b0), .pcpi_rd (32'b0),
        .pcpi_wait  (1'b0), .pcpi_ready (1'b0),

        // IRQ: khong dung
        .irq        (32'b0),
        .eoi        ()
    );

    //==================================================================
    // 3. Giai ma dia chi
    //==================================================================
    wire ram_sel  = mem_valid && (mem_addr[31:24] == 8'h00);
    wire mmio_sel = mem_valid && (mem_addr[31:24] == 8'h02);

    //==================================================================
    // 4. RAM 8 KB (chua firmware DA MA HOA)
    //==================================================================
    wire [31:0] ram_rdata;
    wire        ram_ready;

    isr_ram #(
        .AW        (RAM_AW),
        .INIT_FILE (RAM_INIT)
    ) u_ram (
        .clk    (sys_clk),
        .resetn (resetn),
        .sel    (ram_sel),
        .ready  (ram_ready),
        .addr   (mem_addr[RAM_AW+1:2]),   // dia chi theo WORD
        .wdata  (mem_wdata),
        .wstrb  (mem_wstrb),
        .rdata  (ram_rdata)
    );

    //==================================================================
    // 5. ISR decoder -- tinh truoc key_eff, cho qua thanh ghi
    //
    //    Meo: dat data_in = 0 va is_instr = 1 thi isr_decoder tra ve
    //    dung key_eff (vi data_out = data_in ^ k = 0 ^ k = k), va van
    //    tu dong tra ve 0 khi MODE = 0. Nho vay KHONG phai sua
    //    isr_decoder.v, ma van tach duoc PRF ra khoi duong to hop
    //    tro ve chan mem_rdata cua CPU.
    //==================================================================
    wire [31:0] key_eff;

    isr_decoder #(
        .MODE (ISR_MODE),
        .KEY  (ISR_KEY)
    ) u_key (
        .addr     (mem_addr),          // KHONG dung mem_la_addr
        .data_in  (32'h0000_0000),
        .is_instr (1'b1),
        .data_out (key_eff)
    );

    reg [31:0] key_eff_q;
    reg        instr_q;

    always @(posedge sys_clk) begin
        key_eff_q <= key_eff;           // f(mem_addr cua chu ky truoc)
        instr_q   <= mem_instr;
    end

    //==================================================================
    // 6. MMIO
    //      0x0200_0000  bit[0]  LED            (doc/ghi)
    //      0x0200_0010  [7:0]   UART TX data   (ghi)
    //      0x0200_0014  bit[0]  UART busy      (chi doc)
    //==================================================================
    reg        led_reg;
    reg        mmio_ready;
    reg [31:0] mmio_rdata;

    wire [3:0] mmio_reg = mem_addr[5:2];   // 0x00->0  0x10->4  0x14->5
    wire       mmio_wr  = mmio_sel && !mmio_ready && (|mem_wstrb);

    wire       led_wr   = mmio_wr && (mmio_reg == 4'd0);
    wire       uart_we  = mmio_wr && (mmio_reg == 4'd4);

    wire       uart_busy;

    uart_tx #(
        .CLK_HZ (CLK_HZ),
        .BAUD   (UART_BAUD)
    ) u_uart (
        .clk    (sys_clk),
        .resetn (resetn),
        .data   (mem_wdata[7:0]),
        .we     (uart_we),
        .busy   (uart_busy),
        .tx     (uart_tx_pin)
    );

    always @(posedge sys_clk) begin
        if (!resetn) begin
            led_reg    <= 1'b0;
            mmio_ready <= 1'b0;
            mmio_rdata <= 32'b0;
        end else begin
            mmio_ready <= mmio_sel && !mmio_ready;
            if (mmio_sel && !mmio_ready) begin
                case (mmio_reg)
                    4'd0:    mmio_rdata <= {31'b0, led_reg};
                    4'd5:    mmio_rdata <= {31'b0, uart_busy};
                    default: mmio_rdata <= 32'h0000_0000;
                endcase
                if (led_wr && mem_wstrb[0]) led_reg <= mem_wdata[0];
            end
        end
    end

    //==================================================================
    // 7. Bus timeout -- neu code rac nhay ra ngoai vung dia chi da map
    //    thi khong slave nao tra ready => CPU treo im lang. Tra ve 0
    //    sau 256 chu ky de CPU fetch phai lenh 0x00000000 (khong hop le)
    //    va bat trap -> loi hien ro thay vi treo am tham.
    //==================================================================
    reg [8:0] to_cnt;
    wire      to_ready = BUS_TIMEOUT_EN && to_cnt[8];

    always @(posedge sys_clk) begin
        if (!resetn || !mem_valid || mem_ready)
            to_cnt <= 9'd0;
        else if (!to_cnt[8])
            to_cnt <= to_cnt + 9'd1;
    end

    //==================================================================
    // 8. Gop bus + GIAI MA lenh
    //==================================================================
    wire [31:0] raw_rdata = ram_ready  ? ram_rdata  :
                            mmio_ready ? mmio_rdata :
                                         32'h0000_0000;

    // Chi giai ma khi: la lenh fetch (instr_q) VA lay tu RAM (ram_ready).
    // Du lieu doc bang lw/lb (mem_instr = 0) di thang, khong giai ma
    // -> .rodata / .data phai duoc luu DANG THO trong file hex.
    assign mem_rdata = (instr_q && ram_ready) ? (raw_rdata ^ key_eff_q)
                                              :  raw_rdata;

    assign mem_ready = ram_ready | mmio_ready | to_ready;

    //==================================================================
    // 9. Watchdog: CPU phai ghi vao thanh ghi LED it nhat 1 lan / 1.24 s
    //==================================================================
    reg [WD_BITS-1:0] wd_cnt;
    reg               alive;

    always @(posedge sys_clk) begin
        if (!resetn) begin
            wd_cnt <= {WD_BITS{1'b0}};
            alive  <= 1'b0;
        end else if (led_wr) begin
            wd_cnt <= {WD_BITS{1'b0}};
            alive  <= 1'b1;                       // CPU con song
        end else if (!wd_cnt[WD_BITS-1]) begin
            wd_cnt <= wd_cnt + 1'b1;
        end else begin
            alive  <= 1'b0;                       // qua han -> coi nhu chet
        end
    end

    //==================================================================
    // 10. LED
    //     DUNG key : CPU chay -> led_reg nhay -> LED nhay ~1 Hz
    //     SAI key  : trap = 1 hoac alive = 0   -> LED TAT han
    //==================================================================
    wire run_ok = alive && !trap;
    wire led_on = run_ok && led_reg;

    assign led = LED_ACTIVE_LOW ? ~led_on : led_on;

endmodule

`default_nettype wire