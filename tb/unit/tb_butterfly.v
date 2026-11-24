`timescale 1ns / 1ps

module tb_butterfly;

    parameter Q = 3329;
    parameter CLK_PERIOD = 10;

    reg         clk, rst_n;
    reg         valid_in, mode;
    reg  [11:0] a, b, w;
    wire        valid_out;
    wire [11:0] out_lo, out_hi;

    butterfly u_dut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .mode(mode),
        .a(a), .b(b), .w(w),
        .valid_out(valid_out), .out_lo(out_lo), .out_hi(out_hi)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    integer pass_count, fail_count, test_count, i;
    reg [11:0] exp_lo, exp_hi, t_val;
    reg [11:0] ta, tb_r, tw;
    reg [31:0] lfsr;

    function [31:0] lfsr_next;
        input [31:0] state;
        begin
            lfsr_next = {state[30:0], state[31] ^ state[21] ^ state[1] ^ state[0]};
        end
    endfunction

    function [11:0] mod_add_f;
        input [11:0] x, y;
        reg [12:0] s;
        begin
            s = x + y;
            mod_add_f = (s >= Q) ? (s - Q) : s[11:0];
        end
    endfunction

    function [11:0] mod_sub_f;
        input [11:0] x, y;
        reg [12:0] d;
        begin
            d = {1'b0, x} - {1'b0, y};
            mod_sub_f = d[12] ? (d + Q) : d[11:0];
        end
    endfunction

    function [11:0] mod_mul_f;
        input [11:0] x, y;
        reg [23:0] p;
        begin
            p = x * y;
            mod_mul_f = p % Q;
        end
    endfunction

    task apply_and_check;
        input [11:0] in_a, in_b, in_w;
        input        in_mode;
        input [11:0] e_lo, e_hi;
        begin
            @(posedge clk);
            a        <= in_a;
            b        <= in_b;
            w        <= in_w;
            mode     <= in_mode;
            valid_in <= 1'b1;
            @(posedge clk);
            valid_in <= 1'b0;
            while (!valid_out) @(posedge clk);

            test_count = test_count + 1;
            if (out_lo !== e_lo || out_hi !== e_hi) begin
                $display("FAIL [%0d]: mode=%0d a=%0d b=%0d w=%0d -> got(%0d,%0d) exp(%0d,%0d)",
                         test_count, in_mode, in_a, in_b, in_w, out_lo, out_hi, e_lo, e_hi);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== Butterfly Testbench ===");
        pass_count = 0;
        fail_count = 0;
        test_count = 0;

        rst_n = 0; valid_in = 0; mode = 0; a = 0; b = 0; w = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        t_val = mod_mul_f(12'd200, 12'd1729);
        exp_lo = mod_add_f(12'd100, t_val);
        exp_hi = mod_sub_f(12'd100, t_val);
        apply_and_check(12'd100, 12'd200, 12'd1729, 1'b0, exp_lo, exp_hi);

        apply_and_check(12'd0, 12'd0, 12'd1729, 1'b0, 12'd0, 12'd0);

        t_val = mod_mul_f(Q-1, 12'd1);
        exp_lo = mod_add_f(Q-1, t_val);
        exp_hi = mod_sub_f(Q-1, t_val);
        apply_and_check(Q-1, Q-1, 12'd1, 1'b0, exp_lo, exp_hi);

        exp_lo = mod_add_f(12'd100, 12'd200);
        exp_hi = mod_mul_f(mod_sub_f(12'd200, 12'd100), 12'd1729);
        apply_and_check(12'd100, 12'd200, 12'd1729, 1'b1, exp_lo, exp_hi);

        apply_and_check(12'd0, 12'd0, 12'd1729, 1'b1, 12'd0, 12'd0);

        $display("Running 2000 random tests (1000 FW + 1000 GS)...");
        lfsr = 32'hCAFEBABE;

        for (i = 0; i < 1000; i = i + 1) begin
            lfsr = lfsr_next(lfsr);
            ta = lfsr[11:0] % Q;
            lfsr = lfsr_next(lfsr);
            tb_r = lfsr[11:0] % Q;
            lfsr = lfsr_next(lfsr);
            tw = lfsr[11:0] % Q;

            t_val = mod_mul_f(tb_r, tw);
            exp_lo = mod_add_f(ta, t_val);
            exp_hi = mod_sub_f(ta, t_val);
            apply_and_check(ta, tb_r, tw, 1'b0, exp_lo, exp_hi);

            exp_lo = mod_add_f(ta, tb_r);
            exp_hi = mod_mul_f(mod_sub_f(tb_r, ta), tw);
            apply_and_check(ta, tb_r, tw, 1'b1, exp_lo, exp_hi);
        end

        $display("\n=== Results ===");
        $display("Total: %0d  Passed: %0d  Failed: %0d", test_count, pass_count, fail_count);
        if (fail_count == 0)
            $display("STATUS: ALL TESTS PASSED");
        else
            $display("STATUS: SOME TESTS FAILED");

        $finish;
    end

endmodule
