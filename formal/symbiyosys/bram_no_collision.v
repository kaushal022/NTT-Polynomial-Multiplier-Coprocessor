`timescale 1ns / 1ps

module bram_no_collision #(
    parameter integer INJECT_BUG = 0
)(
    input wire clk,
    input wire rst_n
);

    wire start;
    wire mode;
    wire advance;

    wire [7:0] addr_lo;
    wire [7:0] addr_hi;
    wire [6:0] tw_addr;
    wire       pair_valid;
    wire       ntt_done;
    wire [2:0] layer_idx;

    ntt_addr_gen u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .mode       (mode),
        .advance    (advance),
        .addr_lo    (addr_lo),
        .addr_hi    (addr_hi),
        .tw_addr    (tw_addr),
        .pair_valid (pair_valid),
        .ntt_done   (ntt_done),
        .layer_idx  (layer_idx)
    );

    reg        wea, web;
    reg [7:0]  addra, addrb;

    wire [7:0] checked_addr_hi = (INJECT_BUG != 0 && layer_idx == 3'd0) ? addr_lo : addr_hi;

    always @(posedge clk) begin
        if (pair_valid) begin
            wea   <= 1'b1;
            web   <= 1'b1;
            addra <= addr_lo;
            addrb <= checked_addr_hi;
        end else begin
            wea   <= 1'b0;
            web   <= 1'b0;
        end
    end

`ifdef FORMAL
    reg [2:0] f_rst_count;
    initial f_rst_count = 0;
    always @(posedge clk) begin
        if (f_rst_count < 3) begin
            f_rst_count <= f_rst_count + 1;
            assume(!rst_n);
        end else begin
            assume(rst_n);
        end
    end

    reg start_r;
    initial start_r = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            start_r <= start;
            if (start) assume(!start_r);
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            if (pair_valid) begin
                assume (addr_lo != addr_hi);
                assume (tw_addr >= 7'd1 && tw_addr <= 7'd127);
                assume (layer_idx <= 3'd6);
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n && wea && web) begin
            assert (addra != addrb);
        end
    end

    always @(posedge clk) begin
        if (rst_n && pair_valid) begin
            assert (addr_lo != checked_addr_hi);
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            assert (layer_idx <= 3'd6);
        end
    end

    always @(posedge clk) begin
        if (rst_n && pair_valid) begin
            assert (tw_addr >= 7'd1 && tw_addr <= 7'd127);
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cover (ntt_done);
        end
    end

`endif

endmodule
