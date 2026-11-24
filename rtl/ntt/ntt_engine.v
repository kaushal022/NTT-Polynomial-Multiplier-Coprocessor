`timescale 1ns / 1ps

module ntt_engine (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire        mode,
    output reg         done,
    output reg         busy,
    output reg  [15:0] cycle_count,

    output wire        bram_ena,
    output wire        bram_wea,
    output wire [7:0]  bram_addra,
    output wire [11:0] bram_dina,
    input  wire [11:0] bram_douta,

    output wire        bram_enb,
    output wire        bram_web,
    output wire [7:0]  bram_addrb,
    output wire [11:0] bram_dinb,
    input  wire [11:0] bram_doutb,

    input  wire        scr_ena,
    input  wire [7:0]  scr_addr,
    output wire [11:0] scr_data,

    output reg         result_in_scratch
);

    localparam [11:0] N_INV      = 12'd3303;
    localparam integer WB_LATENCY = 6;
    localparam integer STALL_CYC  = 6;
    localparam integer SC_PIPE    = 3;
    localparam integer INTT_DRAIN = WB_LATENCY + SC_PIPE;
    localparam integer FWD_DRAIN  = WB_LATENCY;

    localparam [2:0]
        S_IDLE        = 3'd0,
        S_INIT        = 3'd1,
        S_NTT         = 3'd2,
        S_LAYER_STALL = 3'd3,
        S_DRAIN       = 3'd4,
        S_FINISH      = 3'd5;

    reg [2:0] state;

    reg       mode_r;
    reg       layer_parity;
    reg [6:0] bfly_in_layer;
    reg [3:0] stall_cnt;

    reg        ag_start;
    wire       ag_advance;
    wire [7:0] ag_addr_lo, ag_addr_hi;
    wire [6:0] ag_tw_addr;
    wire       ag_pair_valid;
    wire       ag_ntt_done;
    wire [2:0] ag_layer_idx;

    ntt_addr_gen u_addr_gen (
        .clk(clk),
        .rst_n(rst_n),
        .start(ag_start),
        .mode(mode_r),
        .advance(ag_advance),
        .addr_lo(ag_addr_lo),
        .addr_hi(ag_addr_hi),
        .tw_addr(ag_tw_addr),
        .pair_valid(ag_pair_valid),
        .ntt_done(ag_ntt_done),
        .layer_idx(ag_layer_idx)
    );

    wire [11:0] tw_data;
    twiddle_rom u_tw_rom (
        .clk(clk),
        .addr(ag_tw_addr),
        .twiddle(tw_data)
    );

    wire read_issue = (state == S_NTT) && ag_pair_valid;
    assign ag_advance = read_issue;

    reg       read_valid_r1;
    reg       layer_parity_r1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_valid_r1   <= 1'b0;
            layer_parity_r1 <= 1'b0;
        end else begin
            read_valid_r1   <= read_issue;
            layer_parity_r1 <= layer_parity;
        end
    end

    wire        scr_ena_a, scr_wea_a;
    wire [7:0]  scr_addr_a;
    wire [11:0] scr_din_a;
    wire [11:0] scr_dout_a;

    wire        scr_ena_b, scr_web_b;
    wire [7:0]  scr_addr_b;
    wire [11:0] scr_din_b;
    wire [11:0] scr_dout_b;

    reg [11:0] bfly_a_r, bfly_b_r, bfly_w_r;
    reg        bfly_v_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bfly_v_r <= 1'b0;
            bfly_a_r <= 12'd0;
            bfly_b_r <= 12'd0;
            bfly_w_r <= 12'd0;
        end else begin
            bfly_v_r <= read_valid_r1;
            bfly_a_r <= (layer_parity_r1 == 1'b0) ? bram_douta : scr_dout_a;
            bfly_b_r <= (layer_parity_r1 == 1'b0) ? bram_doutb : scr_dout_b;
            bfly_w_r <= tw_data;
        end
    end

    wire        bfly_valid_out;
    wire [11:0] bfly_out_lo, bfly_out_hi;

    butterfly u_butterfly (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(bfly_v_r),
        .mode(mode_r),
        .a(bfly_a_r),
        .b(bfly_b_r),
        .w(bfly_w_r),
        .valid_out(bfly_valid_out),
        .out_lo(bfly_out_lo),
        .out_hi(bfly_out_hi)
    );

    wire is_last_intt_layer = (mode_r == 1'b1) && (ag_layer_idx == 3'd6);

    reg [17:0] wb_pipe [0:WB_LATENCY-1];

    always @(posedge clk or negedge rst_n) begin : wb_shift
        integer k;
        if (!rst_n) begin
            for (k = 0; k < WB_LATENCY; k = k + 1)
                wb_pipe[k] <= 18'd0;
        end else begin
            for (k = WB_LATENCY - 1; k > 0; k = k - 1)
                wb_pipe[k] <= wb_pipe[k - 1];
            wb_pipe[0] <= {is_last_intt_layer, layer_parity, ag_addr_lo, ag_addr_hi};
        end
    end

    wire        wb_we      = bfly_valid_out;
    wire        wb_intt6   = wb_pipe[WB_LATENCY - 1][17];
    wire        wb_par     = wb_pipe[WB_LATENCY - 1][16];
    wire [7:0]  wb_lo      = wb_pipe[WB_LATENCY - 1][15:8];
    wire [7:0]  wb_hi      = wb_pipe[WB_LATENCY - 1][7:0];

    wire wb_to_scratch = wb_we && !wb_intt6 && (wb_par == 1'b0);

    wire [11:0] scaled_lo, scaled_hi;

    mod_mul u_scale_lo_mul (
        .clk(clk),
        .rst_n(rst_n),
        .a(bfly_out_lo),
        .b(N_INV),
        .result(scaled_lo)
    );

    mod_mul u_scale_hi_mul (
        .clk(clk),
        .rst_n(rst_n),
        .a(bfly_out_hi),
        .b(N_INV),
        .result(scaled_hi)
    );

    reg [16:0] sc_wb_pipe [0:SC_PIPE-1];

    always @(posedge clk or negedge rst_n) begin : sc_wb_shift
        integer m;
        if (!rst_n) begin
            for (m = 0; m < SC_PIPE; m = m + 1)
                sc_wb_pipe[m] <= 17'd0;
        end else begin
            for (m = SC_PIPE - 1; m > 0; m = m - 1)
                sc_wb_pipe[m] <= sc_wb_pipe[m - 1];
            sc_wb_pipe[0] <= {(wb_we && wb_intt6), wb_lo, wb_hi};
        end
    end

    wire        sc_wb_v  = sc_wb_pipe[SC_PIPE - 1][16];
    wire [7:0]  sc_wb_lo = sc_wb_pipe[SC_PIPE - 1][15:8];
    wire [7:0]  sc_wb_hi = sc_wb_pipe[SC_PIPE - 1][7:0];

    poly_bram u_scratch (
        .clk(clk),
        .ena(scr_ena_a), .wea(scr_wea_a), .addra(scr_addr_a), .dina(scr_din_a), .douta(scr_dout_a),
        .enb(scr_ena_b), .web(scr_web_b), .addrb(scr_addr_b), .dinb(scr_din_b), .doutb(scr_dout_b)
    );

    assign scr_ena_a = (state == S_IDLE) ? scr_ena :
                       sc_wb_v           ? 1'b1 :
                       wb_to_scratch      ? 1'b1 :
                       (read_issue && (layer_parity == 1'b1)) ? 1'b1 : 1'b0;

    assign scr_wea_a = (state == S_IDLE) ? 1'b0 :
                       sc_wb_v           ? 1'b1 :
                       wb_to_scratch      ? 1'b1 : 1'b0;

    assign scr_addr_a = (state == S_IDLE) ? scr_addr :
                        sc_wb_v           ? sc_wb_lo :
                        wb_to_scratch      ? wb_lo :
                        (read_issue && (layer_parity == 1'b1)) ? ag_addr_lo : 8'd0;

    assign scr_din_a  = sc_wb_v      ? scaled_lo :
                        wb_to_scratch ? bfly_out_lo : 12'd0;

    assign scr_ena_b = sc_wb_v      ? 1'b1 :
                       wb_to_scratch  ? 1'b1 :
                       (read_issue && (layer_parity == 1'b1)) ? 1'b1 : 1'b0;

    assign scr_web_b = sc_wb_v      ? 1'b1 :
                       wb_to_scratch  ? 1'b1 : 1'b0;

    assign scr_addr_b = sc_wb_v      ? sc_wb_hi :
                        wb_to_scratch  ? wb_hi :
                        (read_issue && (layer_parity == 1'b1)) ? ag_addr_hi : 8'd0;

    assign scr_din_b  = sc_wb_v      ? scaled_hi :
                        wb_to_scratch  ? bfly_out_hi : 12'd0;

    assign scr_data = scr_dout_a;

    wire wb_to_ext = wb_we && !wb_intt6 && (wb_par == 1'b1);

    assign bram_ena = wb_to_ext ? 1'b1 :
                      (read_issue && (layer_parity == 1'b0)) ? 1'b1 : 1'b0;

    assign bram_wea = wb_to_ext ? 1'b1 : 1'b0;

    assign bram_addra = wb_to_ext ? wb_lo :
                        (read_issue && (layer_parity == 1'b0)) ? ag_addr_lo : 8'd0;

    assign bram_dina  = wb_to_ext ? bfly_out_lo : 12'd0;

    assign bram_enb = wb_to_ext ? 1'b1 :
                      (read_issue && (layer_parity == 1'b0)) ? 1'b1 : 1'b0;

    assign bram_web = wb_to_ext ? 1'b1 : 1'b0;

    assign bram_addrb = wb_to_ext ? wb_hi :
                        (read_issue && (layer_parity == 1'b0)) ? ag_addr_hi : 8'd0;

    assign bram_dinb  = wb_to_ext ? bfly_out_hi : 12'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= S_IDLE;
            done              <= 1'b0;
            busy              <= 1'b0;
            cycle_count       <= 16'd0;
            ag_start          <= 1'b0;
            mode_r            <= 1'b0;
            layer_parity      <= 1'b0;
            bfly_in_layer     <= 7'd0;
            stall_cnt         <= 4'd0;
            result_in_scratch <= 1'b0;
        end else begin
            ag_start   <= 1'b0;
            done       <= 1'b0;

            if (busy)
                cycle_count <= cycle_count + 16'd1;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        busy              <= 1'b1;
                        mode_r            <= mode;
                        cycle_count       <= 16'd0;
                        layer_parity      <= 1'b0;
                        bfly_in_layer     <= 7'd0;
                        result_in_scratch <= 1'b0;
                        ag_start          <= 1'b1;
                        state             <= S_INIT;
                    end
                end

                S_INIT: begin
                    state <= S_NTT;
                end

                S_NTT: begin
                    if (ag_pair_valid) begin
                        if (bfly_in_layer == 7'd127) begin
                            bfly_in_layer <= 7'd0;

                            if (ag_layer_idx == 3'd6) begin
                                stall_cnt <= (mode_r == 1'b1) ? (INTT_DRAIN - 1) : (FWD_DRAIN - 1);
                                state     <= S_DRAIN;
                            end else begin
                                stall_cnt <= (STALL_CYC - 1);
                                state     <= S_LAYER_STALL;
                            end
                        end else begin
                            bfly_in_layer <= bfly_in_layer + 7'd1;
                        end
                    end
                end

                S_LAYER_STALL: begin
                    if (stall_cnt == 4'd0) begin
                        layer_parity <= ~layer_parity;
                        state        <= S_NTT;
                    end else begin
                        stall_cnt <= stall_cnt - 4'd1;
                    end
                end

                S_DRAIN: begin
                    if (stall_cnt == 4'd0) begin
                        result_in_scratch <= 1'b1;
                        state             <= S_FINISH;
                    end else begin
                        stall_cnt <= stall_cnt - 4'd1;
                    end
                end

                S_FINISH: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
