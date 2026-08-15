`timescale 1ns/1ps
module tb_uart;
    parameter integer MODE = 3;
    localparam real   BITT = 1000000000.0/115384.6;   // ns/bit
    reg clk=0, rst_n=0; wire led, tx;
    always #18.518 clk=~clk;

    isr_top #(.ISR_MODE(MODE),.ISR_KEY(32'h5A5A5A5A),.RAM_AW(9),
              .RAM_INIT(`HEXFILE),.WD_BITS(26))
        dut(.sys_clk(clk),.sys_rst_n(rst_n),.led(led),.uart_tx_pin(tx));

    // ---- bo thu UART: giai ma duong tx thanh ky tu ----
    integer nch=0; reg [7:0] b; integer i;
    initial begin : rx
        @(posedge rst_n);
        forever begin
            @(negedge tx);                 // start bit
            #(BITT*1.5);
            for (i=0;i<8;i=i+1) begin b[i]=tx; #(BITT); end
            nch=nch+1;
            if (b==8'h0D) $write("\\r"); else if (b==8'h0A) $write("\n"); else $write("%c",b);
            $fflush;
        end
    end

    initial begin
        repeat(4) @(posedge clk); rst_n=1;
        #40_000_000;                       // 40 ms
        $display("\n---- KET QUA: %0d ky tu | trap=%b alive=%b led=%b ----", nch, dut.trap, dut.alive, led);
        $finish;
    end
endmodule
