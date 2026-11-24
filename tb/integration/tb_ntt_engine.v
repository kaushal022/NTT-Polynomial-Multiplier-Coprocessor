`timescale 1ns / 1ps

module tb_ntt_engine;

    parameter CLK_PERIOD = 10;
    parameter Q = 3329;
    parameter MAX_NTT_CYCLES = 1000;

    reg         clk, rst_n;
    reg         start, mode;
    wire        done, busy;
    wire [15:0] cycle_count;
    wire        result_in_scratch;

    wire        bram_ena, bram_wea;
    wire [7:0]  bram_addra;
    wire [11:0] bram_dina;
    wire [11:0] bram_douta;
    wire        bram_enb, bram_web;
    wire [7:0]  bram_addrb;
    wire [11:0] bram_dinb;
    wire [11:0] bram_doutb;

    reg         tb_bram_ena, tb_bram_wea;
    reg  [7:0]  tb_bram_addra;
    reg  [11:0] tb_bram_dina;
    reg         tb_bram_enb, tb_bram_web;
    reg  [7:0]  tb_bram_addrb;
    reg  [11:0] tb_bram_dinb;

    reg         engine_has_control;

    wire        mux_ena   = engine_has_control ? bram_ena   : tb_bram_ena;
    wire        mux_wea   = engine_has_control ? bram_wea   : tb_bram_wea;
    wire [7:0]  mux_addra = engine_has_control ? bram_addra : tb_bram_addra;
    wire [11:0] mux_dina  = engine_has_control ? bram_dina  : tb_bram_dina;
    wire        mux_enb   = engine_has_control ? bram_enb   : tb_bram_enb;
    wire        mux_web   = engine_has_control ? bram_web   : tb_bram_web;
    wire [7:0]  mux_addrb = engine_has_control ? bram_addrb : tb_bram_addrb;
    wire [11:0] mux_dinb  = engine_has_control ? bram_dinb  : tb_bram_dinb;

    poly_bram u_bram (
        .clk(clk),
        .ena(mux_ena), .wea(mux_wea), .addra(mux_addra), .dina(mux_dina), .douta(bram_douta),
        .enb(mux_enb), .web(mux_web), .addrb(mux_addrb), .dinb(mux_dinb), .doutb(bram_doutb)
    );

    reg         scr_ena_tb;
    reg  [7:0]  scr_addr_tb;
    wire [11:0] scr_data_tb;

    ntt_engine u_engine (
        .clk(clk), .rst_n(rst_n),
        .start(start), .mode(mode),
        .done(done), .busy(busy), .cycle_count(cycle_count),
        .bram_ena(bram_ena), .bram_wea(bram_wea), .bram_addra(bram_addra),
        .bram_dina(bram_dina), .bram_douta(bram_douta),
        .bram_enb(bram_enb), .bram_web(bram_web), .bram_addrb(bram_addrb),
        .bram_dinb(bram_dinb), .bram_doutb(bram_doutb),
        .scr_ena(scr_ena_tb), .scr_addr(scr_addr_tb), .scr_data(scr_data_tb),
        .result_in_scratch(result_in_scratch)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg [11:0] input_poly   [0:255];
    reg [11:0] readback     [0:255];

    integer i, errors, total_errors;

    task write_poly_to_bram;
        begin
            for (i = 0; i < 256; i = i + 1) begin
                @(posedge clk);
                tb_bram_ena   <= 1'b1;
                tb_bram_wea   <= 1'b1;
                tb_bram_addra <= i[7:0];
                tb_bram_dina  <= input_poly[i];
            end
            @(posedge clk);
            tb_bram_ena <= 1'b0;
            tb_bram_wea <= 1'b0;
        end
    endtask

    task read_ext_bram;
        begin
            for (i = 0; i < 256; i = i + 1) begin
                @(posedge clk);
                tb_bram_ena   <= 1'b1;
                tb_bram_wea   <= 1'b0;
                tb_bram_addra <= i[7:0];
                @(posedge clk);
                #1;
                readback[i] = bram_douta;
            end
            @(posedge clk);
            tb_bram_ena <= 1'b0;
        end
    endtask

    task read_scratch_bram;
        begin
            for (i = 0; i < 256; i = i + 1) begin
                @(posedge clk);
                scr_ena_tb  <= 1'b1;
                scr_addr_tb <= i[7:0];
                @(posedge clk);
                #1;
                readback[i] = scr_data_tb;
            end
            @(posedge clk);
            scr_ena_tb <= 1'b0;
        end
    endtask

    task run_ntt;
        input run_mode;
        integer wait_cycles;
        begin
            engine_has_control <= 1'b1;
            @(posedge clk);
            mode  <= run_mode;
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;

            wait_cycles = 0;
            while (!done && (wait_cycles < (MAX_NTT_CYCLES + 20))) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end

            if (!done) begin
                $display("ERROR: NTT timed out! Did not assert done within %0d cycles (mode=%0d).",
                         MAX_NTT_CYCLES, run_mode);
                total_errors = total_errors + 1;
            end else if (cycle_count > MAX_NTT_CYCLES) begin
                $display("FAIL: NTT took %0d cycles (target <= %0d EXCEEDED, mode=%0d)!",
                         cycle_count, MAX_NTT_CYCLES, run_mode);
                total_errors = total_errors + 1;
            end else begin
                $display("PASS: NTT completed in %0d cycles (target <= %0d MET, mode=%0d)",
                         cycle_count, MAX_NTT_CYCLES, run_mode);
            end

            @(posedge clk);
            engine_has_control <= 1'b0;
        end
    endtask

    initial begin
        $display("=== NTT Engine Integration Testbench (Pipelined v4) ===");
        $display("Target: forward NTT <= 1,000 cycles");

        total_errors = 0;

        rst_n = 0; start = 0; mode = 0;
        engine_has_control = 0;
        tb_bram_ena = 0; tb_bram_wea = 0; tb_bram_addra = 0; tb_bram_dina = 0;
        tb_bram_enb = 0; tb_bram_web = 0; tb_bram_addrb = 0; tb_bram_dinb = 0;
        scr_ena_tb = 0; scr_addr_tb = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5)  @(posedge clk);

        $display("\n--- Test 1: All-zero polynomial ---");
        for (i = 0; i < 256; i = i + 1) input_poly[i] = 0;

        write_poly_to_bram();
        repeat(3) @(posedge clk);

        run_ntt(1'b0);
        $display("Forward NTT complete. Cycles: %0d  (target: <= 1000)", cycle_count);
        if (cycle_count > 16'd1000)
            $display("WARNING: cycle count %0d exceeds 1000 target!", cycle_count);

        repeat(3) @(posedge clk);

        if (result_in_scratch)
            read_scratch_bram();
        else
            read_ext_bram();

        errors = 0;
        for (i = 0; i < 256; i = i + 1)
            if (readback[i] !== 12'd0) errors = errors + 1;

        if (errors == 0)
            $display("PASS: NTT(0) = 0 (%0d/256 coefficients correct)", 256);
        else
            $display("FAIL: %0d non-zero coefficients in NTT(0)", errors);
        total_errors = total_errors + errors;

        $display("\n--- Test 2: Round-trip NTT -> INTT (f[i] = i) ---");
        for (i = 0; i < 256; i = i + 1) input_poly[i] = i;

        write_poly_to_bram();
        repeat(3) @(posedge clk);

        run_ntt(1'b0);
        $display("Forward NTT done. Cycles: %0d  result_in_scratch=%b",
                 cycle_count, result_in_scratch);

        $display("Copying NTT(f) from scratch to external BRAM for INTT...");
        begin : copy_scr_to_ext
            reg [11:0] temp_val;
            for (i = 0; i < 256; i = i + 1) begin
                @(posedge clk);
                scr_ena_tb  <= 1'b1;
                scr_addr_tb <= i[7:0];
                @(posedge clk);
                #1;
                temp_val     = scr_data_tb;
                scr_ena_tb  <= 1'b0;
                @(posedge clk);
                tb_bram_ena   <= 1'b1;
                tb_bram_wea   <= 1'b1;
                tb_bram_addra <= i[7:0];
                tb_bram_dina  <= temp_val;
                @(posedge clk);
                tb_bram_ena   <= 1'b0;
                tb_bram_wea   <= 1'b0;
            end
        end
        repeat(3) @(posedge clk);

        run_ntt(1'b1);
        $display("Inverse NTT done. Cycles: %0d  result_in_scratch=%b",
                 cycle_count, result_in_scratch);

        repeat(3) @(posedge clk);

        if (!result_in_scratch)
            read_ext_bram();
        else
            read_scratch_bram();

        errors = 0;
        for (i = 0; i < 256; i = i + 1) begin
            if (readback[i] !== input_poly[i]) begin
                if (errors < 20)
                    $display("  MISMATCH [%0d]: got %0d, expected %0d",
                             i, readback[i], input_poly[i]);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: Round-trip NTT->INTT: all 256 coefficients match");
        else
            $display("FAIL: %0d/256 mismatches in round-trip", errors);
        total_errors = total_errors + errors;

        $display("\n--- Test 3: Constant polynomial (all 1s) round-trip ---");
        for (i = 0; i < 256; i = i + 1) input_poly[i] = 1;

        write_poly_to_bram();
        repeat(3) @(posedge clk);

        run_ntt(1'b0);
        $display("Forward NTT done. Cycles: %0d", cycle_count);

        begin : copy2
            reg [11:0] tv;
            for (i = 0; i < 256; i = i + 1) begin
                @(posedge clk); scr_ena_tb <= 1'b1; scr_addr_tb <= i[7:0];
                @(posedge clk); #1 tv = scr_data_tb; scr_ena_tb <= 1'b0;
                @(posedge clk); tb_bram_ena <= 1'b1; tb_bram_wea <= 1'b1;
                                tb_bram_addra <= i[7:0]; tb_bram_dina <= tv;
                @(posedge clk); tb_bram_ena <= 1'b0; tb_bram_wea <= 1'b0;
            end
        end
        repeat(3) @(posedge clk);

        run_ntt(1'b1);
        $display("Inverse NTT done. Cycles: %0d", cycle_count);
        repeat(3) @(posedge clk);

        if (!result_in_scratch) read_ext_bram(); else read_scratch_bram();

        errors = 0;
        for (i = 0; i < 256; i = i + 1)
            if (readback[i] !== 12'd1) errors = errors + 1;

        if (errors == 0)
            $display("PASS: Round-trip of all-ones matches");
        else
            $display("FAIL: %0d mismatches in all-ones round-trip", errors);
        total_errors = total_errors + errors;

        $display("\n=== NTT Engine Test Summary ===");
        if (total_errors == 0)
            $display("STATUS: ALL TESTS PASSED");
        else
            $display("STATUS: FAILED with %0d total errors", total_errors);

        repeat (10) @(posedge clk);
        $finish;
    end

    initial begin
        #120000;
        $display("\n=======================================================");
        $display("ERROR: Simulation timeout (120 us exceeded)!");
        $display("=======================================================");
        $finish;
    end

endmodule
