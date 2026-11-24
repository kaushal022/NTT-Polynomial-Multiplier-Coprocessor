`timescale 1ns / 1ps

module pl_hybrid_soc #(
    parameter integer BRAM_DEPTH     = 8192,
    parameter integer BRAM_ADDR_BITS = 13
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_100m CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_ps_axi, ASSOCIATED_RESET resetn, FREQ_HZ 100000000" *)
    input  wire        clk_100m,

    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 resetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        resetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi AWADDR" *)
    (* X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12, FREQ_HZ 100000000" *)
    input  wire [11:0] s_ps_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi AWPROT" *)
    input  wire [2:0]  s_ps_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi AWVALID" *)
    input  wire        s_ps_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi AWREADY" *)
    output wire        s_ps_axi_awready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi WDATA" *)
    input  wire [31:0] s_ps_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi WSTRB" *)
    input  wire [3:0]  s_ps_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi WVALID" *)
    input  wire        s_ps_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi WREADY" *)
    output wire        s_ps_axi_wready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi BRESP" *)
    output wire [1:0]  s_ps_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi BVALID" *)
    output wire        s_ps_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi BREADY" *)
    input  wire        s_ps_axi_bready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi ARADDR" *)
    input  wire [11:0] s_ps_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi ARPROT" *)
    input  wire [2:0]  s_ps_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi ARVALID" *)
    input  wire        s_ps_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi ARREADY" *)
    output wire        s_ps_axi_arready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi RDATA" *)
    output wire [31:0] s_ps_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi RRESP" *)
    output wire [1:0]  s_ps_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi RVALID" *)
    output wire        s_ps_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_ps_axi RREADY" *)
    input  wire        s_ps_axi_rready,

    output wire        uart_tx,
    input  wire        uart_rx,

    output wire [3:0]  led
);

    wire        cpu_trap;
    wire        mlkem_irq;
    wire        core_busy_w;
    wire        core_start_w;
    wire        core_done_w;
    wire [15:0] core_cycle_count_w;
    wire        dma_busy_w;
    wire        dma_done_w;
    wire        mb_req_pending_w;
    wire        mb_resp_ready_w;
    wire        mb_rv_running_w;

    wire        dbg_result_ren;
    wire [7:0]  dbg_result_raddr;
    wire [11:0] dbg_result_rdata;

    reg done_led_r;
    always @(posedge clk_100m or negedge resetn) begin
        if (!resetn)
            done_led_r <= 1'b0;
        else if (core_start_w)
            done_led_r <= 1'b0;
        else if (mb_resp_ready_w)
            done_led_r <= 1'b1;
    end

    assign led[0] = mb_rv_running_w;
    assign led[1] = core_busy_w | dma_busy_w;
    assign led[2] = done_led_r;
    assign led[3] = cpu_trap;

    wire [31:0] rv_awaddr, rv_wdata, rv_araddr, rv_rdata;
    wire [2:0]  rv_awprot, rv_arprot;
    wire [3:0]  rv_wstrb;
    wire [1:0]  rv_bresp, rv_rresp;
    wire        rv_awvalid, rv_awready, rv_wvalid, rv_wready, rv_bvalid, rv_bready;
    wire        rv_arvalid, rv_arready, rv_rvalid, rv_rready;

    wire [31:0] dma_awaddr, dma_wdata, dma_araddr, dma_rdata;
    wire [2:0]  dma_awprot, dma_arprot;
    wire [3:0]  dma_wstrb;
    wire [1:0]  dma_bresp, dma_rresp;
    wire        dma_awvalid, dma_awready, dma_wvalid, dma_wready, dma_bvalid, dma_bready;
    wire        dma_arvalid, dma_arready, dma_rvalid, dma_rready;

    wire [31:0] bus_awaddr, bus_wdata, bus_araddr, bus_rdata;
    wire [2:0]  bus_awprot, bus_arprot;
    wire [3:0]  bus_wstrb;
    wire [1:0]  bus_bresp, bus_rresp;
    wire        bus_awvalid, bus_awready, bus_wvalid, bus_wready, bus_bvalid, bus_bready;
    wire        bus_arvalid, bus_arready, bus_rvalid, bus_rready;

    wire [31:0] bram_awaddr, bram_wdata, bram_araddr, bram_rdata;
    wire [2:0]  bram_awprot, bram_arprot;
    wire [3:0]  bram_wstrb;
    wire [1:0]  bram_bresp, bram_rresp;
    wire        bram_awvalid, bram_awready, bram_wvalid, bram_wready, bram_bvalid, bram_bready;
    wire        bram_arvalid, bram_arready, bram_rvalid, bram_rready;

    wire [31:0] cop_awaddr, cop_wdata, cop_araddr, cop_rdata;
    wire [2:0]  cop_awprot, cop_arprot;
    wire [3:0]  cop_wstrb;
    wire [1:0]  cop_bresp, cop_rresp;
    wire        cop_awvalid, cop_awready, cop_wvalid, cop_wready, cop_bvalid, cop_bready;
    wire        cop_arvalid, cop_arready, cop_rvalid, cop_rready;

    wire [31:0] uart_awaddr, uart_wdata, uart_araddr, uart_rdata;
    wire [2:0]  uart_awprot, uart_arprot;
    wire [3:0]  uart_wstrb;
    wire [1:0]  uart_bresp, uart_rresp;
    wire        uart_awvalid, uart_awready, uart_wvalid, uart_wready, uart_bvalid, uart_bready;
    wire        uart_arvalid, uart_arready, uart_rvalid, uart_rready;

    wire [31:0] mb_awaddr, mb_wdata, mb_araddr, mb_rdata;
    wire [2:0]  mb_awprot, mb_arprot;
    wire [3:0]  mb_wstrb;
    wire [1:0]  mb_bresp, mb_rresp;
    wire        mb_awvalid, mb_awready, mb_wvalid, mb_wready, mb_bvalid, mb_bready;
    wire        mb_arvalid, mb_arready, mb_rvalid, mb_rready;

    picorv32_axi #(
        .ENABLE_COUNTERS      (1),
        .ENABLE_COUNTERS64    (0),
        .ENABLE_REGS_16_31    (1),
        .ENABLE_REGS_DUALPORT (1),
        .TWO_STAGE_SHIFT      (1),
        .BARREL_SHIFTER       (0),
        .TWO_CYCLE_COMPARE    (0),
        .TWO_CYCLE_ALU        (0),
        .COMPRESSED_ISA       (0),
        .CATCH_MISALIGN       (1),
        .CATCH_ILLINSN        (1),
        .ENABLE_PCPI          (0),
        .ENABLE_MUL           (0),
        .ENABLE_FAST_MUL      (0),
        .ENABLE_DIV           (0),
        .ENABLE_IRQ           (1),
        .ENABLE_IRQ_QREGS     (1),
        .ENABLE_IRQ_TIMER     (0),
        .ENABLE_TRACE         (0),
        .REGS_INIT_ZERO       (0),
        .MASKED_IRQ           (32'hFFFF_FFFE),
        .LATCHED_IRQ          (32'h0000_0000),
        .PROGADDR_RESET       (32'h0000_0000),
        .PROGADDR_IRQ         (32'h0000_0010),
        .STACKADDR            (32'h0000_8000)
    ) u_cpu (
        .clk           (clk_100m),
        .resetn        (resetn),
        .trap          (cpu_trap),

        .mem_axi_awvalid (rv_awvalid),
        .mem_axi_awready (rv_awready),
        .mem_axi_awaddr  (rv_awaddr),
        .mem_axi_awprot  (rv_awprot),
        .mem_axi_wvalid  (rv_wvalid),
        .mem_axi_wready  (rv_wready),
        .mem_axi_wdata   (rv_wdata),
        .mem_axi_wstrb   (rv_wstrb),
        .mem_axi_bvalid  (rv_bvalid),
        .mem_axi_bready  (rv_bready),
        .mem_axi_arvalid (rv_arvalid),
        .mem_axi_arready (rv_arready),
        .mem_axi_araddr  (rv_araddr),
        .mem_axi_arprot  (rv_arprot),
        .mem_axi_rvalid  (rv_rvalid),
        .mem_axi_rready  (rv_rready),
        .mem_axi_rdata   (rv_rdata),

        .pcpi_valid    (),
        .pcpi_insn     (),
        .pcpi_rs1      (),
        .pcpi_rs2      (),
        .pcpi_wr       (1'b0),
        .pcpi_rd       (32'b0),
        .pcpi_wait     (1'b0),
        .pcpi_ready    (1'b0),

        .irq           ({31'b0, mlkem_irq}),
        .eoi           (),
        .trace_valid   (),
        .trace_data    ()
    );

    axi_arbiter_2m u_arbiter (
        .clk            (clk_100m),
        .resetn         (resetn),

        .m0_axi_awaddr  (rv_awaddr),  .m0_axi_awprot (rv_awprot),  .m0_axi_awvalid (rv_awvalid), .m0_axi_awready (rv_awready),
        .m0_axi_wdata   (rv_wdata),   .m0_axi_wstrb  (rv_wstrb),   .m0_axi_wvalid  (rv_wvalid),  .m0_axi_wready  (rv_wready),
        .m0_axi_bresp   (rv_bresp),   .m0_axi_bvalid (rv_bvalid),  .m0_axi_bready  (rv_bready),
        .m0_axi_araddr  (rv_araddr),  .m0_axi_arprot (rv_arprot),  .m0_axi_arvalid (rv_arvalid), .m0_axi_arready (rv_arready),
        .m0_axi_rdata   (rv_rdata),   .m0_axi_rresp  (rv_rresp),   .m0_axi_rvalid  (rv_rvalid),  .m0_axi_rready  (rv_rready),

        .m1_axi_awaddr  (dma_awaddr), .m1_axi_awprot (dma_awprot), .m1_axi_awvalid (dma_awvalid), .m1_axi_awready (dma_awready),
        .m1_axi_wdata   (dma_wdata),  .m1_axi_wstrb  (dma_wstrb),  .m1_axi_wvalid  (dma_wvalid),  .m1_axi_wready  (dma_wready),
        .m1_axi_bresp   (dma_bresp),  .m1_axi_bvalid (dma_bvalid), .m1_axi_bready  (dma_bready),
        .m1_axi_araddr  (dma_araddr), .m1_axi_arprot (dma_arprot), .m1_axi_arvalid (dma_arvalid), .m1_axi_arready (dma_arready),
        .m1_axi_rdata   (dma_rdata),  .m1_axi_rresp  (dma_rresp),  .m1_axi_rvalid  (dma_rvalid),  .m1_axi_rready  (dma_rready),

        .s_axi_awaddr   (bus_awaddr), .s_axi_awprot  (bus_awprot), .s_axi_awvalid  (bus_awvalid), .s_axi_awready  (bus_awready),
        .s_axi_wdata    (bus_wdata),  .s_axi_wstrb   (bus_wstrb),  .s_axi_wvalid   (bus_wvalid),  .s_axi_wready   (bus_wready),
        .s_axi_bresp    (bus_bresp),  .s_axi_bvalid  (bus_bvalid), .s_axi_bready   (bus_bready),
        .s_axi_araddr   (bus_araddr), .s_axi_arprot  (bus_arprot), .s_axi_arvalid  (bus_arvalid), .s_axi_arready  (bus_arready),
        .s_axi_rdata    (bus_rdata),  .s_axi_rresp   (bus_rresp),  .s_axi_rvalid   (bus_rvalid),  .s_axi_rready   (bus_rready)
    );

    axi_demux_4s u_demux (
        .clk            (clk_100m),
        .resetn         (resetn),

        .m_axi_awaddr   (bus_awaddr),  .m_axi_awprot (bus_awprot),  .m_axi_awvalid (bus_awvalid), .m_axi_awready (bus_awready),
        .m_axi_wdata    (bus_wdata),   .m_axi_wstrb  (bus_wstrb),   .m_axi_wvalid  (bus_wvalid),  .m_axi_wready  (bus_wready),
        .m_axi_bresp    (bus_bresp),   .m_axi_bvalid (bus_bvalid),  .m_axi_bready  (bus_bready),
        .m_axi_araddr   (bus_araddr),  .m_axi_arprot (bus_arprot),  .m_axi_arvalid (bus_arvalid), .m_axi_arready (bus_arready),
        .m_axi_rdata    (bus_rdata),   .m_axi_rresp  (bus_rresp),   .m_axi_rvalid  (bus_rvalid),  .m_axi_rready  (bus_rready),

        .s0_axi_awaddr  (bram_awaddr), .s0_axi_awprot (bram_awprot), .s0_axi_awvalid (bram_awvalid), .s0_axi_awready (bram_awready),
        .s0_axi_wdata   (bram_wdata),  .s0_axi_wstrb  (bram_wstrb),  .s0_axi_wvalid  (bram_wvalid),  .s0_axi_wready  (bram_wready),
        .s0_axi_bresp   (bram_bresp),  .s0_axi_bvalid (bram_bvalid), .s0_axi_bready  (bram_bready),
        .s0_axi_araddr  (bram_araddr), .s0_axi_arprot (bram_arprot), .s0_axi_arvalid (bram_arvalid), .s0_axi_arready (bram_arready),
        .s0_axi_rdata   (bram_rdata),  .s0_axi_rresp  (bram_rresp),  .s0_axi_rvalid  (bram_rvalid),  .s0_axi_rready  (bram_rready),

        .s1_axi_awaddr  (cop_awaddr),  .s1_axi_awprot (cop_awprot),  .s1_axi_awvalid (cop_awvalid), .s1_axi_awready (cop_awready),
        .s1_axi_wdata   (cop_wdata),   .s1_axi_wstrb  (cop_wstrb),   .s1_axi_wvalid  (cop_wvalid),  .s1_axi_wready  (cop_wready),
        .s1_axi_bresp   (cop_bresp),   .s1_axi_bvalid (cop_bvalid),  .s1_axi_bready  (cop_bready),
        .s1_axi_araddr  (cop_araddr),  .s1_axi_arprot (cop_arprot),  .s1_axi_arvalid (cop_arvalid), .s1_axi_arready (cop_arready),
        .s1_axi_rdata   (cop_rdata),   .s1_axi_rresp  (cop_rresp),   .s1_axi_rvalid  (cop_rvalid),  .s1_axi_rready  (cop_rready),

        .s2_axi_awaddr  (uart_awaddr), .s2_axi_awprot (uart_awprot), .s2_axi_awvalid (uart_awvalid), .s2_axi_awready (uart_awready),
        .s2_axi_wdata   (uart_wdata),  .s2_axi_wstrb  (uart_wstrb),  .s2_axi_wvalid  (uart_wvalid),  .s2_axi_wready  (uart_wready),
        .s2_axi_bresp   (uart_bresp),  .s2_axi_bvalid (uart_bvalid), .s2_axi_bready  (uart_bready),
        .s2_axi_araddr  (uart_araddr), .s2_axi_arprot (uart_arprot), .s2_axi_arvalid (uart_arvalid), .s2_axi_arready (uart_arready),
        .s2_axi_rdata   (uart_rdata),  .s2_axi_rresp  (uart_rresp),  .s2_axi_rvalid  (uart_rvalid),  .s2_axi_rready  (uart_rready),

        .s3_axi_awaddr  (mb_awaddr),   .s3_axi_awprot (mb_awprot),   .s3_axi_awvalid (mb_awvalid),  .s3_axi_awready (mb_awready),
        .s3_axi_wdata   (mb_wdata),    .s3_axi_wstrb  (mb_wstrb),    .s3_axi_wvalid  (mb_wvalid),   .s3_axi_wready  (mb_wready),
        .s3_axi_bresp   (mb_bresp),    .s3_axi_bvalid (mb_bvalid),   .s3_axi_bready  (mb_bready),
        .s3_axi_araddr  (mb_araddr),   .s3_axi_arprot (mb_arprot),   .s3_axi_arvalid (mb_arvalid),  .s3_axi_arready (mb_arready),
        .s3_axi_rdata   (mb_rdata),    .s3_axi_rresp  (mb_rresp),    .s3_axi_rvalid  (mb_rvalid),   .s3_axi_rready  (mb_rready)
    );

    (* ram_style = "block" *) reg [31:0] bram [0:BRAM_DEPTH-1];

    initial begin
        $readmemh("firmware_hybrid.hex", bram);
    end

    reg [BRAM_ADDR_BITS-1:0] bram_waddr_r;
    reg [31:0]               bram_wdata_r;
    reg [3:0]                bram_wstrb_r;
    reg                      bram_aw_done, bram_w_done, bram_bvalid_r;

    assign bram_awready = !bram_aw_done && !bram_bvalid_r;
    assign bram_wready  = !bram_w_done  && !bram_bvalid_r;
    assign bram_bresp   = 2'b00;
    assign bram_bvalid  = bram_bvalid_r;

    wire bram_aw_active = bram_awvalid && bram_awready;
    wire bram_w_active  = bram_wvalid  && bram_wready;
    wire [BRAM_ADDR_BITS-1:0] bram_eff_waddr = bram_aw_active ? bram_awaddr[BRAM_ADDR_BITS+1:2] : bram_waddr_r;
    wire [31:0]               bram_eff_wdata = bram_w_active  ? bram_wdata : bram_wdata_r;
    wire [3:0]                bram_eff_wstrb = bram_w_active  ? bram_wstrb : bram_wstrb_r;
    wire bram_do_write = (bram_aw_active || bram_aw_done) && (bram_w_active || bram_w_done) && !bram_bvalid_r;

    always @(posedge clk_100m) begin
        if (bram_do_write) begin
            if (bram_eff_wstrb[0]) bram[bram_eff_waddr][ 7: 0] <= bram_eff_wdata[ 7: 0];
            if (bram_eff_wstrb[1]) bram[bram_eff_waddr][15: 8] <= bram_eff_wdata[15: 8];
            if (bram_eff_wstrb[2]) bram[bram_eff_waddr][23:16] <= bram_eff_wdata[23:16];
            if (bram_eff_wstrb[3]) bram[bram_eff_waddr][31:24] <= bram_eff_wdata[31:24];
        end
    end

    always @(posedge clk_100m or negedge resetn) begin
        if (!resetn) begin
            bram_aw_done  <= 1'b0;
            bram_w_done   <= 1'b0;
            bram_bvalid_r <= 1'b0;
            bram_waddr_r  <= {BRAM_ADDR_BITS{1'b0}};
            bram_wdata_r  <= 32'd0;
            bram_wstrb_r  <= 4'd0;
        end else begin
            if (bram_aw_active) begin
                bram_waddr_r <= bram_awaddr[BRAM_ADDR_BITS+1:2];
                bram_aw_done <= 1'b1;
            end
            if (bram_w_active) begin
                bram_wdata_r <= bram_wdata;
                bram_wstrb_r <= bram_wstrb;
                bram_w_done  <= 1'b1;
            end
            if (bram_do_write) begin
                bram_bvalid_r <= 1'b1;
                bram_aw_done  <= 1'b0;
                bram_w_done   <= 1'b0;
            end else if (bram_bvalid_r && bram_bready) begin
                bram_bvalid_r <= 1'b0;
            end
        end
    end

    reg [31:0] bram_rdata_r;
    reg        bram_rvalid_r;
    always @(posedge clk_100m) begin
        if (bram_arvalid && bram_arready)
            bram_rdata_r <= bram[bram_araddr[BRAM_ADDR_BITS+1:2]];
    end

    assign bram_arready = !bram_rvalid_r;
    assign bram_rdata   = bram_rdata_r;
    assign bram_rresp   = 2'b00;
    assign bram_rvalid  = bram_rvalid_r;

    always @(posedge clk_100m or negedge resetn) begin
        if (!resetn)
            bram_rvalid_r <= 1'b0;
        else if (bram_arvalid && bram_arready)
            bram_rvalid_r <= 1'b1;
        else if (bram_rvalid_r && bram_rready)
            bram_rvalid_r <= 1'b0;
    end

    mlkem_dma_coproc_top #(
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(6)
    ) u_mlkem (
        .s_axi_aclk       (clk_100m),
        .s_axi_aresetn    (resetn),

        .s_axi_awaddr     (cop_awaddr[5:0]),
        .s_axi_awprot     (cop_awprot),
        .s_axi_awvalid    (cop_awvalid),
        .s_axi_awready    (cop_awready),
        .s_axi_wdata      (cop_wdata),
        .s_axi_wstrb      (cop_wstrb),
        .s_axi_wvalid     (cop_wvalid),
        .s_axi_wready     (cop_wready),
        .s_axi_bresp      (cop_bresp),
        .s_axi_bvalid     (cop_bvalid),
        .s_axi_bready     (cop_bready),
        .s_axi_araddr     (cop_araddr[5:0]),
        .s_axi_arprot     (cop_arprot),
        .s_axi_arvalid    (cop_arvalid),
        .s_axi_arready    (cop_arready),
        .s_axi_rdata      (cop_rdata),
        .s_axi_rresp      (cop_rresp),
        .s_axi_rvalid     (cop_rvalid),
        .s_axi_rready     (cop_rready),

        .m_dma_axi_awaddr (dma_awaddr),
        .m_dma_axi_awprot (dma_awprot),
        .m_dma_axi_awvalid(dma_awvalid),
        .m_dma_axi_awready(dma_awready),
        .m_dma_axi_wdata  (dma_wdata),
        .m_dma_axi_wstrb  (dma_wstrb),
        .m_dma_axi_wvalid (dma_wvalid),
        .m_dma_axi_wready (dma_wready),
        .m_dma_axi_bresp  (dma_bresp),
        .m_dma_axi_bvalid (dma_bvalid),
        .m_dma_axi_bready (dma_bready),
        .m_dma_axi_araddr (dma_araddr),
        .m_dma_axi_arprot (dma_arprot),
        .m_dma_axi_arvalid(dma_arvalid),
        .m_dma_axi_arready(dma_arready),
        .m_dma_axi_rdata  (dma_rdata),
        .m_dma_axi_rresp  (dma_rresp),
        .m_dma_axi_rvalid (dma_rvalid),
        .m_dma_axi_rready (dma_rready),

        .irq              (mlkem_irq),
        .core_busy        (core_busy_w),
        .core_start       (core_start_w),
        .core_done        (core_done_w),
        .core_cycle_count (core_cycle_count_w),
        .dma_busy         (dma_busy_w),
        .dma_done         (dma_done_w),

        .dbg_result_ren   (dbg_result_ren),
        .dbg_result_raddr (dbg_result_raddr),
        .dbg_result_rdata (dbg_result_rdata)
    );

    reg  [3:0]  uart_div_we;
    reg  [31:0] uart_div_di;
    wire [31:0] uart_div_do;
    reg         uart_dat_we, uart_dat_re;
    reg  [31:0] uart_dat_di;
    wire [31:0] uart_dat_do;
    wire        uart_dat_wait;

    simpleuart #(.DEFAULT_DIV(866)) u_uart (
        .clk          (clk_100m),
        .resetn       (resetn),
        .ser_tx       (uart_tx),
        .ser_rx       (uart_rx),
        .reg_div_we   (uart_div_we),
        .reg_div_di   (uart_div_di),
        .reg_div_do   (uart_div_do),
        .reg_dat_we   (uart_dat_we),
        .reg_dat_re   (uart_dat_re),
        .reg_dat_di   (uart_dat_di),
        .reg_dat_do   (uart_dat_do),
        .reg_dat_wait (uart_dat_wait)
    );

    localparam UART_ST_IDLE   = 2'd0;
    localparam UART_ST_WAIT_W = 2'd1;
    localparam UART_ST_WAIT_B = 2'd2;

    reg [1:0]  uart_wr_state;
    reg [31:0] uart_wr_addr_r, uart_rd_data_r;
    reg        uart_rd_valid_r, uart_wr_resp_r;

    assign uart_awready = (uart_wr_state == UART_ST_IDLE);
    assign uart_wready  = (uart_wr_state == UART_ST_WAIT_W) && !uart_dat_wait;
    assign uart_bresp   = 2'b00;
    assign uart_bvalid  = uart_wr_resp_r;
    assign uart_arready = !uart_rd_valid_r;
    assign uart_rdata   = uart_rd_data_r;
    assign uart_rresp   = 2'b00;
    assign uart_rvalid  = uart_rd_valid_r;

    always @(posedge clk_100m or negedge resetn) begin
        if (!resetn) begin
            uart_wr_state   <= UART_ST_IDLE;
            uart_wr_addr_r  <= 32'd0;
            uart_div_we     <= 4'd0;
            uart_div_di     <= 32'd0;
            uart_dat_we     <= 1'b0;
            uart_dat_re     <= 1'b0;
            uart_dat_di     <= 32'd0;
            uart_rd_data_r  <= 32'd0;
            uart_rd_valid_r <= 1'b0;
            uart_wr_resp_r  <= 1'b0;
        end else begin
            uart_div_we <= 4'd0;
            uart_dat_we <= 1'b0;
            uart_dat_re <= 1'b0;

            case (uart_wr_state)
                UART_ST_IDLE: begin
                    if (uart_awvalid) begin
                        uart_wr_addr_r <= uart_awaddr;
                        uart_wr_state  <= UART_ST_WAIT_W;
                    end
                end
                UART_ST_WAIT_W: begin
                    if (uart_wvalid && !uart_dat_wait) begin
                        if (uart_wr_addr_r[3:0] == 4'h4) begin
                            uart_div_we <= uart_wstrb;
                            uart_div_di <= uart_wdata;
                        end else if (uart_wr_addr_r[3:0] == 4'h8) begin
                            uart_dat_we <= 1'b1;
                            uart_dat_di <= uart_wdata;
                        end
                        uart_wr_resp_r <= 1'b1;
                        uart_wr_state  <= UART_ST_WAIT_B;
                    end
                end
                UART_ST_WAIT_B: begin
                    if (uart_bready) begin
                        uart_wr_resp_r <= 1'b0;
                        uart_wr_state  <= UART_ST_IDLE;
                    end
                end
                default: uart_wr_state <= UART_ST_IDLE;
            endcase

            if (uart_arvalid && uart_arready) begin
                uart_rd_valid_r <= 1'b1;
                if (uart_araddr[3:0] == 4'h4) begin
                    uart_rd_data_r <= uart_div_do;
                end else if (uart_araddr[3:0] == 4'h8) begin
                    uart_rd_data_r <= uart_dat_do;
                    uart_dat_re    <= 1'b1;
                end else begin
                    uart_rd_data_r <= 32'd0;
                end
            end else if (uart_rd_valid_r && uart_rready) begin
                uart_rd_valid_r <= 1'b0;
            end
        end
    end

    axi_mailbox #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) u_mailbox (
        .clk            (clk_100m),
        .resetn         (resetn),

        .s0_axi_awaddr  (s_ps_axi_awaddr),
        .s0_axi_awprot  (s_ps_axi_awprot),
        .s0_axi_awvalid (s_ps_axi_awvalid),
        .s0_axi_awready (s_ps_axi_awready),
        .s0_axi_wdata   (s_ps_axi_wdata),
        .s0_axi_wstrb   (s_ps_axi_wstrb),
        .s0_axi_wvalid  (s_ps_axi_wvalid),
        .s0_axi_wready  (s_ps_axi_wready),
        .s0_axi_bresp   (s_ps_axi_bresp),
        .s0_axi_bvalid  (s_ps_axi_bvalid),
        .s0_axi_bready  (s_ps_axi_bready),
        .s0_axi_araddr  (s_ps_axi_araddr),
        .s0_axi_arprot  (s_ps_axi_arprot),
        .s0_axi_arvalid (s_ps_axi_arvalid),
        .s0_axi_arready (s_ps_axi_arready),
        .s0_axi_rdata   (s_ps_axi_rdata),
        .s0_axi_rresp   (s_ps_axi_rresp),
        .s0_axi_rvalid  (s_ps_axi_rvalid),
        .s0_axi_rready  (s_ps_axi_rready),

        .s1_axi_awaddr  (mb_awaddr[11:0]),
        .s1_axi_awprot  (mb_awprot),
        .s1_axi_awvalid (mb_awvalid),
        .s1_axi_awready (mb_awready),
        .s1_axi_wdata   (mb_wdata),
        .s1_axi_wstrb   (mb_wstrb),
        .s1_axi_wvalid  (mb_wvalid),
        .s1_axi_wready  (mb_wready),
        .s1_axi_bresp   (mb_bresp),
        .s1_axi_bvalid  (mb_bvalid),
        .s1_axi_bready  (mb_bready),
        .s1_axi_araddr  (mb_araddr[11:0]),
        .s1_axi_arprot  (mb_arprot),
        .s1_axi_arvalid (mb_arvalid),
        .s1_axi_arready (mb_arready),
        .s1_axi_rdata   (mb_rdata),
        .s1_axi_rresp   (mb_rresp),
        .s1_axi_rvalid  (mb_rvalid),
        .s1_axi_rready  (mb_rready),

        .req_pending_o  (mb_req_pending_w),
        .resp_ready_o   (mb_resp_ready_w),
        .rv_running_o   (mb_rv_running_w)
    );

endmodule
