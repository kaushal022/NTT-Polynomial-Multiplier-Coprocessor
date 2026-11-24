`timescale 1ns / 1ps

module tb_arithmetic;

    reg clk, rst_n;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    reg  [11:0] a, b;
    wire [11:0] add_result, sub_result, mul_result;

    mod_add u_add (.a(a), .b(b), .result(add_result));
    mod_sub u_sub (.a(a), .b(b), .result(sub_result));
    mod_mul u_mul (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .result(mul_result));

    integer pass_count = 0;
    integer fail_count = 0;
    integer test_count = 0;
    integer i;

    reg [31:0] lfsr;

    localparam Q = 3329;

    reg [11:0] exp_add, exp_sub, exp_mul;
    reg [23:0] product;

    task check_result;
        input [11:0] got;
        input [11:0] expected;
        input [63:0] op_name;
        begin
            test_count = test_count + 1;
            if (got !== expected) begin
                $display("FAIL: %0s(%0d, %0d) = %0d, expected %0d",
                         op_name, a, b, got, expected);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end
        end
    endtask

    function [31:0] lfsr_next;
        input [31:0] state;
        begin
            lfsr_next = {state[30:0], state[31] ^ state[21] ^ state[1] ^ state[0]};
        end
    endfunction

    initial begin
        $display("=== Modular Arithmetic Testbench ===");
        $display("q = %0d", Q);

        rst_n = 0;
        a = 0; b = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("\n--- Boundary Tests ---");

        a = 0; b = 0; #1;
        exp_add = 0; check_result(add_result, exp_add, "add     ");

        a = 0; b = Q-1; #1;
        exp_add = Q-1; check_result(add_result, exp_add, "add     ");

        a = Q-1; b = 1; #1;
        exp_add = 0; check_result(add_result, exp_add, "add     ");

        a = Q-1; b = Q-1; #1;
        exp_add = (2*(Q-1)) % Q; check_result(add_result, exp_add, "add     ");

        a = 1; b = 1; #1;
        exp_add = 2; check_result(add_result, exp_add, "add     ");

        a = 0; b = 0; #1;
        exp_sub = 0; check_result(sub_result, exp_sub, "sub     ");

        a = 0; b = 1; #1;
        exp_sub = Q-1; check_result(sub_result, exp_sub, "sub     ");

        a = Q-1; b = Q-1; #1;
        exp_sub = 0; check_result(sub_result, exp_sub, "sub     ");

        a = 1; b = Q-1; #1;
        exp_sub = 2; check_result(sub_result, exp_sub, "sub     ");

        a = 0; b = Q-1; repeat(3) @(posedge clk); #1;
        exp_mul = 0; check_result(mul_result, exp_mul, "mul     ");

        a = 1; b = Q-1; repeat(3) @(posedge clk); #1;
        exp_mul = Q-1; check_result(mul_result, exp_mul, "mul     ");

        a = Q-1; b = Q-1; repeat(3) @(posedge clk); #1;
        product = (Q-1) * (Q-1);
        exp_mul = product % Q;
        check_result(mul_result, exp_mul, "mul     ");

        a = 2; b = 1665; repeat(3) @(posedge clk); #1;
        exp_mul = 1; check_result(mul_result, exp_mul, "mul     ");

        a = 17; b = 17; repeat(3) @(posedge clk); #1;
        exp_mul = (17*17) % Q;
        check_result(mul_result, exp_mul, "mul     ");

        $display("\n--- Randomized Tests (10000 iterations) ---");
        lfsr = 32'hDEADBEEF;

        for (i = 0; i < 10000; i = i + 1) begin
            lfsr = lfsr_next(lfsr);
            a = lfsr[11:0] % Q;
            lfsr = lfsr_next(lfsr);
            b = lfsr[11:0] % Q;
            #1;

            exp_add = (a + b) % Q;
            check_result(add_result, exp_add, "add     ");

            exp_sub = (a + Q - b) % Q;
            check_result(sub_result, exp_sub, "sub     ");

            product = a * b;
            exp_mul = product % Q;
            repeat(3) @(posedge clk); #1;
            check_result(mul_result, exp_mul, "mul     ");
        end

        $display("\n=== Results ===");
        $display("Total tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        if (fail_count == 0)
            $display("STATUS: ALL TESTS PASSED");
        else
            $display("STATUS: SOME TESTS FAILED");

        $finish;
    end

endmodule
