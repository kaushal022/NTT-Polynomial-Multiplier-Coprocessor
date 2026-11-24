`timescale 1ns / 1ps
module mod_add (
    input  wire [11:0] a,
    input  wire [11:0] b,
    output wire [11:0] result
);

    localparam [12:0] Q = 13'd3329;

    wire [12:0] sum;
    wire [12:0] sum_minus_q;

    assign sum = {1'b0, a} + {1'b0, b};
    assign sum_minus_q = sum - Q;

    assign result = sum_minus_q[12] ? sum[11:0] : sum_minus_q[11:0];

endmodule
