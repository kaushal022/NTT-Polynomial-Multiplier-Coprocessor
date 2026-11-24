`timescale 1ns / 1ps

module tb_soc_top;

    reg sys_clk_125 = 1'b0;
    always #4 sys_clk_125 = ~sys_clk_125;

    reg        sys_rst_n = 1'b1;
    reg        uart_rx   = 1'b1;
    wire       uart_tx;
    wire [3:0] led;

    soc_top dut (
        .sys_clk_125 (sys_clk_125),
        .sys_rst_n   (sys_rst_n),
        .uart_tx     (uart_tx),
        .uart_rx     (uart_rx),
        .led         (led)
    );

    reg [11:0] golden_h [0:255];

    integer mismatches;

    initial begin
        golden_h[0]  = 12'h96D; golden_h[1]  = 12'hB69;
        golden_h[2]  = 12'hC14; golden_h[3]  = 12'h74B;
        golden_h[4]  = 12'h0D3; golden_h[5]  = 12'hB6A;
        golden_h[6]  = 12'h1B6; golden_h[7]  = 12'hCE4;
        golden_h[8]  = 12'h9C3; golden_h[9]  = 12'h1DC;
        golden_h[10] = 12'h39E; golden_h[11] = 12'h5D0;
        $readmemh("tv_polymul_result.hex", golden_h);
    end

    integer coeff_count;
    integer pass_count;
    initial begin
        coeff_count = 0;
        pass_count  = 0;
        mismatches  = 0;
    end

    initial begin
        $timeformat(-9, 3, " ns", 12);
        $display("");
        $display("========================================================================");
        $display("  ML-KEM NTT Coprocessor — SoC Integration Testbench (tb_soc_top)");
        $display("========================================================================");
        $display("  SoC     : PicoRV32 RV32I + AXI4-Lite demux + ML-KEM accelerator");
        $display("  Clocks  : 125 MHz (board) -> 100 MHz PLLE2_BASE (system)");
        $display("  Firmware: firmware.hex — autonomous NIST FIPS 203 self-test loop");
        $display("========================================================================");
        $display("");

        #200;
        sys_rst_n = 1'b0;
        $display("[%t] BTN0 released — sys_rst_n deasserted (0). CPU boot begins.", $realtime);

        wait (dut.pll_locked === 1'b1);
        $display("[%t] PLL locked. 100 MHz system clock active.", $realtime);

        wait (dut.resetn === 1'b1);
        $display("[%t] resetn asserted. PicoRV32 starts fetching from PC=0x00000000.", $realtime);
        $display("");

        #1500000;
        $display("[%t] TIMEOUT: simulation did not complete within 1.5 ms.", $realtime);
        $display("  LED state: LD0(Ready)=%b  LD1(Busy)=%b  LD2(Done)=%b  LD3(Trap)=%b",
                 led[0], led[1], led[2], led[3]);
        $display("  Coprocessor cycle counter : %0d", dut.core_cycle_count_w);
        $display("  Coefficients captured so far: %0d / 256", coeff_count);
        $finish;
    end

    always @(posedge dut.clk_100m) begin
        if (dut.resetn && dut.cpu_trap) begin
            $display("[%t] FAIL: PicoRV32 CPU TRAP asserted (LD3=1).", $realtime);
            $display("  Likely cause: unaligned memory access or illegal opcode.");
            $display("  core_start=%b  core_done=%b  busy=%b  cycle=%0d",
                     dut.core_start_w, dut.core_done_w,
                     dut.mlkem_busy_w, dut.core_cycle_count_w);
            $finish;
        end
    end

    always @(posedge dut.clk_100m) begin
        if (dut.resetn && dut.core_start_w) begin
            $display("[%t] COPROC START — AXI write to 0x4000_0000 detected.", $realtime);
        end
    end

    reg prev_busy_r = 1'b0;
    always @(posedge dut.clk_100m) begin
        if (dut.resetn) begin
            if (dut.mlkem_busy_w && !prev_busy_r)
                $display("[%t] COPROC BUSY — NTT pipeline running at 100 MHz.", $realtime);
            if (!dut.mlkem_busy_w && prev_busy_r)
                $display("[%t] COPROC IDLE — computation pipeline finished.", $realtime);
            prev_busy_r <= dut.mlkem_busy_w;
        end else begin
            prev_busy_r <= 1'b0;
        end
    end

    always @(posedge dut.clk_100m) begin
        if (dut.resetn && dut.core_done_w) begin
            $display("");
            $display("------------------------------------------------------------------------");
            $display("[%t] COPROC DONE — core_done_w pulsed.", $realtime);
            $display("  Hardware latency: %0d cycles  (%.2f us @ 100 MHz)",
                     dut.core_cycle_count_w,
                     (dut.core_cycle_count_w * 10) / 1000);
            $display("------------------------------------------------------------------------");
        end
    end

    always @(posedge dut.clk_100m) begin
        if (dut.resetn && dut.mlkem_irq)
            $display("[%t] IRQ — mlkem_irq pulsed to PicoRV32 (vector 0x00000010).", $realtime);
    end

    reg        ren_p1,   ren_p2;
    reg [7:0]  raddr_p1, raddr_p2;

    always @(posedge dut.clk_100m) begin
        if (!dut.resetn) begin
            ren_p1   <= 1'b0;  ren_p2   <= 1'b0;
            raddr_p1 <= 8'd0;  raddr_p2 <= 8'd0;
        end else begin
            ren_p1   <= dut.dbg_result_ren;
            ren_p2   <= ren_p1;
            raddr_p1 <= dut.dbg_result_raddr;
            raddr_p2 <= raddr_p1;

            if (ren_p2) begin
                coeff_count = coeff_count + 1;

                if (coeff_count <= 16 || coeff_count == 256) begin
                    $display("  Coeff[%3d]  hw=0x%03X (%4d)  ref=0x%03X (%4d)  %s",
                             raddr_p2,
                             dut.dbg_result_rdata, dut.dbg_result_rdata,
                             golden_h[raddr_p2],   golden_h[raddr_p2],
                             (dut.dbg_result_rdata === golden_h[raddr_p2]) ? "PASS" : "MISMATCH");
                end

                if (dut.dbg_result_rdata === golden_h[raddr_p2])
                    pass_count = pass_count + 1;
                else
                    mismatches = mismatches + 1;

                if (coeff_count == 256) begin
                    $display("");
                    $display("========================================================================");
                    if (mismatches == 0) begin
                        $display("  RESULT: ALL 256 COEFFICIENTS MATCH — NIST FIPS 203 VERIFIED");
                        $display("  Bit-exact NTT polynomial multiplication confirmed on SoC hardware.");
                    end else begin
                        $display("  RESULT: FAIL — %0d / 256 coefficient mismatches detected.", mismatches);
                    end
                    $display("  LED: LD0(Rdy)=%b  LD1(Bsy)=%b  LD2(Done)=%b  LD3(Trap)=%b",
                             led[0], led[1], led[2], led[3]);
                    $display("  Latency: %0d cycles", dut.core_cycle_count_w);
                    $display("========================================================================");
                    $display("");
                    #200;
                    $finish;
                end
            end
        end
    end

endmodule
