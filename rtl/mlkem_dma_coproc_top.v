`timescale 1ns / 1ps

module mlkem_dma_coproc_top #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)(
    input  wire                                s_axi_aclk,
    input  wire                                s_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  wire [2:0]                          s_axi_awprot,
    input  wire                                s_axi_awvalid,
    output reg                                 s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   s_axi_wstrb,
    input  wire                                s_axi_wvalid,
    output reg                                 s_axi_wready,

    output reg  [1:0]                          s_axi_bresp,
    output reg                                 s_axi_bvalid,
    input  wire                                s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  wire [2:0]                          s_axi_arprot,
    input  wire                                s_axi_arvalid,
    output reg                                 s_axi_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output reg  [1:0]                          s_axi_rresp,
    output reg                                 s_axi_rvalid,
    input  wire                                s_axi_rready,

    output wire [31:0]                         m_dma_axi_awaddr,
    output wire [2:0]                          m_dma_axi_awprot,
    output wire                                m_dma_axi_awvalid,
    input  wire                                m_dma_axi_awready,

    output wire [31:0]                         m_dma_axi_wdata,
    output wire [3:0]                          m_dma_axi_wstrb,
    output wire                                m_dma_axi_wvalid,
    input  wire                                m_dma_axi_wready,

    input  wire [1:0]                          m_dma_axi_bresp,
    input  wire                                m_dma_axi_bvalid,
    output wire                                m_dma_axi_bready,

    output wire [31:0]                         m_dma_axi_araddr,
    output wire [2:0]                          m_dma_axi_arprot,
    output wire                                m_dma_axi_arvalid,
    input  wire                                m_dma_axi_arready,

    input  wire [31:0]                         m_dma_axi_rdata,
    input  wire [1:0]                          m_dma_axi_rresp,
    input  wire                                m_dma_axi_rvalid,
    output wire                                m_dma_axi_rready,

    output wire                                irq,
    output wire                                core_busy,
    output wire                                core_start,
    output wire                                core_done,
    output wire [15:0]                         core_cycle_count,
    output wire                                dma_busy,
    output wire                                dma_done,

    output wire                                dbg_result_ren,
    output wire [7:0]                          dbg_result_raddr,
    output wire [11:0]                         dbg_result_rdata
);

    reg wr_sel_r, wr_busy_r;
    reg rd_sel_r, rd_busy_r;

    wire wr_sel = wr_busy_r ? wr_sel_r : s_axi_awaddr[5];

    reg  core_awvalid, core_wvalid, core_bready, core_arvalid, core_rready;
    wire core_awready, core_wready, core_bvalid, core_arready, core_rvalid;
    wire [1:0]  core_bresp, core_rresp;
    wire [31:0] core_rdata;

    reg  dma_reg_awvalid, dma_reg_wvalid, dma_reg_bready;
    reg  dma_reg_arvalid, dma_reg_rready;
    wire dma_reg_awready, dma_reg_wready, dma_reg_bvalid;
    wire dma_reg_arready, dma_reg_rvalid;
    wire [1:0]  dma_reg_bresp, dma_reg_rresp;
    wire [31:0] dma_reg_rdata;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            wr_sel_r  <= 1'b0;
            wr_busy_r <= 1'b0;
            rd_sel_r  <= 1'b0;
            rd_busy_r <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                wr_sel_r  <= s_axi_awaddr[5];
                wr_busy_r <= 1'b1;
            end
            if (s_axi_bvalid && s_axi_bready) begin
                wr_busy_r <= 1'b0;
            end
            if (s_axi_arvalid && s_axi_arready) begin
                rd_sel_r  <= s_axi_araddr[5];
                rd_busy_r <= 1'b1;
            end
            if (s_axi_rvalid && s_axi_rready) begin
                rd_busy_r <= 1'b0;
            end
        end
    end

    always @(*) begin
        core_awvalid    = 1'b0;
        dma_reg_awvalid = 1'b0;
        s_axi_awready   = 1'b0;
        if (!s_axi_awaddr[5]) begin
            core_awvalid  = s_axi_awvalid;
            s_axi_awready = core_awready;
        end else begin
            dma_reg_awvalid = s_axi_awvalid;
            s_axi_awready   = dma_reg_awready;
        end

        core_wvalid    = 1'b0;
        dma_reg_wvalid = 1'b0;
        s_axi_wready   = 1'b0;
        if (!wr_sel) begin
            core_wvalid  = s_axi_wvalid;
            s_axi_wready = core_wready;
        end else begin
            dma_reg_wvalid = s_axi_wvalid;
            s_axi_wready   = dma_reg_wready;
        end

        core_bready    = 1'b0;
        dma_reg_bready = 1'b0;
        if (!wr_sel_r) begin
            s_axi_bresp  = core_bresp;
            s_axi_bvalid = core_bvalid;
            core_bready  = s_axi_bready;
        end else begin
            s_axi_bresp    = dma_reg_bresp;
            s_axi_bvalid   = dma_reg_bvalid;
            dma_reg_bready = s_axi_bready;
        end

        core_arvalid    = 1'b0;
        dma_reg_arvalid = 1'b0;
        s_axi_arready   = 1'b0;
        if (!s_axi_araddr[5]) begin
            core_arvalid  = s_axi_arvalid;
            s_axi_arready = core_arready;
        end else begin
            dma_reg_arvalid = s_axi_arvalid;
            s_axi_arready   = dma_reg_arready;
        end

        core_rready    = 1'b0;
        dma_reg_rready = 1'b0;
        if (!rd_sel_r) begin
            s_axi_rdata  = core_rdata;
            s_axi_rresp  = core_rresp;
            s_axi_rvalid = core_rvalid;
            core_rready  = s_axi_rready;
        end else begin
            s_axi_rdata    = dma_reg_rdata;
            s_axi_rresp    = dma_reg_rresp;
            s_axi_rvalid   = dma_reg_rvalid;
            dma_reg_rready = s_axi_rready;
        end
    end

    // =========================================================================
    // 2. Core AXI4-Lite Slave (0x00..0x1C)
    // =========================================================================
    wire        axi_ext_wen_f;
    wire        axi_ext_wen_g;
    wire [7:0]  axi_ext_addr;
    wire [11:0] axi_ext_wdata_f;
    wire [11:0] axi_ext_wdata_g;
    wire        axi_ext_ren;
    wire [7:0]  axi_ext_raddr;
    wire [11:0] pm_ext_rdata;
    wire        unused_axi_slave_irq;

    axi_lite_coprocessor #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) u_axi_slave (
        .clk              (s_axi_aclk),
        .rst_n            (s_axi_aresetn),
        .s_axi_awaddr     (s_axi_awaddr),
        .s_axi_awprot     (s_axi_awprot),
        .s_axi_awvalid    (core_awvalid),
        .s_axi_awready    (core_awready),
        .s_axi_wdata      (s_axi_wdata),
        .s_axi_wstrb      (s_axi_wstrb),
        .s_axi_wvalid     (core_wvalid),
        .s_axi_wready     (core_wready),
        .s_axi_bresp      (core_bresp),
        .s_axi_bvalid     (core_bvalid),
        .s_axi_bready     (core_bready),
        .s_axi_araddr     (s_axi_araddr),
        .s_axi_arprot     (s_axi_arprot),
        .s_axi_arvalid    (core_arvalid),
        .s_axi_arready    (core_arready),
        .s_axi_rdata      (core_rdata),
        .s_axi_rresp      (core_rresp),
        .s_axi_rvalid     (core_rvalid),
        .s_axi_rready     (core_rready),

        .core_start       (core_start),
        .core_done        (core_done),
        .core_busy        (core_busy),
        .core_cycle_count (core_cycle_count),

        .core_ext_wen_f   (axi_ext_wen_f),
        .core_ext_wen_g   (axi_ext_wen_g),
        .core_ext_addr    (axi_ext_addr),
        .core_ext_wdata_f (axi_ext_wdata_f),
        .core_ext_wdata_g (axi_ext_wdata_g),
        .core_ext_ren     (axi_ext_ren),
        .core_ext_raddr   (axi_ext_raddr),
        .core_ext_rdata   (pm_ext_rdata),
        .irq              (unused_axi_slave_irq)
    );

    // =========================================================================
    // 3. DMA & Interrupt Control Registers (0x20..0x3C)
    // =========================================================================
    reg        dma_start_r;
    reg        dma_dir_r;
    reg [1:0]  dma_target_r;
    reg [31:0] dma_mem_addr_r;
    reg        dma_done_sticky;
    reg [2:0]  irq_ier_r;
    reg [2:0]  irq_icr_r;
    reg        core_done_sticky;

    wire [2:0] irq_isr_w;

    reg [5:0]  reg_waddr_r;
    reg [31:0] reg_wdata_r;
    reg        reg_aw_done, reg_w_done, reg_bvalid_r;

    assign dma_reg_awready = !reg_aw_done && !reg_bvalid_r;
    assign dma_reg_wready  = !reg_w_done  && !reg_bvalid_r;
    assign dma_reg_bresp   = 2'b00;
    assign dma_reg_bvalid  = reg_bvalid_r;

    wire reg_aw_fire = dma_reg_awvalid && dma_reg_awready;
    wire reg_w_fire  = dma_reg_wvalid  && dma_reg_wready;
    wire [5:0]  eff_waddr = reg_aw_fire ? s_axi_awaddr : reg_waddr_r;
    wire [31:0] eff_wdata = reg_w_fire  ? s_axi_wdata  : reg_wdata_r;
    wire reg_do_wr = (reg_aw_fire || reg_aw_done) && (reg_w_fire || reg_w_done) && !reg_bvalid_r;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            reg_aw_done      <= 1'b0;
            reg_w_done       <= 1'b0;
            reg_bvalid_r     <= 1'b0;
            reg_waddr_r      <= 6'd0;
            reg_wdata_r      <= 32'd0;
            dma_start_r      <= 1'b0;
            dma_dir_r        <= 1'b0;
            dma_target_r     <= 2'd0;
            dma_mem_addr_r   <= 32'd0;
            dma_done_sticky  <= 1'b0;
            irq_ier_r        <= 3'b000;
            irq_icr_r        <= 3'b000;
            core_done_sticky <= 1'b0;
        end else begin
            dma_start_r <= 1'b0;
            irq_icr_r   <= 3'b000;

            if (dma_done)
                dma_done_sticky <= 1'b1;

            if (core_start)
                core_done_sticky <= 1'b0;
            else if (core_done)
                core_done_sticky <= 1'b1;

            if (reg_aw_fire) begin
                reg_waddr_r <= s_axi_awaddr;
                reg_aw_done <= 1'b1;
            end
            if (reg_w_fire) begin
                reg_wdata_r <= s_axi_wdata;
                reg_w_done  <= 1'b1;
            end

            if (reg_do_wr) begin
                case (eff_waddr[4:2])
                    3'd0: begin // 0x20 DMA_CTRL
                        dma_dir_r    <= eff_wdata[1];
                        dma_target_r <= eff_wdata[3:2];
                        if (eff_wdata[0] && !dma_busy) begin
                            dma_start_r     <= 1'b1;
                            dma_done_sticky <= 1'b0;
                        end
                    end
                    3'd1: begin // 0x24 DMA_STATUS (W1C bit 1)
                        if (eff_wdata[1])
                            dma_done_sticky <= 1'b0;
                    end
                    3'd2: begin // 0x28 DMA_MEM_ADDR
                        dma_mem_addr_r <= eff_wdata;
                    end
                    3'd4: begin // 0x30 IRQ_IER
                        irq_ier_r <= eff_wdata[2:0];
                    end
                    3'd5: begin // 0x34 IRQ_ICR (W1C)
                        irq_icr_r <= eff_wdata[2:0];
                        if (eff_wdata[0])
                            core_done_sticky <= 1'b0;
                    end
                    default: ;
                endcase
                reg_bvalid_r <= 1'b1;
                reg_aw_done  <= 1'b0;
                reg_w_done   <= 1'b0;
            end else if (reg_bvalid_r && dma_reg_bready) begin
                reg_bvalid_r <= 1'b0;
            end
        end
    end

    reg [31:0] reg_rdata_r;
    reg        reg_rvalid_r;
    assign dma_reg_arready = !reg_rvalid_r;
    assign dma_reg_rdata   = reg_rdata_r;
    assign dma_reg_rresp   = 2'b00;
    assign dma_reg_rvalid  = reg_rvalid_r;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            reg_rdata_r  <= 32'd0;
            reg_rvalid_r <= 1'b0;
        end else begin
            if (dma_reg_arvalid && dma_reg_arready) begin
                case (s_axi_araddr[4:2])
                    3'd0:    reg_rdata_r <= {28'd0, dma_target_r, dma_dir_r, dma_busy};
                    3'd1:    reg_rdata_r <= {30'd0, dma_done_sticky, dma_busy};
                    3'd2:    reg_rdata_r <= dma_mem_addr_r;
                    3'd3:    reg_rdata_r <= 32'd256;
                    3'd4:    reg_rdata_r <= {29'd0, irq_ier_r};
                    3'd5:    reg_rdata_r <= {29'd0, irq_isr_w};
                    3'd6:    reg_rdata_r <= {29'd0, core_busy, core_done_sticky, irq};
                    default: reg_rdata_r <= 32'd0;
                endcase
                reg_rvalid_r <= 1'b1;
            end else if (reg_rvalid_r && dma_reg_rready) begin
                reg_rvalid_r <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 4. DMA Engine (ntt_dma)
    // =========================================================================
    wire        dma_coproc_wen;
    wire [7:0]  dma_coproc_addr;
    wire [11:0] dma_coproc_wdata_f;
    wire [11:0] dma_coproc_wdata_g;
    wire        dma_coproc_ren;
    wire [7:0]  dma_coproc_raddr;

    assign m_dma_axi_awprot = 3'b000;
    assign m_dma_axi_wstrb  = 4'hF;
    assign m_dma_axi_arprot = 3'b000;

    ntt_dma #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32)
    ) u_dma (
        .clk            (s_axi_aclk),
        .rst_n          (s_axi_aresetn),
        .dma_start      (dma_start_r),
        .dma_dir        (dma_dir_r),
        .dma_target     (dma_target_r),
        .dma_mem_addr   (dma_mem_addr_r),
        .dma_done       (dma_done),
        .dma_busy       (dma_busy),

        .m_axi_araddr   (m_dma_axi_araddr),
        .m_axi_arvalid  (m_dma_axi_arvalid),
        .m_axi_arready  (m_dma_axi_arready),
        .m_axi_rdata    (m_dma_axi_rdata),
        .m_axi_rvalid   (m_dma_axi_rvalid),
        .m_axi_rready   (m_dma_axi_rready),

        .m_axi_awaddr   (m_dma_axi_awaddr),
        .m_axi_awvalid  (m_dma_axi_awvalid),
        .m_axi_awready  (m_dma_axi_awready),
        .m_axi_wdata    (m_dma_axi_wdata),
        .m_axi_wvalid   (m_dma_axi_wvalid),
        .m_axi_wready   (m_dma_axi_wready),
        .m_axi_bvalid   (m_dma_axi_bvalid),
        .m_axi_bready   (m_dma_axi_bready),

        .coproc_wen     (dma_coproc_wen),
        .coproc_addr    (dma_coproc_addr),
        .coproc_wdata_f (dma_coproc_wdata_f),
        .coproc_wdata_g (dma_coproc_wdata_g),
        .coproc_ren     (dma_coproc_ren),
        .coproc_raddr   (dma_coproc_raddr),
        .coproc_rdata   (pm_ext_rdata)
    );

    // =========================================================================
    // 5. Interrupt Controller (interrupt_ctrl)
    // =========================================================================
    interrupt_ctrl u_int_ctrl (
        .clk               (s_axi_aclk),
        .rst_n             (s_axi_aresetn),
        .coproc_done_pulse (core_done),
        .dma_done_pulse    (dma_done),
        .error_pulse       (1'b0),
        .ier               (irq_ier_r),
        .icr               (irq_icr_r),
        .isr               (irq_isr_w),
        .irq_out           (irq)
    );

    // =========================================================================
    // 6. Coprocessor Core BRAM Port Mux (DMA when active, else AXI-Lite slave)
    // =========================================================================
    wire        pm_ext_wen_f   = dma_busy ? (dma_coproc_wen && (dma_target_r == 2'd0)) : axi_ext_wen_f;
    wire        pm_ext_wen_g   = dma_busy ? (dma_coproc_wen && (dma_target_r == 2'd1)) : axi_ext_wen_g;
    wire [7:0]  pm_ext_addr    = dma_busy ? dma_coproc_addr    : axi_ext_addr;
    wire [11:0] pm_ext_wdata_f = dma_busy ? dma_coproc_wdata_f : axi_ext_wdata_f;
    wire [11:0] pm_ext_wdata_g = dma_busy ? dma_coproc_wdata_g : axi_ext_wdata_g;
    wire        pm_ext_ren     = dma_busy ? dma_coproc_ren     : axi_ext_ren;
    wire [7:0]  pm_ext_raddr   = dma_busy ? dma_coproc_raddr   : axi_ext_raddr;

    assign dbg_result_ren   = pm_ext_ren;
    assign dbg_result_raddr = pm_ext_raddr;
    assign dbg_result_rdata = pm_ext_rdata;

    poly_multiplier u_poly_mul_core (
        .clk         (s_axi_aclk),
        .rst_n       (s_axi_aresetn),
        .start       (core_start),
        .done        (core_done),
        .busy        (core_busy),
        .cycle_count (core_cycle_count),

        .ext_wen_f   (pm_ext_wen_f),
        .ext_wen_g   (pm_ext_wen_g),
        .ext_addr    (pm_ext_addr),
        .ext_wdata_f (pm_ext_wdata_f),
        .ext_wdata_g (pm_ext_wdata_g),

        .ext_ren     (pm_ext_ren),
        .ext_raddr   (pm_ext_raddr),
        .ext_rdata   (pm_ext_rdata)
    );

endmodule
