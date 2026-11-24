`timescale 1ns / 1ps

module ntt_addr_gen (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        mode,
    input  wire        advance,

    output reg  [7:0]  addr_lo,
    output reg  [7:0]  addr_hi,
    output reg  [6:0]  tw_addr,
    output reg         pair_valid,
    output reg         ntt_done,
    output reg  [2:0]  layer_idx
);

    reg        active;
    reg        mode_r;
    reg [7:0]  len;
    reg [7:0]  group_start;
    reg [7:0]  j;
    reg [6:0]  k;

    wire [7:0] next_j;
    wire       j_last;
    wire [8:0] next_group;
    wire       group_last;
    wire       layer_last;

    assign j_last     = (j >= len - 8'd1);
    assign next_group = {1'b0, group_start} + {len, 1'b0};
    assign group_last = (next_group >= 9'd256);
    assign layer_last = (layer_idx >= 3'd6);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active      <= 1'b0;
            pair_valid  <= 1'b0;
            ntt_done    <= 1'b0;
            layer_idx   <= 3'd0;
            len         <= 8'd0;
            group_start <= 8'd0;
            j           <= 8'd0;
            k           <= 7'd0;
            mode_r      <= 1'b0;
            addr_lo     <= 8'd0;
            addr_hi     <= 8'd0;
            tw_addr     <= 7'd0;
        end else begin
            ntt_done <= 1'b0;

            if (start) begin
                active      <= 1'b1;
                mode_r      <= mode;
                layer_idx   <= 3'd0;
                group_start <= 8'd0;
                j           <= 8'd0;
                pair_valid  <= 1'b1;

                addr_lo <= 8'd0;

                if (mode == 1'b0) begin
                    len     <= 8'd128;
                    k       <= 7'd1;
                    addr_hi <= 8'd128;
                    tw_addr <= 7'd1;
                end else begin
                    len     <= 8'd2;
                    k       <= 7'd127;
                    addr_hi <= 8'd2;
                    tw_addr <= 7'd127;
                end
            end else if (active) begin
                if (advance && pair_valid) begin
                    if (j_last && group_last && layer_last) begin
                        ntt_done   <= 1'b1;
                        pair_valid <= 1'b0;
                        active     <= 1'b0;
                    end else if (j_last && group_last) begin
                        layer_idx   <= layer_idx + 3'd1;
                        group_start <= 8'd0;
                        j           <= 8'd0;

                        if (mode_r == 1'b0) begin
                            k <= k + 7'd1;
                            tw_addr <= k + 7'd1;
                            len <= len >> 1;
                            addr_lo <= 8'd0;
                            addr_hi <= len >> 1;
                        end else begin
                            k <= k - 7'd1;
                            tw_addr <= k - 7'd1;
                            len <= len << 1;
                            addr_lo <= 8'd0;
                            addr_hi <= len << 1;
                        end
                    end else if (j_last) begin
                        group_start <= next_group[7:0];
                        j <= 8'd0;

                        if (mode_r == 1'b0) begin
                            k <= k + 7'd1;
                            tw_addr <= k + 7'd1;
                        end else begin
                            k <= k - 7'd1;
                            tw_addr <= k - 7'd1;
                        end

                        addr_lo <= next_group[7:0];
                        addr_hi <= next_group[7:0] + len;
                    end else begin
                        j <= j + 8'd1;
                        addr_lo <= group_start + j + 8'd1;
                        addr_hi <= group_start + j + 8'd1 + len;
                        tw_addr <= k;
                    end
                end
            end
        end
    end

endmodule
