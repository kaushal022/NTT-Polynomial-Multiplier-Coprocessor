`timescale 1ns / 1ps

module axi_demux #(
    parameter integer NUM_SLAVES      = 3,
    parameter integer ADDR_WIDTH      = 32,
    parameter integer DATA_WIDTH      = 32,
    parameter integer STRB_WIDTH      = DATA_WIDTH / 8
)(
    input  wire                   clk,
    input  wire                   resetn,

    input  wire [ADDR_WIDTH-1:0]  m_axi_awaddr,
    input  wire [2:0]             m_axi_awprot,
    input  wire                   m_axi_awvalid,
    output reg                    m_axi_awready,

    input  wire [DATA_WIDTH-1:0]  m_axi_wdata,
    input  wire [STRB_WIDTH-1:0]  m_axi_wstrb,
    input  wire                   m_axi_wvalid,
    output reg                    m_axi_wready,

    output reg  [1:0]             m_axi_bresp,
    output reg                    m_axi_bvalid,
    input  wire                   m_axi_bready,

    input  wire [ADDR_WIDTH-1:0]  m_axi_araddr,
    input  wire [2:0]             m_axi_arprot,
    input  wire                   m_axi_arvalid,
    output reg                    m_axi_arready,

    output reg  [DATA_WIDTH-1:0]  m_axi_rdata,
    output reg  [1:0]             m_axi_rresp,
    output reg                    m_axi_rvalid,
    input  wire                   m_axi_rready,

    output reg  [ADDR_WIDTH-1:0]  s0_axi_awaddr,
    output reg  [2:0]             s0_axi_awprot,
    output reg                    s0_axi_awvalid,
    input  wire                   s0_axi_awready,

    output reg  [DATA_WIDTH-1:0]  s0_axi_wdata,
    output reg  [STRB_WIDTH-1:0]  s0_axi_wstrb,
    output reg                    s0_axi_wvalid,
    input  wire                   s0_axi_wready,

    input  wire [1:0]             s0_axi_bresp,
    input  wire                   s0_axi_bvalid,
    output reg                    s0_axi_bready,

    output reg  [ADDR_WIDTH-1:0]  s0_axi_araddr,
    output reg  [2:0]             s0_axi_arprot,
    output reg                    s0_axi_arvalid,
    input  wire                   s0_axi_arready,

    input  wire [DATA_WIDTH-1:0]  s0_axi_rdata,
    input  wire [1:0]             s0_axi_rresp,
    input  wire                   s0_axi_rvalid,
    output reg                    s0_axi_rready,

    output reg  [ADDR_WIDTH-1:0]  s1_axi_awaddr,
    output reg  [2:0]             s1_axi_awprot,
    output reg                    s1_axi_awvalid,
    input  wire                   s1_axi_awready,

    output reg  [DATA_WIDTH-1:0]  s1_axi_wdata,
    output reg  [STRB_WIDTH-1:0]  s1_axi_wstrb,
    output reg                    s1_axi_wvalid,
    input  wire                   s1_axi_wready,

    input  wire [1:0]             s1_axi_bresp,
    input  wire                   s1_axi_bvalid,
    output reg                    s1_axi_bready,

    output reg  [ADDR_WIDTH-1:0]  s1_axi_araddr,
    output reg  [2:0]             s1_axi_arprot,
    output reg                    s1_axi_arvalid,
    input  wire                   s1_axi_arready,

    input  wire [DATA_WIDTH-1:0]  s1_axi_rdata,
    input  wire [1:0]             s1_axi_rresp,
    input  wire                   s1_axi_rvalid,
    output reg                    s1_axi_rready,

    output reg  [ADDR_WIDTH-1:0]  s2_axi_awaddr,
    output reg  [2:0]             s2_axi_awprot,
    output reg                    s2_axi_awvalid,
    input  wire                   s2_axi_awready,

    output reg  [DATA_WIDTH-1:0]  s2_axi_wdata,
    output reg  [STRB_WIDTH-1:0]  s2_axi_wstrb,
    output reg                    s2_axi_wvalid,
    input  wire                   s2_axi_wready,

    input  wire [1:0]             s2_axi_bresp,
    input  wire                   s2_axi_bvalid,
    output reg                    s2_axi_bready,

    output reg  [ADDR_WIDTH-1:0]  s2_axi_araddr,
    output reg  [2:0]             s2_axi_arprot,
    output reg                    s2_axi_arvalid,
    input  wire                   s2_axi_arready,

    input  wire [DATA_WIDTH-1:0]  s2_axi_rdata,
    input  wire [1:0]             s2_axi_rresp,
    input  wire                   s2_axi_rvalid,
    output reg                    s2_axi_rready
);

    function [1:0] decode_slave;
        input [ADDR_WIDTH-1:0] addr;
        begin
            if      (addr[31:16] == 16'h0000) decode_slave = 2'd0;
            else if (addr[31:16] == 16'h4000) decode_slave = 2'd1;
            else if (addr[31:16] == 16'h4001) decode_slave = 2'd2;
            else                              decode_slave = 2'd3;
        end
    endfunction

    reg [1:0] wr_sel_r;
    reg [1:0] rd_sel_r;
    reg       wr_busy_r;
    reg       rd_busy_r;

    wire [1:0] wr_sel = wr_busy_r ? wr_sel_r : decode_slave(m_axi_awaddr);

    reg       decerr_bvalid_r;
    reg       decerr_rvalid_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wr_sel_r       <= 2'd0;
            wr_busy_r      <= 1'b0;
            decerr_bvalid_r <= 1'b0;
        end else begin
            if (m_axi_awvalid && m_axi_awready) begin
                wr_sel_r  <= decode_slave(m_axi_awaddr);
                wr_busy_r <= 1'b1;
            end
            if (m_axi_bvalid && m_axi_bready) begin
                wr_busy_r <= 1'b0;
            end
            if (m_axi_awvalid && m_axi_awready && (decode_slave(m_axi_awaddr) == 2'd3)) begin
                decerr_bvalid_r <= 1'b1;
            end else if (decerr_bvalid_r && m_axi_bready) begin
                decerr_bvalid_r <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rd_sel_r       <= 2'd0;
            rd_busy_r      <= 1'b0;
            decerr_rvalid_r <= 1'b0;
        end else begin
            if (m_axi_arvalid && m_axi_arready) begin
                rd_sel_r  <= decode_slave(m_axi_araddr);
                rd_busy_r <= 1'b1;
            end
            if (m_axi_rvalid && m_axi_rready) begin
                rd_busy_r <= 1'b0;
            end
            if (m_axi_arvalid && m_axi_arready && (decode_slave(m_axi_araddr) == 2'd3)) begin
                decerr_rvalid_r <= 1'b1;
            end else if (decerr_rvalid_r && m_axi_rready) begin
                decerr_rvalid_r <= 1'b0;
            end
        end
    end

    always @(*) begin
        // Default: deassert all slave valids / readys
        s0_axi_awaddr  = m_axi_awaddr;
        s0_axi_awprot  = m_axi_awprot;
        s0_axi_awvalid = 1'b0;
        s1_axi_awaddr  = m_axi_awaddr;
        s1_axi_awprot  = m_axi_awprot;
        s1_axi_awvalid = 1'b0;
        s2_axi_awaddr  = m_axi_awaddr;
        s2_axi_awprot  = m_axi_awprot;
        s2_axi_awvalid = 1'b0;

        s0_axi_wdata   = m_axi_wdata;
        s0_axi_wstrb   = m_axi_wstrb;
        s0_axi_wvalid  = 1'b0;
        s1_axi_wdata   = m_axi_wdata;
        s1_axi_wstrb   = m_axi_wstrb;
        s1_axi_wvalid  = 1'b0;
        s2_axi_wdata   = m_axi_wdata;
        s2_axi_wstrb   = m_axi_wstrb;
        s2_axi_wvalid  = 1'b0;

        s0_axi_bready  = 1'b0;
        s1_axi_bready  = 1'b0;
        s2_axi_bready  = 1'b0;

        m_axi_awready  = 1'b0;
        m_axi_wready   = 1'b0;
        m_axi_bresp    = 2'b10; // SLVERR default
        m_axi_bvalid   = 1'b0;

        case (decode_slave(m_axi_awaddr))
            2'd0: begin
                s0_axi_awvalid = m_axi_awvalid;
                m_axi_awready  = s0_axi_awready;
            end
            2'd1: begin
                s1_axi_awvalid = m_axi_awvalid;
                m_axi_awready  = s1_axi_awready;
            end
            2'd2: begin
                s2_axi_awvalid = m_axi_awvalid;
                m_axi_awready  = s2_axi_awready;
            end
            default: begin
                // Unmapped: accept the address immediately, generate DECERR
                m_axi_awready  = 1'b1;
            end
        endcase

        // W channel: steer based on active write slave select
        case (wr_sel)
            2'd0: begin
                s0_axi_wvalid = m_axi_wvalid;
                m_axi_wready  = s0_axi_wready;
            end
            2'd1: begin
                s1_axi_wvalid = m_axi_wvalid;
                m_axi_wready  = s1_axi_wready;
            end
            2'd2: begin
                s2_axi_wvalid = m_axi_wvalid;
                m_axi_wready  = s2_axi_wready;
            end
            default: begin
                m_axi_wready  = 1'b1; // consume spurious write data
            end
        endcase

        // B channel: steer based on registered slave select
        case (wr_sel_r)
            2'd0: begin
                m_axi_bresp   = s0_axi_bresp;
                m_axi_bvalid  = s0_axi_bvalid;
                s0_axi_bready = m_axi_bready;
            end
            2'd1: begin
                m_axi_bresp   = s1_axi_bresp;
                m_axi_bvalid  = s1_axi_bvalid;
                s1_axi_bready = m_axi_bready;
            end
            2'd2: begin
                m_axi_bresp   = s2_axi_bresp;
                m_axi_bvalid  = s2_axi_bvalid;
                s2_axi_bready = m_axi_bready;
            end
            default: begin
                // DECERR response from internal register
                m_axi_bresp   = 2'b11; // DECERR
                m_axi_bvalid  = decerr_bvalid_r;
            end
        endcase
    end

    // =========================================================================
    // AR / R channel steering (combinational mux)
    // =========================================================================
    always @(*) begin
        s0_axi_araddr  = m_axi_araddr;
        s0_axi_arprot  = m_axi_arprot;
        s0_axi_arvalid = 1'b0;
        s1_axi_araddr  = m_axi_araddr;
        s1_axi_arprot  = m_axi_arprot;
        s1_axi_arvalid = 1'b0;
        s2_axi_araddr  = m_axi_araddr;
        s2_axi_arprot  = m_axi_arprot;
        s2_axi_arvalid = 1'b0;

        s0_axi_rready  = 1'b0;
        s1_axi_rready  = 1'b0;
        s2_axi_rready  = 1'b0;

        m_axi_arready  = 1'b0;
        m_axi_rdata    = 32'hDEAD_BEEF;
        m_axi_rresp    = 2'b11;
        m_axi_rvalid   = 1'b0;

        case (decode_slave(m_axi_araddr))
            2'd0: begin
                s0_axi_arvalid = m_axi_arvalid;
                m_axi_arready  = s0_axi_arready;
            end
            2'd1: begin
                s1_axi_arvalid = m_axi_arvalid;
                m_axi_arready  = s1_axi_arready;
            end
            2'd2: begin
                s2_axi_arvalid = m_axi_arvalid;
                m_axi_arready  = s2_axi_arready;
            end
            default: begin
                m_axi_arready  = 1'b1;
            end
        endcase

        case (rd_sel_r)
            2'd0: begin
                m_axi_rdata    = s0_axi_rdata;
                m_axi_rresp    = s0_axi_rresp;
                m_axi_rvalid   = s0_axi_rvalid;
                s0_axi_rready  = m_axi_rready;
            end
            2'd1: begin
                m_axi_rdata    = s1_axi_rdata;
                m_axi_rresp    = s1_axi_rresp;
                m_axi_rvalid   = s1_axi_rvalid;
                s1_axi_rready  = m_axi_rready;
            end
            2'd2: begin
                m_axi_rdata    = s2_axi_rdata;
                m_axi_rresp    = s2_axi_rresp;
                m_axi_rvalid   = s2_axi_rvalid;
                s2_axi_rready  = m_axi_rready;
            end
            default: begin
                m_axi_rdata    = 32'hDEAD_BEEF;
                m_axi_rresp    = 2'b11;
                m_axi_rvalid   = decerr_rvalid_r;
            end
        endcase
    end

endmodule
