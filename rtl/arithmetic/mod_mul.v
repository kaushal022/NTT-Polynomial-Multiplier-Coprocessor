`timescale 1ns / 1ps

module mod_mul (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] a,
    input  wire [11:0] b,
    output reg  [11:0] result
);

    localparam [12:0] Q = 13'd3329;
    localparam [12:0] BARRETT_M = 13'd5039;

    reg [23:0] product_r1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_r1 <= 24'd0;
        end else begin
            product_r1 <= a * b;
        end
    end

    reg [36:0] product_m_r2;
    reg [12:0] product_low_r2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_m_r2   <= 37'd0;
            product_low_r2 <= 13'd0;
        end else begin
            product_m_r2   <= product_r1 * BARRETT_M;
            product_low_r2 <= product_r1[12:0];
        end
    end

    wire [12:0] t = product_m_r2[36:24];

    wire [12:0] t_times_q_low = {t[1:0], 11'd0} + {t[2:0], 10'd0} + {t[4:0], 8'd0} + t;

    wire [12:0] r = product_low_r2 - t_times_q_low;

    wire [12:0] r_minus_q = r - Q;
    wire [11:0] next_result = r_minus_q[12] ? r[11:0] : r_minus_q[11:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 12'd0;
        end else begin
            result <= next_result;
        end
    end

endmodule
