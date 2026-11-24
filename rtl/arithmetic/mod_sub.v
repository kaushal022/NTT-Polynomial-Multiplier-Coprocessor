`timescale 1ns / 1ps

module mod_sub (
    input  wire [11:0] a,
    input  wire [11:0] b,
    output wire [11:0] result
);

    localparam [12:0] Q = 13'd3329;

    wire [12:0] diff;
    wire [12:0] diff_plus_q;

    assign diff = {1'b0, a} - {1'b0, b};
    assign diff_plus_q = diff + Q;

    assign result = diff[12] ? diff_plus_q[11:0] : diff[11:0];

endmodule
