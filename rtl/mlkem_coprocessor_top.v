`timescale 1ns / 1ps

module mlkem_coprocessor_top #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)(
    input  wire                                s_axi_aclk,
    input  wire                                s_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  wire [2:0]                          s_axi_awprot,
    input  wire                                s_axi_awvalid,
    output wire                                s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   s_axi_wstrb,
    input  wire                                s_axi_wvalid,
    output wire                                s_axi_wready,

    output wire [1:0]                          s_axi_bresp,
    output wire                                s_axi_bvalid,
    input  wire                                s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  wire [2:0]                          s_axi_arprot,
    input  wire                                s_axi_arvalid,
    output wire                                s_axi_arready,

    output wire [C_S_AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output wire [1:0]                          s_axi_rresp,
    output wire                                s_axi_rvalid,
    input  wire                                s_axi_rready,

    output wire                                irq,
    output wire                                core_busy,
    output wire                                core_start,
    output wire                                core_done,
    output wire [15:0]                         core_cycle_count,

    output wire                                dbg_result_ren,
    output wire [7:0]                          dbg_result_raddr,
    output wire [11:0]                         dbg_result_rdata
);

    wire        axi_ext_wen_f;
    wire        axi_ext_wen_g;
    wire [7:0]  axi_ext_addr;
    wire [11:0] axi_ext_wdata_f;
    wire [11:0] axi_ext_wdata_g;

    wire        axi_ext_ren;
    wire [7:0]  axi_ext_raddr;
    wire [11:0] axi_ext_rdata;

    assign dbg_result_ren   = axi_ext_ren;
    assign dbg_result_raddr = axi_ext_raddr;
    assign dbg_result_rdata = axi_ext_rdata;

    axi_lite_coprocessor #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) u_axi_slave (
        .clk              (s_axi_aclk),
        .rst_n            (s_axi_aresetn),
        .s_axi_awaddr     (s_axi_awaddr),
        .s_axi_awprot     (s_axi_awprot),
        .s_axi_awvalid    (s_axi_awvalid),
        .s_axi_awready    (s_axi_awready),
        .s_axi_wdata      (s_axi_wdata),
        .s_axi_wstrb      (s_axi_wstrb),
        .s_axi_wvalid     (s_axi_wvalid),
        .s_axi_wready     (s_axi_wready),
        .s_axi_bresp      (s_axi_bresp),
        .s_axi_bvalid     (s_axi_bvalid),
        .s_axi_bready     (s_axi_bready),
        .s_axi_araddr     (s_axi_araddr),
        .s_axi_arprot     (s_axi_arprot),
        .s_axi_arvalid    (s_axi_arvalid),
        .s_axi_arready    (s_axi_arready),
        .s_axi_rdata      (s_axi_rdata),
        .s_axi_rresp      (s_axi_rresp),
        .s_axi_rvalid     (s_axi_rvalid),
        .s_axi_rready     (s_axi_rready),

        .core_start       (core_start),
        .core_done        (core_done),
        .core_busy        (core_busy),
        .core_cycle_count (core_cycle_count),

        .core_ext_wen_f   (axi_ext_wen_f),
        .core_ext_wen_g   (axi_ext_wen_g),
        .core_ext_addr    (axi_ext_addr),
        .core_ext_wdata_f (axi_ext_wdata_f),
        .core_ext_wdata_g (axi_ext_wdata_g),

        .core_ext_ren     (axi_ext_ren),
        .core_ext_raddr   (axi_ext_raddr),
        .core_ext_rdata   (axi_ext_rdata),

        .irq              (irq)
    );

    poly_multiplier u_poly_mul_core (
        .clk         (s_axi_aclk),
        .rst_n       (s_axi_aresetn),
        .start       (core_start),
        .done        (core_done),
        .busy        (core_busy),
        .cycle_count (core_cycle_count),

        .ext_wen_f   (axi_ext_wen_f),
        .ext_wen_g   (axi_ext_wen_g),
        .ext_addr    (axi_ext_addr),
        .ext_wdata_f (axi_ext_wdata_f),
        .ext_wdata_g (axi_ext_wdata_g),

        .ext_ren     (axi_ext_ren),
        .ext_raddr   (axi_ext_raddr),
        .ext_rdata   (axi_ext_rdata)
    );

endmodule
