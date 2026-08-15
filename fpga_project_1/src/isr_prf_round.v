module isr_prf_round #(parameter [31:0] KEY = 32'h0)
    (input [31:0] x, output [31:0] y);
    wire [3:0] s7,s6,s5,s4,s3,s2,s1,s0;
    isr_sbox4 u7(x[31:28],s7);
    isr_sbox4 u6(x[27:24],s6);
    isr_sbox4 u5(x[23:20],s5);
    isr_sbox4 u4(x[19:16],s4);
    isr_sbox4 u3(x[15:12],s3);
    isr_sbox4 u2(x[11: 8],s2);
    isr_sbox4 u1(x[ 7: 4],s1);
    isr_sbox4 u0(x[ 3: 0],s0);
    wire [31:0] s = {s7,s6,s5,s4,s3,s2,s1,s0};
    // khuech tan:  s ^ rotl(s,7) ^ rotl(s,19)
    wire [31:0] diff = s ^ {s[24:0],s[31:25]} ^ {s[12:0],s[31:13]};
    assign y = diff ^ KEY;
endmodule