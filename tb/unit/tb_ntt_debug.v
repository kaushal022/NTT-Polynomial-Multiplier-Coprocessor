`timescale 1ns / 1ps

module tb_ntt_debug;

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

    always @(posedge clk) begin
        if (busy && cycle_count < 50) begin
            $display("T=%0t state=%0d ag_valid=%b ag_done=%b ag_lo=%0d ag_hi=%0d ag_tw=%0d bfly_vi=%b bfly_vo=%b",
                     $time,
                     u_eng.state,
                     u_eng.u_addr_gen.pair_valid,
                     u_eng.u_addr_gen.ntt_done,
                     u_eng.u_addr_gen.addr_lo,
                     u_eng.u_addr_gen.addr_hi,
                     u_eng.u_addr_gen.tw_addr,
                     u_eng.bfly_valid_in,
                     u_eng.u_butterfly.valid_out);
        end
    end

    initial begin
        $display("=== NTT Engine Debug ===");
        rst_n = 0; start = 0; mode = 0; ctrl = 0;
        tb_ena = 0; tb_wea = 0; tb_addra = 0; tb_dina = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(3) @(posedge clk);

        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clk);
            tb_ena <= 1; tb_wea <= 1; tb_addra <= i; tb_dina <= i;
        end
        @(posedge clk);
        tb_ena <= 0; tb_wea <= 0;
        repeat(3) @(posedge clk);

        ctrl = 1;
        @(posedge clk);
        mode <= 0;
        start <= 1;
        @(posedge clk);
        start <= 0;

        repeat(200) @(posedge clk);

        if (!done)
            $display("Engine still busy after 200 cycles, state=%0d", u_eng.state);

        $finish;
    end

endmodule
