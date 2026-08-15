//======================================================================
//  uart_tx.v -- UART transmitter 8N1 cho ISR demo (Tang Nano 4K)
//
//  - 8 bit du lieu, khong parity, 1 stop bit (8N1)
//  - Chi TX (du cho demo in thong bao ra PC)
//  - Giao dien: dat data, nhan we 1 chu ky -> busy len cho toi khi
//    gui xong. Firmware phai doi busy = 0 truoc khi gui byte tiep.
//
//  BAUD @ 27 MHz:
//      DIV = 27_000_000 / 115200 = 234.375  ->  lam tron 234
//      Baud thuc te = 27e6 / 234 = 115384.6
//      Sai so = +0.16%  (UART chiu duoc toi ~2-3%, rat thoai mai)
//
//  Muc nghi (idle) cua duong TX la MUC CAO. Neu do bang dao dong ky
//  ma thay muc thap khi khong gui gi, la dau day bi dao.
//======================================================================
`default_nettype none

module uart_tx #(
    parameter integer CLK_HZ = 27_000_000,
    parameter integer BAUD   = 115200
) (
    input  wire       clk,
    input  wire       resetn,

    input  wire [7:0] data,     // byte can gui
    input  wire       we,       // pulse 1 chu ky: bat dau gui
    output wire       busy,     // 1 = dang gui, khong nhan byte moi

    output reg        tx        // ra chan FPGA
);

    localparam integer DIV = CLK_HZ / BAUD;

    reg [15:0] cnt;             // dem chu ky trong 1 bit
    reg [3:0]  idx;             // 0=start, 1..8=data, 9=stop
    reg [9:0]  sh;              // {stop, data[7:0], start}
    reg        active;

    assign busy = active;

    always @(posedge clk) begin
        if (!resetn) begin
            tx     <= 1'b1;         // idle = muc cao
            active <= 1'b0;
            cnt    <= 16'd0;
            idx    <= 4'd0;
            sh     <= 10'h3FF;
        end
        else if (!active) begin
            tx <= 1'b1;
            if (we) begin
                sh     <= {1'b1, data, 1'b0};   // stop | data | start
                tx     <= 1'b0;                 // start bit ngay chu ky sau
                cnt    <= 16'd0;
                idx    <= 4'd0;
                active <= 1'b1;
            end
        end
        else begin
            if (cnt == DIV[15:0] - 16'd1) begin
                cnt <= 16'd0;
                if (idx == 4'd9) begin          // xong stop bit
                    active <= 1'b0;
                    tx     <= 1'b1;
                end else begin
                    idx <= idx + 4'd1;
                    tx  <= sh[idx + 4'd1];      // bit ke tiep
                end
            end else begin
                cnt <= cnt + 16'd1;
            end
        end
    end

endmodule

`default_nettype wire
