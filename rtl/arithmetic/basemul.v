`timescale 1ns / 1ps

module basemul (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [11:0] a0,
    input  wire [11:0] a1,
    input  wire [11:0] b0,
    input  wire [11:0] b1,
    input  wire [11:0] gamma,
    output reg         valid_out,
    output reg  [11:0] c0,
    output reg  [11:0] c1
);

    wire [11:0] a0b0_res, a1b1_res, a0b1_res, a1b0_res;
    mod_mul u_a0b0 (.clk(clk), .rst_n(rst_n), .a(a0), .b(b0), .result(a0b0_res));
    mod_mul u_a1b1 (.clk(clk), .rst_n(rst_n), .a(a1), .b(b1), .result(a1b1_res));
    mod_mul u_a0b1 (.clk(clk), .rst_n(rst_n), .a(a0), .b(b1), .result(a0b1_res));
    mod_mul u_a1b0 (.clk(clk), .rst_n(rst_n), .a(a1), .b(b0), .result(a1b0_res));

    reg [11:0] gamma_r1, gamma_r2, gamma_r3;
    reg        v_r1, v_r2, v_r3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_r1     <= 1'b0;
            v_r2     <= 1'b0;
            v_r3     <= 1'b0;
            gamma_r1 <= 12'd0;
            gamma_r2 <= 12'd0;
            gamma_r3 <= 12'd0;
        end else begin
            v_r1     <= valid_in;
            v_r2     <= v_r1;
            v_r3     <= v_r2;
            gamma_r1 <= gamma;
            gamma_r2 <= gamma_r1;
            gamma_r3 <= gamma_r2;
        end
    end

    wire [11:0] a1b1g_res;
    mod_mul u_a1b1g (.clk(clk), .rst_n(rst_n), .a(a1b1_res), .b(gamma_r3), .result(a1b1g_res));

    wire [11:0] c1_comb;
    mod_add u_c1 (.a(a0b1_res), .b(a1b0_res), .result(c1_comb));

    reg [11:0] a0b0_r4, a0b0_r5, a0b0_r6;
    reg [11:0] c1_r4, c1_r5, c1_r6;
    reg        v_r4, v_r5, v_r6;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_r4    <= 1'b0;
            v_r5    <= 1'b0;
            v_r6    <= 1'b0;
            a0b0_r4 <= 12'd0;
            a0b0_r5 <= 12'd0;
            a0b0_r6 <= 12'd0;
            c1_r4   <= 12'd0;
            c1_r5   <= 12'd0;
            c1_r6   <= 12'd0;
        end else begin
            v_r4    <= v_r3;
            v_r5    <= v_r4;
            v_r6    <= v_r5;
            a0b0_r4 <= a0b0_res;
            a0b0_r5 <= a0b0_r4;
            a0b0_r6 <= a0b0_r5;
            c1_r4   <= c1_comb;
            c1_r5   <= c1_r4;
            c1_r6   <= c1_r5;
        end
    end

    wire [11:0] c0_comb;
    mod_add u_c0 (.a(a0b0_r6), .b(a1b1g_res), .result(c0_comb));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            c0        <= 12'd0;
            c1        <= 12'd0;
        end else begin
            valid_out <= v_r6;
            c0        <= c0_comb;
            c1        <= c1_r6;
        end
    end

endmodule
