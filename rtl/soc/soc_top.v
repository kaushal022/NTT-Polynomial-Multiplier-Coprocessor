`timescale 1ns / 1ps

module soc_top (
    input  wire        sys_clk_125,
    input  wire        sys_rst_n,
    output wire        uart_tx,
    input  wire        uart_rx,
    output wire [3:0]  led
);

    wire clk_100m;
    wire pll_locked;
    wire pll_fb;

    PLLE2_BASE #(
        .CLKIN1_PERIOD   (8.000),
        .CLKFBOUT_MULT   (8),
        .DIVCLK_DIVIDE   (1),
        .CLKOUT0_DIVIDE  (10),
        .CLKOUT0_PHASE   (0.000),
        .CLKOUT0_DUTY_CYCLE (0.500),
        .BANDWIDTH       ("OPTIMIZED"),
        .STARTUP_WAIT    ("FALSE")
    ) u_pll (
        .CLKIN1   (sys_clk_125),
        .CLKFBIN  (pll_fb),
        .CLKFBOUT (pll_fb),
        .CLKOUT0  (clk_100m),
        .LOCKED   (pll_locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    reg  rst_sync_0, rst_sync_1;
    wire sys_reset_async = sys_rst_n | !pll_locked;

    always @(posedge clk_100m or posedge sys_reset_async) begin
        if (sys_reset_async) begin
            rst_sync_0 <= 1'b1;
            rst_sync_1 <= 1'b1;
        end else begin
            rst_sync_0 <= 1'b0;
            rst_sync_1 <= rst_sync_0;
        end
    end

    (* mark_debug = "true" *) wire resetn = ~rst_sync_1;

    wire [31:0] cpu_axi_awaddr;
    wire [2:0]  cpu_axi_awprot;
    wire        cpu_axi_awvalid;
    wire        cpu_axi_awready;

    wire [31:0] cpu_axi_wdata;
    wire [3:0]  cpu_axi_wstrb;
    wire        cpu_axi_wvalid;
    wire        cpu_axi_wready;

    wire [1:0]  cpu_axi_bresp;
    wire        cpu_axi_bvalid;
    wire        cpu_axi_bready;

    wire [31:0] cpu_axi_araddr;
    wire [2:0]  cpu_axi_arprot;
    wire        cpu_axi_arvalid;
    wire        cpu_axi_arready;

    wire [31:0] cpu_axi_rdata;
    wire [1:0]  cpu_axi_rresp;
    wire        cpu_axi_rvalid;
    wire        cpu_axi_rready;

    (* mark_debug = "true" *) wire        mlkem_irq;
    wire [31:0] cpu_irq = {31'b0, mlkem_irq};
    (* mark_debug = "true" *) wire        cpu_trap;

    picorv32_axi #(
        .ENABLE_COUNTERS   (1),
        .ENABLE_REGS_16_31 (1),
        .CATCH_MISALIGN    (1),
        .CATCH_ILLINSN     (1),
        .ENABLE_IRQ        (1),
        .ENABLE_IRQ_QREGS  (1),
        .ENABLE_IRQ_TIMER  (0),
        .ENABLE_MUL        (0),
        .ENABLE_DIV        (0),
        .MASKED_IRQ        (32'h0000_0000),
        .LATCHED_IRQ       (32'h0000_0000),
        .PROGADDR_RESET    (32'h0000_0000),
        .PROGADDR_IRQ      (32'h0000_0010),
        .STACKADDR         (32'h0000_8000)
    ) u_cpu (
        .clk             (clk_100m),
        .resetn          (resetn),
        .trap            (cpu_trap),

        .mem_axi_awvalid (cpu_axi_awvalid),
        .mem_axi_awready (cpu_axi_awready),
        .mem_axi_awaddr  (cpu_axi_awaddr),
        .mem_axi_awprot  (cpu_axi_awprot),

        .mem_axi_wvalid  (cpu_axi_wvalid),
        .mem_axi_wready  (cpu_axi_wready),
        .mem_axi_wdata   (cpu_axi_wdata),
        .mem_axi_wstrb   (cpu_axi_wstrb),

        .mem_axi_bvalid  (cpu_axi_bvalid),
        .mem_axi_bready  (cpu_axi_bready),

        .mem_axi_arvalid (cpu_axi_arvalid),
        .mem_axi_arready (cpu_axi_arready),
        .mem_axi_araddr  (cpu_axi_araddr),
        .mem_axi_arprot  (cpu_axi_arprot),

        .mem_axi_rvalid  (cpu_axi_rvalid),
        .mem_axi_rready  (cpu_axi_rready),
        .mem_axi_rdata   (cpu_axi_rdata),

        .irq             (cpu_irq),
        .eoi             (),

        .pcpi_valid      (),
        .pcpi_insn       (),
        .pcpi_rs1        (),
        .pcpi_rs2        (),
        .pcpi_wr         (1'b0),
        .pcpi_rd         (32'b0),
        .pcpi_wait       (1'b0),
        .pcpi_ready      (1'b0),

        .trace_valid     (),
        .trace_data      ()
    );

    wire [31:0] bram_axi_awaddr;
    wire [2:0]  bram_axi_awprot;
    wire        bram_axi_awvalid;
    wire        bram_axi_awready;
    wire [31:0] bram_axi_wdata;
    wire [3:0]  bram_axi_wstrb;
    wire        bram_axi_wvalid;
    wire        bram_axi_wready;
    wire [1:0]  bram_axi_bresp;
    wire        bram_axi_bvalid;
    wire        bram_axi_bready;
    wire [31:0] bram_axi_araddr;
    wire [2:0]  bram_axi_arprot;
    wire        bram_axi_arvalid;
    wire        bram_axi_arready;
    wire [31:0] bram_axi_rdata;
    wire [1:0]  bram_axi_rresp;
    wire        bram_axi_rvalid;
    wire        bram_axi_rready;

    wire [31:0] mlkem_axi_awaddr;
    wire [2:0]  mlkem_axi_awprot;
    wire        mlkem_axi_awvalid;
    wire        mlkem_axi_awready;
    wire [31:0] mlkem_axi_wdata;
    wire [3:0]  mlkem_axi_wstrb;
    wire        mlkem_axi_wvalid;
    wire        mlkem_axi_wready;
    wire [1:0]  mlkem_axi_bresp;
    wire        mlkem_axi_bvalid;
    wire        mlkem_axi_bready;
    wire [31:0] mlkem_axi_araddr;
    wire [2:0]  mlkem_axi_arprot;
    wire        mlkem_axi_arvalid;
    wire        mlkem_axi_arready;
    wire [31:0] mlkem_axi_rdata;
    wire [1:0]  mlkem_axi_rresp;
    wire        mlkem_axi_rvalid;
    wire        mlkem_axi_rready;

    wire [31:0] uart_axi_awaddr;
    wire [2:0]  uart_axi_awprot;
    wire        uart_axi_awvalid;
    wire        uart_axi_awready;
    wire [31:0] uart_axi_wdata;
    wire [3:0]  uart_axi_wstrb;
    wire        uart_axi_wvalid;
    wire        uart_axi_wready;
    wire [1:0]  uart_axi_bresp;
    wire        uart_axi_bvalid;
    wire        uart_axi_bready;
    wire [31:0] uart_axi_araddr;
    wire [2:0]  uart_axi_arprot;
    wire        uart_axi_arvalid;
    wire        uart_axi_arready;
    wire [31:0] uart_axi_rdata;
    wire [1:0]  uart_axi_rresp;
    wire        uart_axi_rvalid;
    wire        uart_axi_rready;

    axi_demux u_demux (
        .clk            (clk_100m),
        .resetn         (resetn),

        .m_axi_awaddr   (cpu_axi_awaddr),
        .m_axi_awprot   (cpu_axi_awprot),
        .m_axi_awvalid  (cpu_axi_awvalid),
        .m_axi_awready  (cpu_axi_awready),
        .m_axi_wdata    (cpu_axi_wdata),
        .m_axi_wstrb    (cpu_axi_wstrb),
        .m_axi_wvalid   (cpu_axi_wvalid),
        .m_axi_wready   (cpu_axi_wready),
        .m_axi_bresp    (cpu_axi_bresp),
        .m_axi_bvalid   (cpu_axi_bvalid),
        .m_axi_bready   (cpu_axi_bready),
        .m_axi_araddr   (cpu_axi_araddr),
        .m_axi_arprot   (cpu_axi_arprot),
        .m_axi_arvalid  (cpu_axi_arvalid),
        .m_axi_arready  (cpu_axi_arready),
        .m_axi_rdata    (cpu_axi_rdata),
        .m_axi_rresp    (cpu_axi_rresp),
        .m_axi_rvalid   (cpu_axi_rvalid),
        .m_axi_rready   (cpu_axi_rready),

        .s0_axi_awaddr  (bram_axi_awaddr),
        .s0_axi_awprot  (bram_axi_awprot),
        .s0_axi_awvalid (bram_axi_awvalid),
        .s0_axi_awready (bram_axi_awready),
        .s0_axi_wdata   (bram_axi_wdata),
        .s0_axi_wstrb   (bram_axi_wstrb),
        .s0_axi_wvalid  (bram_axi_wvalid),
        .s0_axi_wready  (bram_axi_wready),
        .s0_axi_bresp   (bram_axi_bresp),
        .s0_axi_bvalid  (bram_axi_bvalid),
        .s0_axi_bready  (bram_axi_bready),
        .s0_axi_araddr  (bram_axi_araddr),
        .s0_axi_arprot  (bram_axi_arprot),
        .s0_axi_arvalid (bram_axi_arvalid),
        .s0_axi_arready (bram_axi_arready),
        .s0_axi_rdata   (bram_axi_rdata),
        .s0_axi_rresp   (bram_axi_rresp),
        .s0_axi_rvalid  (bram_axi_rvalid),
        .s0_axi_rready  (bram_axi_rready),

        .s1_axi_awaddr  (mlkem_axi_awaddr),
        .s1_axi_awprot  (mlkem_axi_awprot),
        .s1_axi_awvalid (mlkem_axi_awvalid),
        .s1_axi_awready (mlkem_axi_awready),
        .s1_axi_wdata   (mlkem_axi_wdata),
        .s1_axi_wstrb   (mlkem_axi_wstrb),
        .s1_axi_wvalid  (mlkem_axi_wvalid),
        .s1_axi_wready  (mlkem_axi_wready),
        .s1_axi_bresp   (mlkem_axi_bresp),
        .s1_axi_bvalid  (mlkem_axi_bvalid),
        .s1_axi_bready  (mlkem_axi_bready),
        .s1_axi_araddr  (mlkem_axi_araddr),
        .s1_axi_arprot  (mlkem_axi_arprot),
        .s1_axi_arvalid (mlkem_axi_arvalid),
        .s1_axi_arready (mlkem_axi_arready),
        .s1_axi_rdata   (mlkem_axi_rdata),
        .s1_axi_rresp   (mlkem_axi_rresp),
        .s1_axi_rvalid  (mlkem_axi_rvalid),
        .s1_axi_rready  (mlkem_axi_rready),

        .s2_axi_awaddr  (uart_axi_awaddr),
        .s2_axi_awprot  (uart_axi_awprot),
        .s2_axi_awvalid (uart_axi_awvalid),
        .s2_axi_awready (uart_axi_awready),
        .s2_axi_wdata   (uart_axi_wdata),
        .s2_axi_wstrb   (uart_axi_wstrb),
        .s2_axi_wvalid  (uart_axi_wvalid),
        .s2_axi_wready  (uart_axi_wready),
        .s2_axi_bresp   (uart_axi_bresp),
        .s2_axi_bvalid  (uart_axi_bvalid),
        .s2_axi_bready  (uart_axi_bready),
        .s2_axi_araddr  (uart_axi_araddr),
        .s2_axi_arprot  (uart_axi_arprot),
        .s2_axi_arvalid (uart_axi_arvalid),
        .s2_axi_arready (uart_axi_arready),
        .s2_axi_rdata   (uart_axi_rdata),
        .s2_axi_rresp   (uart_axi_rresp),
        .s2_axi_rvalid  (uart_axi_rvalid),
        .s2_axi_rready  (uart_axi_rready)
    );

    localparam BRAM_DEPTH     = 8192;
    localparam BRAM_ADDR_BITS = 13;

    (* ram_style = "block" *) reg [31:0] bram [0:BRAM_DEPTH-1];

    initial begin
    $readmemh("firmware.hex", bram);
end

    reg [BRAM_ADDR_BITS-1:0] bram_waddr_r;
    reg [31:0]               bram_wdata_r;
    reg [3:0]                bram_wstrb_r;
    reg                      bram_aw_done;
    reg                      bram_w_done;
    reg                      bram_bvalid_r;

    assign bram_axi_awready = !bram_aw_done && !bram_bvalid_r;
    assign bram_axi_wready  = !bram_w_done  && !bram_bvalid_r;
    assign bram_axi_bresp   = 2'b00;
    assign bram_axi_bvalid  = bram_bvalid_r;

    wire aw_active = (bram_axi_awvalid && bram_axi_awready);
    wire w_active  = (bram_axi_wvalid  && bram_axi_wready);

    wire [BRAM_ADDR_BITS-1:0] eff_waddr = aw_active ? bram_axi_awaddr[BRAM_ADDR_BITS+1:2] : bram_waddr_r;
    wire [31:0]               eff_wdata = w_active  ? bram_axi_wdata : bram_wdata_r;
    wire [3:0]                eff_wstrb = w_active  ? bram_axi_wstrb : bram_wstrb_r;

    wire bram_do_write = (aw_active || bram_aw_done) && (w_active || bram_w_done) && !bram_bvalid_r;

    always @(posedge clk_100m) begin
        if (bram_do_write) begin
            if (eff_wstrb[0]) bram[eff_waddr][ 7: 0] <= eff_wdata[ 7: 0];
            if (eff_wstrb[1]) bram[eff_waddr][15: 8] <= eff_wdata[15: 8];
            if (eff_wstrb[2]) bram[eff_waddr][23:16] <= eff_wdata[23:16];
            if (eff_wstrb[3]) bram[eff_waddr][31:24] <= eff_wdata[31:24];
        end
    end

    always @(posedge clk_100m or negedge resetn) begin
        if (!resetn) begin
            bram_aw_done  <= 1'b0;
            bram_w_done   <= 1'b0;
            bram_bvalid_r <= 1'b0;
            bram_waddr_r  <= {BRAM_ADDR_BITS{1'b0}};
            bram_wdata_r  <= 32'b0;
            bram_wstrb_r  <= 4'b0;
        end else begin
            if (aw_active) begin
                bram_waddr_r <= bram_axi_awaddr[BRAM_ADDR_BITS+1:2];
                bram_aw_done <= 1'b1;
            end
            if (w_active) begin
                bram_wdata_r <= bram_axi_wdata;
                bram_wstrb_r <= bram_axi_wstrb;
                bram_w_done  <= 1'b1;
            end

            if (bram_do_write) begin
                bram_bvalid_r <= 1'b1;
                bram_aw_done  <= 1'b0;
                bram_w_done   <= 1'b0;
            end else if (bram_bvalid_r && bram_axi_bready) begin
                bram_bvalid_r <= 1'b0;
            end
        end
    end

    reg [31:0] bram_rdata_r;
    always @(posedge clk_100m) begin
        if (bram_axi_arvalid && bram_axi_arready) begin
            bram_rdata_r <= bram[bram_axi_araddr[BRAM_ADDR_BITS+1:2]];
        end
    end

    reg bram_rvalid_r;
    assign bram_axi_arready = !bram_rvalid_r;
    assign bram_axi_rdata   = bram_rdata_r;
    assign bram_axi_rresp   = 2'b00;
    assign bram_axi_rvalid  = bram_rvalid_r;

    always @(posedge clk_100m or negedge resetn) begin
        if (!resetn) begin
            bram_rvalid_r <= 1'b0;
        end else begin
            if (bram_axi_arvalid && bram_axi_arready) begin
                bram_rvalid_r <= 1'b1;
            end else if (bram_rvalid_r && bram_axi_rready) begin
                bram_rvalid_r <= 1'b0;
            end
        end
    end

    (* mark_debug = "true" *) wire        core_start_w;
    (* mark_debug = "true" *) wire        core_done_w;
    (* mark_debug = "true" *) wire [15:0] core_cycle_count_w;
    (* mark_debug = "true" *) wire        mlkem_busy_w;
    (* mark_debug = "true" *) wire        mlkem_done_w = core_done_w;

    (* mark_debug = "true" *) wire        dbg_result_ren;
    (* mark_debug = "true" *) wire [7:0]  dbg_result_raddr;
    (* mark_debug = "true" *) wire [11:0] dbg_result_rdata;

    (* mark_debug = "true" *) reg mlkem_done_latched;
    always @(posedge clk_100m or negedge resetn) begin
        if (!resetn) begin
            mlkem_done_latched <= 1'b0;
        end else begin
            if (mlkem_done_w)   mlkem_done_latched <= 1'b1;
            if (mlkem_busy_w)   mlkem_done_latched <= 1'b0;
        end
    end

    mlkem_coprocessor_top u_mlkem (
        .s_axi_aclk       (clk_100m),
        .s_axi_aresetn    (resetn),

        .s_axi_awaddr     (mlkem_axi_awaddr[5:0]),
        .s_axi_awprot     (mlkem_axi_awprot),
        .s_axi_awvalid    (mlkem_axi_awvalid),
        .s_axi_awready    (mlkem_axi_awready),

        .s_axi_wdata      (mlkem_axi_wdata),
        .s_axi_wstrb      (mlkem_axi_wstrb),
        .s_axi_wvalid     (mlkem_axi_wvalid),
        .s_axi_wready     (mlkem_axi_wready),

        .s_axi_bresp      (mlkem_axi_bresp),
        .s_axi_bvalid     (mlkem_axi_bvalid),
        .s_axi_bready     (mlkem_axi_bready),

        .s_axi_araddr     (mlkem_axi_araddr[5:0]),
        .s_axi_arprot     (mlkem_axi_arprot),
        .s_axi_arvalid    (mlkem_axi_arvalid),
        .s_axi_arready    (mlkem_axi_arready),

        .s_axi_rdata      (mlkem_axi_rdata),
        .s_axi_rresp      (mlkem_axi_rresp),
        .s_axi_rvalid     (mlkem_axi_rvalid),
        .s_axi_rready     (mlkem_axi_rready),

        .irq              (mlkem_irq),
        .core_busy        (mlkem_busy_w),
        .core_start       (core_start_w),
        .core_done        (core_done_w),
        .core_cycle_count (core_cycle_count_w),

        .dbg_result_ren   (dbg_result_ren),
        .dbg_result_raddr (dbg_result_raddr),
        .dbg_result_rdata (dbg_result_rdata)
    );

    reg  [3:0]  uart_div_we;
    reg  [31:0] uart_div_di;
    wire [31:0] uart_div_do;
    reg         uart_dat_we;
    reg         uart_dat_re;
    reg  [31:0] uart_dat_di;
    wire [31:0] uart_dat_do;
    wire        uart_dat_wait;

    simpleuart #(.DEFAULT_DIV(866)) u_uart (
        .clk         (clk_100m),
        .resetn      (resetn),
        .ser_tx      (uart_tx),
        .ser_rx      (uart_rx),
        .reg_div_we  (uart_div_we),
        .reg_div_di  (uart_div_di),
        .reg_div_do  (uart_div_do),
        .reg_dat_we  (uart_dat_we),
        .reg_dat_re  (uart_dat_re),
        .reg_dat_di  (uart_dat_di),
        .reg_dat_do  (uart_dat_do),
        .reg_dat_wait(uart_dat_wait)
    );

    reg  [1:0]  uart_wr_state;
    reg  [31:0] uart_wr_addr_r;
    reg  [31:0] uart_rd_data_r;
    reg         uart_rd_valid_r;
    reg         uart_wr_resp_r;

    localparam UART_ST_IDLE  = 2'd0;
    localparam UART_ST_WAIT_W = 2'd1;
    localparam UART_ST_WAIT_B = 2'd2;

    assign uart_axi_awready = (uart_wr_state == UART_ST_IDLE);
    assign uart_axi_wready  = (uart_wr_state == UART_ST_WAIT_W) && !uart_dat_wait;
    assign uart_axi_bresp   = 2'b00;
    assign uart_axi_bvalid  = uart_wr_resp_r;

    assign uart_axi_arready = !uart_rd_valid_r;
    assign uart_axi_rdata   = uart_rd_data_r;
    assign uart_axi_rresp   = 2'b00;
    assign uart_axi_rvalid  = uart_rd_valid_r;

    always @(posedge clk_100m or negedge resetn) begin
        if (!resetn) begin
            uart_wr_state  <= UART_ST_IDLE;
            uart_wr_addr_r <= 32'b0;
            uart_div_we    <= 4'b0;
            uart_div_di    <= 32'b0;
            uart_dat_we    <= 1'b0;
            uart_dat_re    <= 1'b0;
            uart_dat_di    <= 32'b0;
            uart_rd_data_r <= 32'b0;
            uart_rd_valid_r <= 1'b0;
            uart_wr_resp_r  <= 1'b0;
        end else begin
            uart_div_we  <= 4'b0;
            uart_dat_we  <= 1'b0;
            uart_dat_re  <= 1'b0;

            case (uart_wr_state)
                UART_ST_IDLE: begin
                    if (uart_axi_awvalid) begin
                        uart_wr_addr_r <= uart_axi_awaddr;
                        uart_wr_state  <= UART_ST_WAIT_W;
                    end
                end
                UART_ST_WAIT_W: begin
                    if (uart_axi_wvalid && !uart_dat_wait) begin
                        if (uart_wr_addr_r[3:0] == 4'h4) begin
                            uart_div_we  <= uart_axi_wstrb;
                            uart_div_di  <= uart_axi_wdata;
                        end
                        else if (uart_wr_addr_r[3:0] == 4'h8) begin
                            uart_dat_we  <= 1'b1;
                            uart_dat_di  <= uart_axi_wdata;
                        end
                        uart_wr_state <= UART_ST_WAIT_B;
                        uart_wr_resp_r <= 1'b1;
                    end
                end
                default: begin
                    uart_wr_state <= UART_ST_IDLE;
                end
            endcase

            if (uart_wr_resp_r && uart_axi_bready) begin
                uart_wr_resp_r <= 1'b0;
                uart_wr_state  <= UART_ST_IDLE;
            end

            if (uart_axi_arvalid && !uart_rd_valid_r) begin
                if (uart_axi_araddr[3:0] == 4'h4) begin
                    uart_rd_data_r  <= uart_div_do;
                end else if (uart_axi_araddr[3:0] == 4'h8) begin
                    uart_rd_data_r  <= uart_dat_do;
                    uart_dat_re     <= 1'b1;
                end else begin
                    uart_rd_data_r  <= 32'b0;
                end
                uart_rd_valid_r <= 1'b1;
            end
            if (uart_rd_valid_r && uart_axi_rready) begin
                uart_rd_valid_r <= 1'b0;
            end
        end
    end

    assign led[0] = resetn && pll_locked && !mlkem_busy_w && !cpu_trap;
    assign led[1] = mlkem_busy_w;
    assign led[2] = mlkem_done_latched;
    assign led[3] = cpu_trap;

endmodule
