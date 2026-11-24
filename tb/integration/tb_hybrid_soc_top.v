`timescale 1ns / 1ps

module tb_hybrid_soc_top;

    reg clk_100m = 1'b0;
    always #5 clk_100m = ~clk_100m;

    reg        resetn = 1'b0;
    reg        uart_rx = 1'b1;
    wire       uart_tx;
    wire [3:0] led;

    reg  [11:0] ps_awaddr  = 12'd0;
    reg  [2:0]  ps_awprot  = 3'd0;
    reg         ps_awvalid = 1'b0;
    wire        ps_awready;

    reg  [31:0] ps_wdata   = 32'd0;
    reg  [3:0]  ps_wstrb   = 4'hF;
    reg         ps_wvalid  = 1'b0;
    wire        ps_wready;

    wire [1:0]  ps_bresp;
    wire        ps_bvalid;
    reg         ps_bready  = 1'b0;

    reg  [11:0] ps_araddr  = 12'd0;
    reg  [2:0]  ps_arprot  = 3'd0;
    reg         ps_arvalid = 1'b0;
    wire        ps_arready;

    wire [31:0] ps_rdata;
    wire [1:0]  ps_rresp;
    wire        ps_rvalid;
    reg         ps_rready  = 1'b0;

    pl_hybrid_soc dut (
        .clk_100m        (clk_100m),
        .resetn          (resetn),

        .s_ps_axi_awaddr (ps_awaddr),
        .s_ps_axi_awprot (ps_awprot),
        .s_ps_axi_awvalid(ps_awvalid),
        .s_ps_axi_awready(ps_awready),
        .s_ps_axi_wdata  (ps_wdata),
        .s_ps_axi_wstrb  (ps_wstrb),
        .s_ps_axi_wvalid (ps_wvalid),
        .s_ps_axi_wready (ps_wready),
        .s_ps_axi_bresp  (ps_bresp),
        .s_ps_axi_bvalid (ps_bvalid),
        .s_ps_axi_bready (ps_bready),
        .s_ps_axi_araddr (ps_araddr),
        .s_ps_axi_arprot (ps_arprot),
        .s_ps_axi_arvalid(ps_arvalid),
        .s_ps_axi_arready(ps_arready),
        .s_ps_axi_rdata  (ps_rdata),
        .s_ps_axi_rresp  (ps_rresp),
        .s_ps_axi_rvalid (ps_rvalid),
        .s_ps_axi_rready (ps_rready),

        .uart_tx         (uart_tx),
        .uart_rx         (uart_rx),
        .led             (led)
    );

    reg [11:0] tv4_f  [0:255];
    reg [11:0] tv5_g  [0:255];
    reg [11:0] exp_h  [0:255];
    reg [11:0] got_h  [0:255];

    task ps_axi_write;
        input [11:0] addr;
        input [31:0] data;
        reg aw_ack, w_ack;
        begin
            @(posedge clk_100m);
            ps_awaddr  <= addr;
            ps_awvalid <= 1'b1;
            ps_wdata   <= data;
            ps_wstrb   <= 4'hF;
            ps_wvalid  <= 1'b1;
            ps_bready  <= 1'b1;
            aw_ack = 1'b0;
            w_ack  = 1'b0;
            while (!aw_ack || !w_ack) begin
                @(posedge clk_100m);
                if (ps_awvalid && ps_awready) begin
                    ps_awvalid <= 1'b0;
                    aw_ack = 1'b1;
                end
                if (ps_wvalid && ps_wready) begin
                    ps_wvalid <= 1'b0;
                    w_ack = 1'b1;
                end
            end
            while (!ps_bvalid) @(posedge clk_100m);
            @(posedge clk_100m);
            ps_bready <= 1'b0;
        end
    endtask

    task ps_axi_read;
        input  [11:0] addr;
        output [31:0] data;
        begin
            @(posedge clk_100m);
            ps_araddr  <= addr;
            ps_arvalid <= 1'b1;
            ps_rready  <= 1'b1;
            @(posedge clk_100m);
            while (!(ps_arvalid && ps_arready)) @(posedge clk_100m);
            ps_arvalid <= 1'b0;
            while (!ps_rvalid) @(posedge clk_100m);
            data = ps_rdata;
            @(posedge clk_100m);
            ps_rready <= 1'b0;
        end
    endtask

    integer i, mismatches, dma_events, irq_events;
    reg [31:0] tmp, cycles, flags, hb;

    reg prev_dma_done, prev_irq;
    always @(posedge clk_100m) begin
        if (!resetn) begin
            dma_events    <= 0;
            irq_events    <= 0;
            prev_dma_done <= 1'b0;
            prev_irq      <= 1'b0;
        end else begin
            if (dut.dma_done_w && !prev_dma_done) begin
                dma_events <= dma_events + 1;
                $display("[%0t] DMA TRANSFER COMPLETE (count=%0d)", $time, dma_events + 1);
            end
            if (dut.mlkem_irq && !prev_irq) begin
                irq_events <= irq_events + 1;
                $display("[%0t] HARDWARE IRQ ASSERTED by interrupt_ctrl -> PicoRV32 irq[0]", $time);
            end
            if (dut.core_start_w)
                $display("[%0t] COPROCESSOR START triggered by PicoRV32", $time);
            if (dut.core_done_w)
                $display("[%0t] COPROCESSOR DONE pulsed (cycles=%0d)", $time, dut.core_cycle_count_w);
            if (dut.cpu_trap) begin
                $display("[%0t] FATAL: PicoRV32 cpu_trap asserted!", $time);
                $finish;
            end
            prev_dma_done <= dut.dma_done_w;
            prev_irq      <= dut.mlkem_irq;
        end
    end

    initial begin
        $readmemh("tv4_input.hex", tv4_f);
        $readmemh("tv5_input.hex", tv5_g);
        $readmemh("tv_polymul_result.hex", exp_h);

        $display("=================================================================");
        $display("  ML-KEM HYBRID SOC (Zynq PS GP0 -> Mailbox -> RV32 -> DMA -> IRQ)");
        $display("=================================================================");

        resetn = 1'b0;
        repeat (20) @(posedge clk_100m);
        resetn = 1'b1;

        ps_axi_read(12'h000, tmp);
        $display("[%0t] Mailbox MAGIC = 0x%08X (expected 0x4D4C4B4D)", $time, tmp);
        if (tmp !== 32'h4D4C_4B4D) begin
            $display("FAIL: Mailbox MAGIC mismatch!");
            $finish;
        end

        tmp = 0;
        while ((tmp & 32'h2) == 0) begin
            repeat (50) @(posedge clk_100m);
            ps_axi_read(12'h008, tmp);
        end
        ps_axi_read(12'h010, hb);
        $display("[%0t] PicoRV32 ONLINE! Status=0x%08X Heartbeat=0x%08X", $time, tmp, hb);

        $display("[%0t] Test 1: Writing 256 F & 256 G coefficients into AXI Mailbox...", $time);
        ps_axi_write(12'h008, 32'h0);
        for (i = 0; i < 256; i = i + 1) begin
            ps_axi_write(12'h100 + (i[9:0] << 2), {20'd0, tv4_f[i]});
            ps_axi_write(12'h500 + (i[9:0] << 2), {20'd0, tv5_g[i]});
        end
        ps_axi_write(12'h004, (32'h0001 << 16) | 32'h3);

        flags = 0;
        while ((flags & 32'h1) == 0) begin
            repeat (100) @(posedge clk_100m);
            ps_axi_read(12'h008, flags);
        end
        ps_axi_read(12'h00C, cycles);
        $display("[%0t] Test 1 DONE! Flags=0x%08X (exp 0x3F) Cycles=%0d DMA_ev=%0d IRQ_ev=%0d",
                 $time, flags, cycles, dma_events, irq_events);

        mismatches = 0;
        for (i = 0; i < 256; i = i + 1) begin
            ps_axi_read(12'h900 + (i[9:0] << 2), tmp);
            got_h[i] = tmp[11:0];
            if (got_h[i] !== exp_h[i]) begin
                if (mismatches < 10)
                    $display("  MISMATCH[%0d]: got=0x%03X exp=0x%03X", i, got_h[i], exp_h[i]);
                mismatches = mismatches + 1;
            end
        end

        if (mismatches == 0 && flags == 32'h3F && dma_events == 3 && irq_events == 1)
            $display("  Test 1 PASS: All 256 NIST coefficients bit-exact!");
        else begin
            $display("  Test 1 FAIL: mismatches=%0d flags=0x%08X dma=%0d irq=%0d",
                     mismatches, flags, dma_events, irq_events);
            $finish;
        end

        $display("[%0t] Test 2: Consecutive request via same live pipeline...", $time);
        ps_axi_write(12'h008, 32'h0);
        for (i = 0; i < 256; i = i + 1) begin
            ps_axi_write(12'h100 + (i[9:0] << 2), i);
            ps_axi_write(12'h500 + (i[9:0] << 2), (i == 0) ? 32'd1 : 32'd0);
        end
        ps_axi_write(12'h004, (32'h0002 << 16) | 32'h3);

        flags = 0;
        while ((flags & 32'h1) == 0) begin
            repeat (100) @(posedge clk_100m);
            ps_axi_read(12'h008, flags);
        end
        ps_axi_read(12'h00C, cycles);

        for (i = 0; i < 256; i = i + 1) begin
            ps_axi_read(12'h900 + (i[9:0] << 2), tmp);
            if (tmp[11:0] !== i[11:0]) begin
                if (mismatches < 10)
                    $display("  Test 2 MISMATCH[%0d]: got=%0d exp=%0d", i, tmp[11:0], i);
                mismatches = mismatches + 1;
            end
        end

        if (mismatches == 0 && flags == 32'h3F && dma_events == 6 && irq_events == 2) begin
            $display("  Test 2 PASS: All 256 identity coefficients exact (Cycles=%0d)!", cycles);
            $display("=================================================================");
            $display("  ALL HYBRID SOC XSIM TESTS PASSED (DMA x6, IRQ x2, 512/512 OK)");
            $display("=================================================================");
        end else begin
            $display("  Test 2 FAIL: mismatches=%0d flags=0x%08X dma=%0d irq=%0d",
                     mismatches, flags, dma_events, irq_events);
        end
        $finish;
    end

    initial begin
        #15000000;
        $display("TIMEOUT: Simulation exceeded 15 ms!");
        $finish;
    end

endmodule
