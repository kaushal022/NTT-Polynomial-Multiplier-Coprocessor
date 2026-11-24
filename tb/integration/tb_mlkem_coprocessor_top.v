`timescale 1ns / 1ps

module tb_mlkem_coprocessor_top;

    parameter CLK_PERIOD = 10;

    reg         clk;
    reg         rst_n;

    reg  [5:0]  s_axi_awaddr;
    reg  [2:0]  s_axi_awprot;
    reg         s_axi_awvalid;
    wire        s_axi_awready;

    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;

    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    reg  [5:0]  s_axi_araddr;
    reg  [2:0]  s_axi_arprot;
    reg         s_axi_arvalid;
    wire        s_axi_arready;

    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    wire        irq;

    mlkem_coprocessor_top dut (
        .s_axi_aclk    (clk),
        .s_axi_aresetn (rst_n),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .irq           (irq)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg [11:0] tv4_f   [0:255];
    reg [11:0] tv5_g   [0:255];
    reg [11:0] exp_h   [0:255];
    reg [11:0] read_h  [0:255];

    integer i, mismatches;
    reg [31:0] rdata_tmp;

    task axi_write;
        input [5:0]  addr;
        input [31:0] data;
        begin
            @(posedge clk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            while (!(s_axi_awready && s_axi_wready)) @(posedge clk);
            @(posedge clk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;

            while (!s_axi_bvalid) @(posedge clk);
            @(posedge clk);
            s_axi_bready <= 1'b0;
        end
    endtask

    task axi_read;
        input  [5:0]  addr;
        output [31:0] data;
        begin
            @(posedge clk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            while (!s_axi_arready) @(posedge clk);
            @(posedge clk);
            s_axi_arvalid <= 1'b0;

            while (!s_axi_rvalid) @(posedge clk);
            data = s_axi_rdata;
            @(posedge clk);
            s_axi_rready <= 1'b0;
        end
    endtask

    initial begin
        $display("===============================================================");
        $display("Running AXI4-Lite ML-KEM Coprocessor Top Integration Testbench");
        $display("===============================================================");

        $readmemh("tv4_input.hex", tv4_f);
        $readmemh("tv5_input.hex", tv5_g);
        $readmemh("tv_polymul_result.mem", exp_h);

        rst_n = 0;
        s_axi_awaddr = 0; s_axi_awprot = 0; s_axi_awvalid = 0;
        s_axi_wdata = 0;  s_axi_wstrb = 0;  s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0; s_axi_arprot = 0; s_axi_arvalid = 0;
        s_axi_rready = 0;
        mismatches = 0;

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        axi_read(6'h1C, rdata_tmp);
        $display("[AXI-TB] Read VERSION register (0x1C): 0x%08X (ASCII: %c%c%c%c)",
                 rdata_tmp, rdata_tmp[31:24], rdata_tmp[23:16], rdata_tmp[15:8], rdata_tmp[7:0]);
        if (rdata_tmp !== 32'h4D4C4B31) begin
            $display("[AXI-TB] ERROR: Version mismatch! Expected 0x4D4C4B31 ('MLK1')");
            mismatches = mismatches + 1;
        end

        $display("[AXI-TB] Enabling interrupts (CONTROL = 0x02)...");
        axi_write(6'h00, 32'h00000002);

        $display("[AXI-TB] Loading polynomial f (256 words via AXI auto-increment)...");
        axi_write(6'h0C, 32'd0);
        for (i = 0; i < 256; i = i + 1) begin
            axi_write(6'h10, {20'd0, tv4_f[i]});
        end

        $display("[AXI-TB] Loading polynomial g (256 words via AXI auto-increment)...");
        axi_write(6'h0C, 32'd0);
        for (i = 0; i < 256; i = i + 1) begin
            axi_write(6'h14, {20'd0, tv5_g[i]});
        end

        $display("[AXI-TB] Starting coprocessor computation (CONTROL = 0x03)...");
        axi_write(6'h00, 32'h00000003);

        $display("[AXI-TB] Waiting for IRQ assertion from coprocessor...");
        fork : irq_wait
            begin
                wait (irq == 1'b1);
                $display("[AXI-TB] SUCCESS: Interrupt IRQ asserted by coprocessor!");
                disable irq_wait;
            end
            begin
                repeat (60000) @(posedge clk);
                $display("[AXI-TB] ERROR: Timeout waiting for IRQ!");
                mismatches = mismatches + 1;
                disable irq_wait;
            end
        join

        axi_read(6'h08, rdata_tmp);
        $display("[AXI-TB] Read CYCLE_COUNT register (0x08): %0d clock cycles", rdata_tmp[15:0]);

        axi_read(6'h04, rdata_tmp);
        $display("[AXI-TB] Read STATUS register (0x04): 0x%08X (busy=%0d, done=%0d)",
                 rdata_tmp, rdata_tmp[0], rdata_tmp[1]);

        $display("[AXI-TB] Reading back result polynomial h via AXI-Lite...");
        for (i = 0; i < 256; i = i + 1) begin
            axi_write(6'h0C, i[7:0]);
            axi_read(6'h18, rdata_tmp);
            read_h[i] = rdata_tmp[11:0];
        end

        $display("[AXI-TB] Verifying all 256 coefficients against golden NIST model...");
        for (i = 0; i < 256; i = i + 1) begin
            if (read_h[i] !== exp_h[i]) begin
                if (mismatches < 10) begin
                    $display("[AXI-TB] MISMATCH at [%0d]: got %0d, expected %0d", i, read_h[i], exp_h[i]);
                end
                mismatches = mismatches + 1;
            end
        end

        $display("---------------------------------------------------------------");
        if (mismatches == 0) begin
            $display("ALL AXI4-LITE SOC INTEGRATION TESTS PASSED!");
            $display("Product coefficients [0..7]: %0d %0d %0d %0d %0d %0d %0d %0d",
                     read_h[0], read_h[1], read_h[2], read_h[3],
                     read_h[4], read_h[5], read_h[6], read_h[7]);
        end else begin
            $display("FAILED: Total mismatches: %0d", mismatches);
        end
        $display("===============================================================");

        $finish;
    end

endmodule
