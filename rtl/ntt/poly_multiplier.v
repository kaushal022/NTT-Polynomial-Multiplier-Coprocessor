`timescale 1ns / 1ps

module poly_multiplier (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    output reg         done,
    output reg         busy,
    output reg  [15:0] cycle_count,

    input  wire        ext_wen_f,
    input  wire        ext_wen_g,
    input  wire [7:0]  ext_addr,
    input  wire [11:0] ext_wdata_f,
    input  wire [11:0] ext_wdata_g,

    input  wire        ext_ren,
    input  wire [7:0]  ext_raddr,
    output wire [11:0] ext_rdata
);

    localparam PM_IDLE         = 4'd0;
    localparam PM_COPY_F       = 4'd1;
    localparam PM_NTT_F        = 4'd2;
    localparam PM_SAVE_FHAT    = 4'd3;
    localparam PM_COPY_G       = 4'd4;
    localparam PM_NTT_G        = 4'd5;
    localparam PM_BASEMUL      = 4'd6;
    localparam PM_INTT         = 4'd7;
    localparam PM_DONE         = 4'd8;

    reg [3:0] pm_state;

    reg         bram_f_ena, bram_f_wea;
    reg  [7:0]  bram_f_addra;
    reg  [11:0] bram_f_dina;
    wire [11:0] bram_f_douta;

    poly_bram u_bram_f (
        .clk(clk),
        .ena(bram_f_ena), .wea(bram_f_wea), .addra(bram_f_addra),
        .dina(bram_f_dina), .douta(bram_f_douta),
        .enb(1'b0), .web(1'b0), .addrb(8'd0), .dinb(12'd0), .doutb()
    );

    reg         bram_g_ena, bram_g_wea;
    reg  [7:0]  bram_g_addra;
    reg  [11:0] bram_g_dina;
    wire [11:0] bram_g_douta;

    poly_bram u_bram_g (
        .clk(clk),
        .ena(bram_g_ena), .wea(bram_g_wea), .addra(bram_g_addra),
        .dina(bram_g_dina), .douta(bram_g_douta),
        .enb(1'b0), .web(1'b0), .addrb(8'd0), .dinb(12'd0), .doutb()
    );

    wire        ntt_bram_ena, ntt_bram_wea;
    wire [7:0]  ntt_bram_addra;
    wire [11:0] ntt_bram_dina, ntt_bram_douta;
    wire        ntt_bram_enb, ntt_bram_web;
    wire [7:0]  ntt_bram_addrb;
    wire [11:0] ntt_bram_dinb, ntt_bram_doutb;

    reg         work_ena, work_wea;
    reg  [7:0]  work_addra;
    reg  [11:0] work_dina;
    wire [11:0] work_douta;
    reg         work_enb, work_web;
    reg  [7:0]  work_addrb;
    reg  [11:0] work_dinb;
    wire [11:0] work_doutb;

    reg ntt_has_control;

    wire m_work_ena   = ntt_has_control ? ntt_bram_ena   : work_ena;
    wire m_work_wea   = ntt_has_control ? ntt_bram_wea   : work_wea;
    wire [7:0]  m_work_addra = ntt_has_control ? ntt_bram_addra : work_addra;
    wire [11:0] m_work_dina  = ntt_has_control ? ntt_bram_dina  : work_dina;
    wire m_work_enb   = ntt_has_control ? ntt_bram_enb   : work_enb;
    wire m_work_web   = ntt_has_control ? ntt_bram_web   : work_web;
    wire [7:0]  m_work_addrb = ntt_has_control ? ntt_bram_addrb : work_addrb;
    wire [11:0] m_work_dinb  = ntt_has_control ? ntt_bram_dinb  : work_dinb;

    poly_bram u_bram_work (
        .clk(clk),
        .ena(m_work_ena), .wea(m_work_wea), .addra(m_work_addra),
        .dina(m_work_dina), .douta(work_douta),
        .enb(m_work_enb), .web(m_work_web), .addrb(m_work_addrb),
        .dinb(m_work_dinb), .doutb(work_doutb)
    );

    assign ntt_bram_douta = work_douta;
    assign ntt_bram_doutb = work_doutb;

    reg         bram_t_ena, bram_t_wea;
    reg  [7:0]  bram_t_addra;
    reg  [11:0] bram_t_dina;
    wire [11:0] bram_t_douta;
    reg         bram_t_enb, bram_t_web;
    reg  [7:0]  bram_t_addrb;
    reg  [11:0] bram_t_dinb;
    wire [11:0] bram_t_doutb;

    poly_bram u_bram_temp (
        .clk(clk),
        .ena(bram_t_ena), .wea(bram_t_wea), .addra(bram_t_addra),
        .dina(bram_t_dina), .douta(bram_t_douta),
        .enb(bram_t_enb), .web(bram_t_web), .addrb(bram_t_addrb),
        .dinb(bram_t_dinb), .doutb(bram_t_doutb)
    );

    reg         ntt_start, ntt_mode;
    wire        ntt_done, ntt_busy;
    wire [15:0] ntt_cycles;
    wire        ntt_result_in_scratch;

    reg         scr_ena_r;
    reg  [7:0]  scr_addr_r;
    wire [11:0] scr_data_w;

    ntt_engine u_ntt (
        .clk(clk), .rst_n(rst_n),
        .start(ntt_start), .mode(ntt_mode),
        .done(ntt_done), .busy(ntt_busy), .cycle_count(ntt_cycles),
        .bram_ena(ntt_bram_ena), .bram_wea(ntt_bram_wea), .bram_addra(ntt_bram_addra),
        .bram_dina(ntt_bram_dina), .bram_douta(ntt_bram_douta),
        .bram_enb(ntt_bram_enb), .bram_web(ntt_bram_web), .bram_addrb(ntt_bram_addrb),
        .bram_dinb(ntt_bram_dinb), .bram_doutb(ntt_bram_doutb),
        .scr_ena(scr_ena_r), .scr_addr(scr_addr_r), .scr_data(scr_data_w),
        .result_in_scratch(ntt_result_in_scratch)
    );

    assign ext_rdata = ntt_result_in_scratch ? scr_data_w : work_douta;

    reg         bm_valid_in;
    reg  [11:0] bm_a0, bm_a1, bm_b0, bm_b1, bm_gamma;
    wire        bm_valid_out;
    wire [11:0] bm_c0, bm_c1;

    basemul u_basemul (
        .clk(clk), .rst_n(rst_n),
        .valid_in(bm_valid_in),
        .a0(bm_a0), .a1(bm_a1), .b0(bm_b0), .b1(bm_b1), .gamma(bm_gamma),
        .valid_out(bm_valid_out), .c0(bm_c0), .c1(bm_c1)
    );

    wire [11:0] gamma_rom;
    reg  [6:0]  gamma_addr;
    twiddle_rom u_gamma_rom (.clk(clk), .addr(gamma_addr), .twiddle(gamma_rom));

    reg [8:0] copy_idx;
    reg [1:0] copy_phase;
    reg [6:0] bm_idx;
    reg [2:0] bm_phase;
    reg       bm_neg_gamma;

    wire [11:0] neg_gamma;
    mod_sub u_neg_gamma (.a(12'd0), .b(gamma_rom), .result(neg_gamma));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pm_state       <= PM_IDLE;
            done           <= 1'b0;
            busy           <= 1'b0;
            cycle_count    <= 16'd0;
            ntt_start      <= 1'b0;
            ntt_mode       <= 1'b0;
            ntt_has_control <= 1'b0;
            bm_valid_in    <= 1'b0;
            copy_idx       <= 9'd0;
            copy_phase     <= 2'd0;
            bm_idx         <= 7'd0;
            bm_phase       <= 3'd0;
            bm_neg_gamma   <= 1'b0;
            scr_ena_r      <= 1'b0;
            scr_addr_r     <= 8'd0;

            bram_f_ena <= 1'b0; bram_f_wea <= 1'b0; bram_f_addra <= 8'd0; bram_f_dina <= 12'd0;
            bram_g_ena <= 1'b0; bram_g_wea <= 1'b0; bram_g_addra <= 8'd0; bram_g_dina <= 12'd0;
            bram_t_ena <= 1'b0; bram_t_wea <= 1'b0; bram_t_addra <= 8'd0; bram_t_dina <= 12'd0;
            bram_t_enb <= 1'b0; bram_t_web <= 1'b0; bram_t_addrb <= 8'd0; bram_t_dinb <= 12'd0;
            work_ena <= 1'b0; work_wea <= 1'b0; work_addra <= 8'd0; work_dina <= 12'd0;
            work_enb <= 1'b0; work_web <= 1'b0; work_addrb <= 8'd0; work_dinb <= 12'd0;
            gamma_addr <= 7'd0;
            bm_a0 <= 12'd0; bm_a1 <= 12'd0; bm_b0 <= 12'd0; bm_b1 <= 12'd0; bm_gamma <= 12'd0;
        end else begin
            ntt_start   <= 1'b0;
            done        <= 1'b0;
            bm_valid_in <= 1'b0;
            scr_ena_r   <= 1'b0;
            bram_f_ena  <= 1'b0; bram_f_wea <= 1'b0;
            bram_g_ena  <= 1'b0; bram_g_wea <= 1'b0;
            bram_t_ena  <= 1'b0; bram_t_wea <= 1'b0;
            bram_t_enb  <= 1'b0; bram_t_web <= 1'b0;
            work_ena    <= 1'b0; work_wea   <= 1'b0;
            work_enb    <= 1'b0; work_web   <= 1'b0;

            if (busy)
                cycle_count <= cycle_count + 16'd1;

            case (pm_state)
                PM_IDLE: begin
                    if (ext_wen_f) begin
                        bram_f_ena   <= 1'b1; bram_f_wea   <= 1'b1;
                        bram_f_addra <= ext_addr; bram_f_dina  <= ext_wdata_f;
                    end
                    if (ext_wen_g) begin
                        bram_g_ena   <= 1'b1; bram_g_wea   <= 1'b1;
                        bram_g_addra <= ext_addr; bram_g_dina  <= ext_wdata_g;
                    end
                    if (ext_ren) begin
                        if (ntt_result_in_scratch) begin
                            scr_ena_r  <= 1'b1;
                            scr_addr_r <= ext_raddr;
                        end else begin
                            work_ena   <= 1'b1;
                            work_addra <= ext_raddr;
                        end
                    end

                    if (start) begin
                        busy        <= 1'b1;
                        cycle_count <= 16'd0;
                        copy_idx    <= 9'd0;
                        copy_phase  <= 2'd0;
                        pm_state    <= PM_COPY_F;
                    end
                end

                PM_COPY_F: begin
                    case (copy_phase)
                        2'd0: begin
                            bram_f_ena   <= 1'b1;
                            bram_f_addra <= copy_idx[7:0];
                            copy_phase   <= 2'd1;
                        end
                        2'd1: begin copy_phase <= 2'd2; end
                        2'd2: begin
                            work_ena   <= 1'b1; work_wea   <= 1'b1;
                            work_addra <= copy_idx[7:0]; work_dina <= bram_f_douta;
                            if (copy_idx == 9'd255) begin
                                copy_idx   <= 9'd0; copy_phase <= 2'd3;
                            end else begin
                                copy_idx   <= copy_idx + 9'd1; copy_phase <= 2'd0;
                            end
                        end
                        2'd3: begin
                            copy_phase      <= 2'd0;
                            ntt_has_control <= 1'b1;
                            pm_state        <= PM_NTT_F;
                        end
                        default: copy_phase <= 2'd0;
                    endcase
                end

                PM_NTT_F: begin
                    if (!ntt_busy && !ntt_done) begin
                        ntt_start <= 1'b1; ntt_mode <= 1'b0;
                    end
                    if (ntt_done) begin
                        ntt_has_control <= 1'b0;
                        copy_idx        <= 9'd0;
                        copy_phase      <= 2'd0;
                        pm_state        <= PM_SAVE_FHAT;
                    end
                end

                PM_SAVE_FHAT: begin
                    case (copy_phase)
                        2'd0: begin
                            scr_ena_r  <= 1'b1;
                            scr_addr_r <= copy_idx[7:0];
                            copy_phase <= 2'd1;
                        end
                        2'd1: begin
                            copy_phase <= 2'd2;
                        end
                        2'd2: begin
                            bram_t_ena   <= 1'b1; bram_t_wea   <= 1'b1;
                            bram_t_addra <= copy_idx[7:0]; bram_t_dina <= scr_data_w;

                            if (copy_idx == 9'd255) begin
                                copy_idx   <= 9'd0; copy_phase <= 2'd3;
                            end else begin
                                copy_idx   <= copy_idx + 9'd1; copy_phase <= 2'd0;
                            end
                        end
                        2'd3: begin
                            copy_phase <= 2'd0;
                            pm_state   <= PM_COPY_G;
                        end
                        default: copy_phase <= 2'd0;
                    endcase
                end

                PM_COPY_G: begin
                    case (copy_phase)
                        2'd0: begin
                            bram_g_ena   <= 1'b1; bram_g_addra <= copy_idx[7:0];
                            copy_phase   <= 2'd1;
                        end
                        2'd1: begin copy_phase <= 2'd2; end
                        2'd2: begin
                            work_ena   <= 1'b1; work_wea   <= 1'b1;
                            work_addra <= copy_idx[7:0]; work_dina <= bram_g_douta;
                            if (copy_idx == 9'd255) begin
                                copy_idx   <= 9'd0; copy_phase <= 2'd3;
                            end else begin
                                copy_idx   <= copy_idx + 9'd1; copy_phase <= 2'd0;
                            end
                        end
                        2'd3: begin
                            copy_phase      <= 2'd0;
                            ntt_has_control <= 1'b1;
                            pm_state        <= PM_NTT_G;
                        end
                        default: copy_phase <= 2'd0;
                    endcase
                end

                PM_NTT_G: begin
                    if (!ntt_busy && !ntt_done) begin
                        ntt_start <= 1'b1; ntt_mode <= 1'b0;
                    end
                    if (ntt_done) begin
                        ntt_has_control <= 1'b0;
                        bm_idx    <= 7'd0;
                        bm_phase  <= 3'd0;
                        pm_state  <= PM_BASEMUL;
                    end
                end

                PM_BASEMUL: begin
                    case (bm_phase)
                        3'd0: begin
                            bram_t_ena   <= 1'b1; bram_t_addra <= {bm_idx, 1'b0};
                            bram_t_enb   <= 1'b1; bram_t_addrb <= {bm_idx, 1'b1};

                            scr_ena_r  <= 1'b1;
                            scr_addr_r <= {bm_idx, 1'b0};

                            gamma_addr   <= {1'b1, bm_idx[6:1]};
                            bm_neg_gamma <= bm_idx[0];
                            bm_phase     <= 3'd1;
                        end
                        3'd1: begin
                            scr_ena_r  <= 1'b1;
                            scr_addr_r <= {bm_idx, 1'b1};

                            bm_phase <= 3'd2;
                        end
                        3'd2: begin
                            bm_b0    <= scr_data_w;
                            bm_a0    <= bram_t_douta;
                            bm_a1    <= bram_t_doutb;
                            bm_gamma <= bm_neg_gamma ? neg_gamma : gamma_rom;

                            bm_phase <= 3'd3;
                        end
                        3'd3: begin
                            bm_b1       <= scr_data_w;
                            bm_valid_in <= 1'b1;

                            bm_phase <= 3'd4;
                        end
                        3'd4: begin
                            if (bm_valid_out) begin
                                work_ena   <= 1'b1; work_wea   <= 1'b1;
                                work_addra <= {bm_idx, 1'b0}; work_dina <= bm_c0;
                                work_enb   <= 1'b1; work_web   <= 1'b1;
                                work_addrb <= {bm_idx, 1'b1}; work_dinb <= bm_c1;

                                if (bm_idx == 7'd127)
                                    bm_phase <= 3'd5;
                                else begin
                                    bm_idx   <= bm_idx + 7'd1;
                                    bm_phase <= 3'd0;
                                end
                            end
                        end
                        3'd5: begin
                            ntt_has_control <= 1'b1;
                            pm_state        <= PM_INTT;
                        end
                        default: bm_phase <= 3'd0;
                    endcase
                end

                PM_INTT: begin
                    if (!ntt_busy && !ntt_done) begin
                        ntt_start <= 1'b1; ntt_mode <= 1'b1;
                    end
                    if (ntt_done) begin
                        ntt_has_control <= 1'b0;
                        pm_state        <= PM_DONE;
                    end
                end

                PM_DONE: begin
                    done     <= 1'b1;
                    busy     <= 1'b0;
                    pm_state <= PM_IDLE;
                end

                default: pm_state <= PM_IDLE;
            endcase
        end
    end

endmodule
