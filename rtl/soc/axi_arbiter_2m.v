`timescale 1ns / 1ps

module axi_arbiter_2m #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    resetn,

    input  wire [ADDR_WIDTH-1:0]   m0_axi_awaddr,
    input  wire [2:0]              m0_axi_awprot,
    input  wire                    m0_axi_awvalid,
    output reg                     m0_axi_awready,
    input  wire [DATA_WIDTH-1:0]   m0_axi_wdata,
    input  wire [3:0]              m0_axi_wstrb,
    input  wire                    m0_axi_wvalid,
    output reg                     m0_axi_wready,
    output reg  [1:0]              m0_axi_bresp,
    output reg                     m0_axi_bvalid,
    input  wire                    m0_axi_bready,
    input  wire [ADDR_WIDTH-1:0]   m0_axi_araddr,
    input  wire [2:0]              m0_axi_arprot,
    input  wire                    m0_axi_arvalid,
    output reg                     m0_axi_arready,
    output reg  [DATA_WIDTH-1:0]   m0_axi_rdata,
    output reg  [1:0]              m0_axi_rresp,
    output reg                     m0_axi_rvalid,
    input  wire                    m0_axi_rready,

    input  wire [ADDR_WIDTH-1:0]   m1_axi_awaddr,
    input  wire [2:0]              m1_axi_awprot,
    input  wire                    m1_axi_awvalid,
    output reg                     m1_axi_awready,
    input  wire [DATA_WIDTH-1:0]   m1_axi_wdata,
    input  wire [3:0]              m1_axi_wstrb,
    input  wire                    m1_axi_wvalid,
    output reg                     m1_axi_wready,
    output reg  [1:0]              m1_axi_bresp,
    output reg                     m1_axi_bvalid,
    input  wire                    m1_axi_bready,
    input  wire [ADDR_WIDTH-1:0]   m1_axi_araddr,
    input  wire [2:0]              m1_axi_arprot,
    input  wire                    m1_axi_arvalid,
    output reg                     m1_axi_arready,
    output reg  [DATA_WIDTH-1:0]   m1_axi_rdata,
    output reg  [1:0]              m1_axi_rresp,
    output reg                     m1_axi_rvalid,
    input  wire                    m1_axi_rready,

    output reg  [ADDR_WIDTH-1:0]   s_axi_awaddr,
    output reg  [2:0]              s_axi_awprot,
    output reg                     s_axi_awvalid,
    input  wire                    s_axi_awready,
    output reg  [DATA_WIDTH-1:0]   s_axi_wdata,
    output reg  [3:0]              s_axi_wstrb,
    output reg                     s_axi_wvalid,
    input  wire                    s_axi_wready,
    input  wire [1:0]              s_axi_bresp,
    input  wire                    s_axi_bvalid,
    output reg                     s_axi_bready,
    output reg  [ADDR_WIDTH-1:0]   s_axi_araddr,
    output reg  [2:0]              s_axi_arprot,
    output reg                     s_axi_arvalid,
    input  wire                    s_axi_arready,
    input  wire [DATA_WIDTH-1:0]   s_axi_rdata,
    input  wire [1:0]              s_axi_rresp,
    input  wire                    s_axi_rvalid,
    output reg                     s_axi_rready
);

    localparam ST_IDLE  = 3'd0;
    localparam ST_M0_RD = 3'd1;
    localparam ST_M0_WR = 3'd2;
    localparam ST_M1_RD = 3'd3;
    localparam ST_M1_WR = 3'd4;

    reg [2:0] state;
    reg       last_master;

    wire m0_req = m0_axi_arvalid || m0_axi_awvalid;
    wire m1_req = m1_axi_arvalid || m1_axi_awvalid;

    reg [2:0] next_grant;
    always @(*) begin
        next_grant = ST_IDLE;
        if (last_master == 1'b0) begin
            // Give M1 priority if both request
            if (m1_req)
                next_grant = m1_axi_awvalid ? ST_M1_WR : ST_M1_RD;
            else if (m0_req)
                next_grant = m0_axi_awvalid ? ST_M0_WR : ST_M0_RD;
        end else begin
            // Give M0 priority if both request
            if (m0_req)
                next_grant = m0_axi_awvalid ? ST_M0_WR : ST_M0_RD;
            else if (m1_req)
                next_grant = m1_axi_awvalid ? ST_M1_WR : ST_M1_RD;
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state       <= ST_IDLE;
            last_master <= 1'b1;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (next_grant != ST_IDLE) begin
                        state <= next_grant;
                        if (next_grant == ST_M0_RD || next_grant == ST_M0_WR)
                            last_master <= 1'b0;
                        else
                            last_master <= 1'b1;
                    end
                end
                ST_M0_RD: if (s_axi_rvalid && m0_axi_rready) state <= ST_IDLE;
                ST_M0_WR: if (s_axi_bvalid && m0_axi_bready) state <= ST_IDLE;
                ST_M1_RD: if (s_axi_rvalid && m1_axi_rready) state <= ST_IDLE;
                ST_M1_WR: if (s_axi_bvalid && m1_axi_bready) state <= ST_IDLE;
                default:  state <= ST_IDLE;
            endcase
        end
    end

    // Track whether AW/W were already accepted in the current write burst so
    // late assertions are ignored if master dropped valid after ready
    reg aw_done_r, w_done_r;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            aw_done_r <= 1'b0;
            w_done_r  <= 1'b0;
        end else if (state != ST_M0_WR && state != ST_M1_WR) begin
            aw_done_r <= 1'b0;
            w_done_r  <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) aw_done_r <= 1'b1;
            if (s_axi_wvalid  && s_axi_wready)  w_done_r  <= 1'b1;
            if ((state == ST_M0_WR && s_axi_bvalid && m0_axi_bready) ||
                (state == ST_M1_WR && s_axi_bvalid && m1_axi_bready)) begin
                aw_done_r <= 1'b0;
                w_done_r  <= 1'b0;
            end
        end
    end

    always @(*) begin
        m0_axi_awready = 1'b0; m0_axi_wready = 1'b0; m0_axi_bvalid = 1'b0; m0_axi_bresp = 2'b00;
        m0_axi_arready = 1'b0; m0_axi_rvalid = 1'b0; m0_axi_rdata = 32'd0; m0_axi_rresp = 2'b00;

        m1_axi_awready = 1'b0; m1_axi_wready = 1'b0; m1_axi_bvalid = 1'b0; m1_axi_bresp = 2'b00;
        m1_axi_arready = 1'b0; m1_axi_rvalid = 1'b0; m1_axi_rdata = 32'd0; m1_axi_rresp = 2'b00;

        s_axi_awaddr  = {ADDR_WIDTH{1'b0}}; s_axi_awprot = 3'b000; s_axi_awvalid = 1'b0;
        s_axi_wdata   = {DATA_WIDTH{1'b0}}; s_axi_wstrb  = 4'b0000; s_axi_wvalid = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = {ADDR_WIDTH{1'b0}}; s_axi_arprot = 3'b000; s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        case (state)
            ST_M0_RD: begin
                s_axi_araddr   = m0_axi_araddr;
                s_axi_arprot   = m0_axi_arprot;
                s_axi_arvalid  = m0_axi_arvalid;
                m0_axi_arready = s_axi_arready;
                m0_axi_rdata   = s_axi_rdata;
                m0_axi_rresp   = s_axi_rresp;
                m0_axi_rvalid  = s_axi_rvalid;
                s_axi_rready   = m0_axi_rready;
            end
            ST_M0_WR: begin
                s_axi_awaddr   = m0_axi_awaddr;
                s_axi_awprot   = m0_axi_awprot;
                s_axi_awvalid  = m0_axi_awvalid && !aw_done_r;
                m0_axi_awready = s_axi_awready && !aw_done_r;
                s_axi_wdata    = m0_axi_wdata;
                s_axi_wstrb    = m0_axi_wstrb;
                s_axi_wvalid   = m0_axi_wvalid && !w_done_r;
                m0_axi_wready  = s_axi_wready && !w_done_r;
                m0_axi_bresp   = s_axi_bresp;
                m0_axi_bvalid  = s_axi_bvalid;
                s_axi_bready   = m0_axi_bready;
            end
            ST_M1_RD: begin
                s_axi_araddr   = m1_axi_araddr;
                s_axi_arprot   = m1_axi_arprot;
                s_axi_arvalid  = m1_axi_arvalid;
                m1_axi_arready = s_axi_arready;
                m1_axi_rdata   = s_axi_rdata;
                m1_axi_rresp   = s_axi_rresp;
                m1_axi_rvalid  = s_axi_rvalid;
                s_axi_rready   = m1_axi_rready;
            end
            ST_M1_WR: begin
                s_axi_awaddr   = m1_axi_awaddr;
                s_axi_awprot   = m1_axi_awprot;
                s_axi_awvalid  = m1_axi_awvalid && !aw_done_r;
                m1_axi_awready = s_axi_awready && !aw_done_r;
                s_axi_wdata    = m1_axi_wdata;
                s_axi_wstrb    = m1_axi_wstrb;
                s_axi_wvalid   = m1_axi_wvalid && !w_done_r;
                m1_axi_wready  = s_axi_wready && !w_done_r;
                m1_axi_bresp   = s_axi_bresp;
                m1_axi_bvalid  = s_axi_bvalid;
                s_axi_bready   = m1_axi_bready;
            end
            default: ;
        endcase
    end

endmodule
