`timescale 1ns / 1ps

module tb_ntt_layer_debug;

    parameter CLK_PERIOD = 10;

    reg clk, rst_n, start, mode;
    wire done, busy;
    wire [15:0] cycle_count;

    wire bram_ena, bram_wea;
    wire [7:0]  bram_addra;
    wire [11:0] bram_dina, bram_douta;
    wire bram_enb, bram_web;
    wire [7:0]  bram_addrb;
    wire [11:0] bram_dinb, bram_doutb;

    reg  tb_ena, tb_wea;
    reg  [7:0]  tb_addra;
    reg  [11:0] tb_dina;
    reg  ctrl;

    wire m_ena   = ctrl ? bram_ena : tb_ena;
    wire m_wea   = ctrl ? bram_wea : tb_wea;
    wire [7:0]  m_addra = ctrl ? bram_addra : tb_addra;
    wire [11:0] m_dina  = ctrl ? bram_dina : tb_dina;
    wire m_enb   = ctrl ? bram_enb : 1'b0;
    wire m_web   = ctrl ? bram_web : 1'b0;
    wire [7:0]  m_addrb = ctrl ? bram_addrb : 8'd0;
    wire [11:0] m_dinb  = ctrl ? bram_dinb : 12'd0;

    poly_bram u_bram (
        .clk(clk),
        .ena(m_ena), .wea(m_wea), .addra(m_addra), .dina(m_dina), .douta(bram_douta),
        .enb(m_enb), .web(m_web), .addrb(m_addrb), .dinb(m_dinb), .doutb(bram_doutb)
    );

    ntt_engine u_eng (
        .clk(clk), .rst_n(rst_n),
        .start(start), .mode(mode),
        .done(done), .busy(busy), .cycle_count(cycle_count),
        .bram_ena(bram_ena), .bram_wea(bram_wea), .bram_addra(bram_addra),
        .bram_dina(bram_dina), .bram_douta(bram_douta),
        .bram_enb(bram_enb), .bram_web(bram_web), .bram_addrb(bram_addrb),
        .bram_dinb(bram_dinb), .bram_doutb(bram_doutb),
        .scr_ena(1'b0), .scr_addr(8'd0), .scr_data(),
        .result_in_scratch()
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    integer i;
    integer cycle_cnt;

    reg [2:0] prev_layer;
    reg prev_ntt_done;
    always @(posedge clk) begin
        if (busy) begin
            if (u_eng.u_addr_gen.layer_idx !== prev_layer) begin
                $display("T=%0t LAYER CHANGE: %0d -> %0d, k=%0d, len=%0d, j=%0d, gs=%0d",
                         $time, prev_layer, u_eng.u_addr_gen.layer_idx,
                         u_eng.u_addr_gen.k, u_eng.u_addr_gen.len,
                         u_eng.u_addr_gen.j, u_eng.u_addr_gen.group_start);
            end
            prev_layer = u_eng.u_addr_gen.layer_idx;

            if (u_eng.u_addr_gen.ntt_done && !prev_ntt_done)
                $display("T=%0t NTT_DONE fired!", $time);
            prev_ntt_done = u_eng.u_addr_gen.ntt_done;

            if (cycle_count % 1000 == 0 && cycle_count > 0)
                $display("T=%0t cycle=%0d state=%0d layer=%0d addr=%0d,%0d",
                         $time, cycle_count, u_eng.state,
                         u_eng.u_addr_gen.layer_idx,
                         u_eng.u_addr_gen.addr_lo, u_eng.u_addr_gen.addr_hi);
        end
    end

    initial begin
        $display("=== NTT Layer Debug ===");
        rst_n = 0; start = 0; mode = 0; ctrl = 0;
        tb_ena = 0; tb_wea = 0; tb_addra = 0; tb_dina = 0;
        prev_layer = 0; prev_ntt_done = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(3) @(posedge clk);

        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clk);
            tb_ena <= 1; tb_wea <= 1; tb_addra <= i; tb_dina <= 0;
        end
        @(posedge clk);
        tb_ena <= 0; tb_wea <= 0;
        repeat(3) @(posedge clk);

        ctrl = 1;
        @(posedge clk);
        mode  <= 0;
        start <= 1;
        @(posedge clk);
        start <= 0;

        for (cycle_cnt = 0; cycle_cnt < 20000; cycle_cnt = cycle_cnt + 1) begin
            @(posedge clk);
            if (done) begin
                $display("DONE at cycle %0d", cycle_cnt);
                cycle_cnt = 20000;
            end
        end

        if (!done)
            $display("NOT DONE after 20000 cycles. State=%0d, Layer=%0d, AddrLo=%0d, AddrHi=%0d, k=%0d, len=%0d, j=%0d, gs=%0d, pair_valid=%b",
                     u_eng.state, u_eng.u_addr_gen.layer_idx,
                     u_eng.u_addr_gen.addr_lo, u_eng.u_addr_gen.addr_hi,
                     u_eng.u_addr_gen.k, u_eng.u_addr_gen.len,
                     u_eng.u_addr_gen.j, u_eng.u_addr_gen.group_start,
                     u_eng.u_addr_gen.pair_valid);

        $finish;
    end

endmodule
