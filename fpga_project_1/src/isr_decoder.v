module isr_decoder #(
    parameter integer MODE = 1,
    parameter [31:0]  KEY  = 32'hA5A5_A5A5
) (
    input  wire [31:0] addr,
    input  wire [31:0] data_in,
    input  wire        is_instr,
    output wire [31:0] data_out
);
    // ---- PC alignment + tron khoa dau vao ----
    wire [31:0] pc_word = addr & 32'hFFFF_FFFC;
    wire [31:0] t       = pc_word ^ KEY;

    // ---- MODE 2: xorshift32(t) ^ KEY ----
    wire [31:0] xs_a = t    ^ (t    << 13);
    wire [31:0] xs_b = xs_a ^ (xs_a >> 17);
    wire [31:0] xs_c = xs_b ^ (xs_b << 5);
    wire [31:0] keff_m2 = xs_c ^ KEY;

    // ---- MODE 3: PRF3 = 3 vong noi tiep ----
    wire [31:0] r1, r2, keff_m3;
    isr_prf_round #(.KEY(KEY)) R1 (.x(t),  .y(r1));
    isr_prf_round #(.KEY(KEY)) R2 (.x(r1), .y(r2));
    isr_prf_round #(.KEY(KEY)) R3 (.x(r2), .y(keff_m3));

    // ---- Chon key_eff theo MODE (parameter -> chi 1 nhanh giu lai) ----
    wire [31:0] k = (MODE == 0) ? 32'h0    :
                    (MODE == 1) ? KEY      :
                    (MODE == 2) ? keff_m2  :
                    (MODE == 3) ? keff_m3  :
                                  32'h0;

    // ---- XOR + gate is_instr ----
    assign data_out = (MODE != 0 && is_instr) ? (data_in ^ k) : data_in;

endmodule