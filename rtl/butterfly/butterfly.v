`timescale 1ns / 1ps

module butterfly (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire        mode,
    input  wire [11:0] a,
    input  wire [11:0] b,
    input  wire [11:0] w,
    output reg         valid_out,
    output reg  [11:0] out_lo,
    output reg  [11:0] out_hi
);

    reg [11:0] a_r1, a_r2, a_r3;
    reg [11:0] gs_sum_r1, gs_sum_r2, gs_sum_r3;
    reg        mode_r1, mode_r2, mode_r3;
    reg        v_r1, v_r2, v_r3;

    wire [11:0] gs_sum_comb, gs_diff_comb;
    mod_add u_add_gs (
        .a(a),
        .b(b),
        .result(gs_sum_comb)
    );
    mod_sub u_sub_gs (
        .a(b),
        .b(a),
        .result(gs_diff_comb)
    );

    wire [11:0] bw_product;
    mod_mul u_mul_fw (
        .clk(clk),
        .rst_n(rst_n),
        .a(b),
        .b(w),
        .result(bw_product)
    );

    wire [11:0] gs_diff_w;
    mod_mul u_mul_gs (
        .clk(clk),
        .rst_n(rst_n),
        .a(gs_diff_comb),
        .b(w),
        .result(gs_diff_w)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r1       <= 12'd0;
            a_r2       <= 12'd0;
            a_r3       <= 12'd0;
            gs_sum_r1  <= 12'd0;
            gs_sum_r2  <= 12'd0;
            gs_sum_r3  <= 12'd0;
            mode_r1    <= 1'b0;
            mode_r2    <= 1'b0;
            mode_r3    <= 1'b0;
            v_r1       <= 1'b0;
            v_r2       <= 1'b0;
            v_r3       <= 1'b0;
        end else begin
            v_r1       <= valid_in;
            v_r2       <= v_r1;
            v_r3       <= v_r2;
            mode_r1    <= mode;
            mode_r2    <= mode_r1;
            mode_r3    <= mode_r2;
            a_r1       <= a;
            a_r2       <= a_r1;
            a_r3       <= a_r2;
            gs_sum_r1  <= gs_sum_comb;
            gs_sum_r2  <= gs_sum_r1;
            gs_sum_r3  <= gs_sum_r2;
        end
    end

    wire [11:0] fw_lo, fw_hi;
    mod_add u_add_fw (
        .a(a_r3),
        .b(bw_product),
        .result(fw_lo)
    );
    mod_sub u_sub_fw (
        .a(a_r3),
        .b(bw_product),
        .result(fw_hi)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            out_lo    <= 12'd0;
            out_hi    <= 12'd0;
        end else begin
            valid_out <= v_r3;
            if (v_r3) begin
                if (mode_r3 == 1'b0) begin
                    out_lo <= fw_lo;
                    out_hi <= fw_hi;
                end else begin
                    out_lo <= gs_sum_r3;
                    out_hi <= gs_diff_w;
                end
            end
        end
    end

endmodule
