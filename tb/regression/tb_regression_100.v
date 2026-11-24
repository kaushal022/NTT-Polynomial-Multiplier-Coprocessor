`timescale 1ns / 1ps

module tb_regression_100;

    parameter CLK_PERIOD = 10;
    parameter NUM_VECTORS = 100;
    parameter N = 256;
    parameter TOTAL_WORDS = NUM_VECTORS * N;

    reg         clk;
    reg         rst_n;
    reg         start;
    wire        done;
    wire        busy;
    wire [15:0] cycle_count;

    reg         ext_wen_f;
    reg         ext_wen_g;
    reg  [7:0]  ext_addr;
    reg  [11:0] ext_wdata_f;
    reg  [11:0] ext_wdata_g;

    reg         ext_ren;
    reg  [7:0]  ext_raddr;
    wire [11:0] ext_rdata;

    poly_multiplier dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .done       (done),
        .busy       (busy),
        .cycle_count(cycle_count),
        .ext_wen_f (ext_wen_f),
        .ext_wen_g (ext_wen_g),
        .ext_addr   (ext_addr),
        .ext_wdata_f(ext_wdata_f),
        .ext_wdata_g(ext_wdata_g),
        .ext_ren    (ext_ren),
        .ext_raddr  (ext_raddr),
        .ext_rdata  (ext_rdata)
    );

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    reg [11:0] mem_f   [0:TOTAL_WORDS - 1];
    reg [11:0] mem_g   [0:TOTAL_WORDS - 1];
    reg [11:0] mem_exp [0:TOTAL_WORDS - 1];

    reg [11:0] read_h  [0:N - 1];

    integer vec_idx, i;
    integer base_offset;
    integer vec_errors;
    integer total_errors;
    integer wait_cycles;
    integer max_cycles, min_cycles, sum_cycles;
    integer vec_fd;

    initial begin
        $display("=================================================================");
        $display("  ML-KEM Polynomial Multiplier: 100 Random Vectors Regression");
        $display("  Deliverable: Bit-exact verification for >= 100 random inputs");
        $display("=================================================================");

        $display("[TB] Loading 100 random vector pairs from hex files...");
        vec_fd = $fopen("inputs_f.hex", "r");
        if (vec_fd != 0) begin
            $fclose(vec_fd);
            $readmemh("inputs_f.hex", mem_f);
            $readmemh("inputs_g.hex", mem_g);
            $readmemh("expected_h.hex", mem_exp);
        end else begin
            $readmemh("tb/vectors/random_100/inputs_f.hex", mem_f);
            $readmemh("tb/vectors/random_100/inputs_g.hex", mem_g);
            $readmemh("tb/vectors/random_100/expected_h.hex", mem_exp);
        end
        $display("[TB] 25,600 words loaded successfully.");

        rst_n       = 0;
        start       = 0;
        ext_wen_f   = 0;
        ext_wen_g   = 0;
        ext_addr    = 0;
        ext_wdata_f = 0;
        ext_wdata_g = 0;
        ext_ren     = 0;
        ext_raddr   = 0;

        total_errors = 0;
        max_cycles   = 0;
        min_cycles   = 999999;
        sum_cycles   = 0;

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        for (vec_idx = 0; vec_idx < NUM_VECTORS; vec_idx = vec_idx + 1) begin
            base_offset = vec_idx * N;
            vec_errors  = 0;

            for (i = 0; i < N; i = i + 1) begin
                @(posedge clk);
                ext_wen_f   <= 1'b1;
                ext_wen_g   <= 1'b1;
                ext_addr    <= i[7:0];
                ext_wdata_f <= mem_f[base_offset + i];
                ext_wdata_g <= mem_g[base_offset + i];
            end
            @(posedge clk);
            ext_wen_f <= 1'b0;
            ext_wen_g <= 1'b0;
            repeat (2) @(posedge clk);

            @(posedge clk);
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;

            wait_cycles = 0;
            while (!done && (wait_cycles < 8000)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end

            if (!done) begin
                $display("[TB] ERROR: Vector %0d TIMEOUT waiting for done!", vec_idx);
                total_errors = total_errors + 1;
            end else begin
                if (cycle_count > max_cycles) max_cycles = cycle_count;
                if (cycle_count < min_cycles) min_cycles = cycle_count;
                sum_cycles = sum_cycles + cycle_count;
            end

            for (i = 0; i < N; i = i + 1) begin
                @(posedge clk);
                ext_ren   <= 1'b1;
                ext_raddr <= i[7:0];
                @(posedge clk);
                @(posedge clk);
                #1;
                read_h[i] = ext_rdata;
            end
            @(posedge clk);
            ext_ren <= 1'b0;

            for (i = 0; i < N; i = i + 1) begin
                if (read_h[i] !== mem_exp[base_offset + i]) begin
                    if (vec_errors < 5) begin
                        $display("[TB] MISMATCH Vec %0d [%0d]: got %0d, exp %0d",
                                 vec_idx, i, read_h[i], mem_exp[base_offset + i]);
                    end
                    vec_errors = vec_errors + 1;
                end
            end

            if (vec_errors > 0) begin
                $display("[TB] Vector %0d: FAILED (%0d mismatches)", vec_idx, vec_errors);
                total_errors = total_errors + vec_errors;
            end else if ((vec_idx % 10 == 0) || (vec_idx == NUM_VECTORS - 1)) begin
                $display("[TB] Vector %3d / %0d: PASS (bit-exact, %0d cycles)",
                         vec_idx + 1, NUM_VECTORS, cycle_count);
            end
        end

        $display("");
        $display("=================================================================");
        $display("  REGRESSION TEST RESULTS SUMMARY (100 RANDOM VECTORS)");
        $display("=================================================================");
        if (total_errors == 0) begin
            $display("  STATUS: ALL 100 VECTORS PASSED (100%% BIT-EXACT)");
            $display("  Total output coefficients verified: %0d", TOTAL_WORDS);
            $display("  Cycle statistics:");
            $display("    - Min cycles: %0d", min_cycles);
            $display("    - Max cycles: %0d", max_cycles);
            $display("    - Avg cycles: %0d", sum_cycles / NUM_VECTORS);
            $display("  DELIVERABLE FULFILLED: Bit-exact on >= 100 random inputs!");
        end else begin
            $display("  STATUS: FAILED with %0d coefficient mismatches", total_errors);
        end
        $display("=================================================================");

        repeat (10) @(posedge clk);
        $finish;
    end

    initial begin
        #10000000;
        $display("\n[TB] ERROR: Global regression timeout!");
        $finish;
    end

endmodule
