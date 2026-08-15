//======================================================================
//  isr_ram.v  -- RAM chuong trinh + du lieu cho ISR demo (Tang Nano 4K)
//
//  - Single-port, 32-bit, co byte-write-enable (phuc vu sb/sh cua RV32I)
//  - Khoi tao tu file hex DA MA HOA (1 word 32-bit hex / dong)
//  - Giao dien valid/ready kieu picorv32: sel -> ready pulse 1 chu ky
//  - Doc mat 1 chu ky (dong bo) => suy dien duoc thanh BSRAM cua GW1NSR-4C
//
//  LUU Y $readmemh: GowinSynthesis chay trong thu muc impl/, duong dan
//  tuong doi rat hay hong. Nen truyen duong dan TUYET DOI qua parameter
//  INIT_FILE, vi du:
//      "D:/New folder (19)/isr/firmware/firmware_enc.hex"
//  (dung dau '/', khong dung '\')
//======================================================================
`default_nettype none

module isr_ram #(
    parameter integer AW        = 11,   // 2^11 word = 2048 word = 8 KB
    parameter         INIT_FILE = "firmware_enc.hex"
) (
    input  wire            clk,
    input  wire            resetn,

    input  wire            sel,      // = mem_valid && trung vung dia chi
    output reg             ready,    // pulse 1 chu ky

    input  wire [AW-1:0]   addr,     // dia chi THEO WORD
    input  wire [31:0]     wdata,
    input  wire [3:0]      wstrb,
    output reg  [31:0]     rdata
);

    localparam integer WORDS = (1 << AW);

    reg [31:0] mem [0:WORDS-1];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    // --- Handshake: ready len 1 chu ky sau khi sel duoc khang dinh -------
    // Tach rieng khoi block BSRAM ben duoi de khong gan reset vao BSRAM
    // (co reset -> Gowin se do ve LUT-RAM/FF thay vi BSRAM).
    always @(posedge clk) begin
        if (!resetn)
            ready <= 1'b0;
        else
            ready <= sel && !ready;
    end

    // --- Block BSRAM: doc dong bo + ghi theo byte ------------------------
    // rdata lay gia tri CU (read-before-write) -- picorv32 khong dung
    // du lieu doc trong chu ky ghi nen khong sao.
    always @(posedge clk) begin
        if (sel && !ready) begin
            rdata <= mem[addr];
            if (wstrb[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
            if (wstrb[1]) mem[addr][15: 8] <= wdata[15: 8];
            if (wstrb[2]) mem[addr][23:16] <= wdata[23:16];
            if (wstrb[3]) mem[addr][31:24] <= wdata[31:24];
        end
    end

endmodule

`default_nettype wire