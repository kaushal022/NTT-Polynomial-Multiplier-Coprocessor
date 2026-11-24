`timescale 1ns / 1ps

module tb_poly_multiplier;

    parameter CLK_PERIOD = 10;
    parameter Q = 3329;
    parameter N = 256;
    parameter TIMEOUT_CYCLES = 50000;

    reg clk;
    reg rst_n;
    reg start;

    wire done;
    wire busy;
    wire [15:0] cycle_count;

    reg ext_wen;
    reg [7:0] ext_addr;

    reg [11:0] ext_wdata_f;
    reg [11:0] ext_wdata_g;

    reg ext_ren;
    reg [7:0] ext_raddr;

    wire [11:0] ext_rdata;

    poly_multiplier dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .busy(busy),
        .cycle_count(cycle_count),

        .ext_wen_f(ext_wen),
        .ext_wen_g(ext_wen),

        .ext_addr(ext_addr),
        .ext_wdata_f(ext_wdata_f),
        .ext_wdata_g(ext_wdata_g),

        .ext_ren(ext_ren),
        .ext_raddr(ext_raddr),
        .ext_rdata(ext_rdata)
    );

    initial begin
        clk = 1'b0;
    end

    always #(CLK_PERIOD/2) clk = ~clk;

    reg [11:0] tv4_f [0:255];
    reg [11:0] tv5_g [0:255];

    reg [11:0] exp_h [0:255];
    reg [11:0] result [0:255];

    integer i;
    integer errors;
    integer timeout_count;

    integer diff_count;
    integer k_dbg;
    integer result_file;

    reg finished;
    reg timed_out;

    reg [3:0] previous_state;

    always @(posedge clk) begin

        if (rst_n) begin

            case (dut.pm_state)

                4'd2: begin
                    if (dut.pm_state != previous_state)
                        $display("[FSM] Entered PM_NTT_F");
                end

                4'd3: begin
                    if (dut.pm_state != previous_state)
                        $display("[FSM] Entered PM_SAVE_FHAT");
                end

                4'd4: begin
                    if (dut.pm_state != previous_state)
                        $display("[FSM] Entered PM_COPY_G");
                end

                4'd5: begin
                    if (dut.pm_state != previous_state)
                        $display("[FSM] Entered PM_NTT_G");
                end

                4'd6: begin
                    if (dut.pm_state != previous_state)
                        $display("[FSM] Entered PM_BASEMUL");
                end

                4'd7: begin
                    if (dut.pm_state != previous_state)
                        $display("[FSM] Entered PM_INTT");
                end

                4'd8: begin
                    if (dut.pm_state != previous_state)
                        $display("[FSM] Entered PM_DONE");
                end

                default: begin
                end

            endcase

            previous_state = dut.pm_state;

        end

    end

    initial begin

        $display("");
        $display("=================================================");
        $display(" ML-KEM POLYNOMIAL MULTIPLIER TESTBENCH");
        $display("=================================================");

        rst_n = 0;
        start = 0;

        ext_wen = 0;
        ext_addr = 0;

        ext_wdata_f = 0;
        ext_wdata_g = 0;

        ext_ren = 0;
        ext_raddr = 0;

        errors = 0;
        timeout_count = 0;

        finished = 0;
        timed_out = 0;

        previous_state = 4'hF;

        $display("[TB] Loading test vectors...");

        $readmemh("tv4_input.mem", tv4_f);
        $readmemh("tv5_input.mem", tv5_g);
        $readmemh("tv_polymul_result.mem", exp_h);

        result_file = $fopen("poly_multiplier_RTL_output.mem", "w");

        $display("[TB] Test vectors loaded.");

        $display("[TB] Applying reset...");

        repeat (5) @(negedge clk);

        rst_n = 1'b1;

        repeat (2) @(negedge clk);

        $display("[TB] Reset released.");

        $display("");
        $display("[TB] Loading polynomial f and g into BRAM...");

        for (i = 0; i < N; i = i + 1) begin

            @(negedge clk);

            ext_wen = 1'b1;

            ext_addr = i;

            ext_wdata_f = tv4_f[i];
            ext_wdata_g = tv5_g[i];

        end

        @(negedge clk);

        ext_wen = 1'b0;

        repeat (2) @(negedge clk);

        $display("[TB] Polynomial loading completed.");

        $display("[TB] f[0:3] = %0d, %0d, %0d, %0d",
                 tv4_f[0], tv4_f[1],
                 tv4_f[2], tv4_f[3]);

        $display("[TB] g[0:3] = %0d, %0d, %0d, %0d",
                 tv5_g[0], tv5_g[1],
                 tv5_g[2], tv5_g[3]);

        $display("");
        $display("[TB] Starting polynomial multiplication...");

        @(negedge clk);

        start = 1'b1;

        @(negedge clk);

        start = 1'b0;

        $display("[TB] Monitoring coprocessor execution...");

        wait (dut.pm_state == 4'd2);

        $display("");
        $display("[DBG] PM_NTT_F started");

        $display("[DBG] work[0:3] = %0d, %0d, %0d, %0d",
                 dut.u_bram_work.mem[0],
                 dut.u_bram_work.mem[1],
                 dut.u_bram_work.mem[2],
                 dut.u_bram_work.mem[3]);

        diff_count = 0;

        for (k_dbg = 0; k_dbg < N; k_dbg = k_dbg + 1) begin

            if (dut.u_bram_work.mem[k_dbg] !== tv4_f[k_dbg]) begin

                if (diff_count < 5) begin

                    $display("[DBG] COPY_F mismatch at %0d: got %0d expected %0d",
                             k_dbg,
                             dut.u_bram_work.mem[k_dbg],
                             tv4_f[k_dbg]);

                end

                diff_count = diff_count + 1;

            end

        end

        if (diff_count == 0)
            $display("[DBG] COPY_F SUCCESS");
        else
            $display("[DBG] COPY_F FAILED: %0d mismatches", diff_count);

        wait (dut.pm_state == 4'd3);

        $display("");
        $display("[DBG] PM_SAVE_FHAT started");

        $display("[DBG] f_hat[0:3] = %0d, %0d, %0d, %0d",
                 dut.u_bram_work.mem[0],
                 dut.u_bram_work.mem[1],
                 dut.u_bram_work.mem[2],
                 dut.u_bram_work.mem[3]);

        wait (dut.pm_state == 4'd4);

        $display("[DBG] PM_COPY_G started");

        $display("[DBG] temp[0:3] = %0d, %0d, %0d, %0d",
                 dut.u_bram_temp.mem[0],
                 dut.u_bram_temp.mem[1],
                 dut.u_bram_temp.mem[2],
                 dut.u_bram_temp.mem[3]);

        wait (dut.pm_state == 4'd5);

        $display("[DBG] PM_NTT_G started");

        $display("[DBG] g[0:3] = %0d, %0d, %0d, %0d",
                 dut.u_bram_work.mem[0],
                 dut.u_bram_work.mem[1],
                 dut.u_bram_work.mem[2],
                 dut.u_bram_work.mem[3]);

        wait (dut.pm_state == 4'd6);

        $display("[DBG] PM_BASEMUL started");

        $display("[DBG] g_hat[0:3] = %0d, %0d, %0d, %0d",
                 dut.u_bram_work.mem[0],
                 dut.u_bram_work.mem[1],
                 dut.u_bram_work.mem[2],
                 dut.u_bram_work.mem[3]);

        wait (dut.pm_state == 4'd7);

        $display("[DBG] PM_INTT started");

        wait (dut.pm_state == 4'd8);

        $display("[DBG] PM_DONE reached");

        while ((done !== 1'b1) &&
               (timeout_count < TIMEOUT_CYCLES)) begin

            @(posedge clk);

            timeout_count = timeout_count + 1;

        end

        if (done === 1'b1) begin

            finished = 1'b1;

            $display("");
            $display("[TB] Coprocessor completed successfully.");
            $display("[TB] Execution cycles = %0d", cycle_count);

        end
        else begin

            timed_out = 1'b1;

            errors = errors + 1;

            $display("[TB] ERROR: Coprocessor timeout.");

        end

        if (finished) begin

            $display("");
            $display("[TB] Reading output polynomial h...");

            for (i = 0; i < N; i = i + 1) begin

                @(negedge clk);

                ext_ren = 1'b1;
                ext_raddr = i;

                @(negedge clk);
                @(negedge clk);
                @(negedge clk);

                result[i] = ext_rdata;

            end

            @(negedge clk);

            ext_ren = 1'b0;

            $display("[TB] Output reading completed.");

            if (result_file == 0) begin
                $display("[ERROR] Could not create poly_multiplier_output.mem");
                errors = errors + 1;
            end
            else begin
                for (i = 0; i < N; i = i + 1) begin
                    $fdisplay(result_file, "%03h", result[i]);
                end

                $fclose(result_file);

                $display("[TB] Final result written to poly_multiplier_output.mem");
            end

        end

        if (finished) begin

            $display("");
            $display("[TB] Comparing against NIST reference...");

            for (i = 0; i < N; i = i + 1) begin

                if (result[i] !== exp_h[i]) begin

                    if (errors < 10) begin

                        $display(
                            "MISMATCH index=%0d got=%0d expected=%0d",
                            i, result[i], exp_h[i]
                        );

                    end

                    errors = errors + 1;

                end

            end

        end

        $display("");
        $display("=================================================");
        $display(" FINAL TEST RESULTS");
        $display("=================================================");

        if (errors == 0) begin

            $display("PASS: All 256 coefficients match.");

            $display("First 8 coefficients:");

            $display("%0d %0d %0d %0d %0d %0d %0d %0d",
                     result[0], result[1],
                     result[2], result[3],
                     result[4], result[5],
                     result[6], result[7]);

        end

        else begin

            $display("FAIL: Total errors = %0d", errors);

        end

        $display("Execution cycles = %0d", cycle_count);

        $display("=================================================");

        $finish;

    end

endmodule
