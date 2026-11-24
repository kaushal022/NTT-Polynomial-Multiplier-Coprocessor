`timescale 1ns / 1ps

module ntt_dma #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_DATA_WIDTH = 32
)(
    input  wire                      clk,
    input  wire                      rst_n,

    input  wire                      dma_start,
    input  wire                      dma_dir,
    input  wire [1:0]                dma_target,
    input  wire [AXI_ADDR_WIDTH-1:0] dma_mem_addr,
    output reg                       dma_done,
    output reg                       dma_busy,

    output reg  [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output reg                       m_axi_arvalid,
    input  wire                      m_axi_arready,

    input  wire [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  wire                      m_axi_rvalid,
    output reg                       m_axi_rready,

    output reg  [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg                       m_axi_awvalid,
    input  wire                      m_axi_awready,

    output reg  [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output reg                       m_axi_wvalid,
    input  wire                      m_axi_wready,

    input  wire                      m_axi_bvalid,
    output reg                       m_axi_bready,

    output reg                       coproc_wen,
    output reg  [7:0]                coproc_addr,
    output reg  [11:0]               coproc_wdata_f,
    output reg  [11:0]               coproc_wdata_g,

    output reg                       coproc_ren,
    output reg  [7:0]                coproc_raddr,
    input  wire [11:0]               coproc_rdata
);

    localparam DMA_IDLE        = 4'd0;
    localparam DMA_READ_REQ    = 4'd1;
    localparam DMA_READ_DATA   = 4'd2;
    localparam DMA_BRAM_WAIT1  = 4'd3;
    localparam DMA_BRAM_WAIT2  = 4'd4;
    localparam DMA_WRITE_REQ   = 4'd5;
    localparam DMA_WRITE_DATA  = 4'd6;
    localparam DMA_WRITE_RESP  = 4'd7;
    localparam DMA_DONE_ST     = 4'd8;

    reg [3:0] dma_state;
    reg [8:0] word_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_state      <= DMA_IDLE;
            dma_done       <= 1'b0;
            dma_busy       <= 1'b0;
            word_count     <= 9'd0;
            m_axi_araddr   <= {AXI_ADDR_WIDTH{1'b0}};
            m_axi_arvalid  <= 1'b0;
            m_axi_rready   <= 1'b0;
            m_axi_awaddr   <= {AXI_ADDR_WIDTH{1'b0}};
            m_axi_awvalid  <= 1'b0;
            m_axi_wdata    <= {AXI_DATA_WIDTH{1'b0}};
            m_axi_wvalid   <= 1'b0;
            m_axi_bready   <= 1'b0;
            coproc_wen     <= 1'b0;
            coproc_addr    <= 8'd0;
            coproc_wdata_f <= 12'd0;
            coproc_wdata_g <= 12'd0;
            coproc_ren     <= 1'b0;
            coproc_raddr   <= 8'd0;
        end else begin
            dma_done   <= 1'b0;
            coproc_wen <= 1'b0;
            coproc_ren <= 1'b0;

            case (dma_state)
                DMA_IDLE: begin
                    if (dma_start) begin
                        dma_busy   <= 1'b1;
                        word_count <= 9'd0;
                        if (!dma_dir) begin
                            m_axi_araddr  <= dma_mem_addr;
                            m_axi_arvalid <= 1'b1;
                            dma_state     <= DMA_READ_REQ;
                        end else begin
                            coproc_ren   <= 1'b1;
                            coproc_raddr <= 8'd0;
                            dma_state    <= DMA_BRAM_WAIT1;
                        end
                    end
                end

                DMA_READ_REQ: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        dma_state     <= DMA_READ_DATA;
                    end
                end

                DMA_READ_DATA: begin
                    if (m_axi_rvalid) begin
                        coproc_wen  <= 1'b1;
                        coproc_addr <= word_count[7:0];
                        if (dma_target == 2'd0)
                            coproc_wdata_f <= m_axi_rdata[11:0];
                        else
                            coproc_wdata_g <= m_axi_rdata[11:0];

                        m_axi_rready <= 1'b0;
                        if (word_count == 9'd255) begin
                            dma_state <= DMA_DONE_ST;
                        end else begin
                            word_count    <= word_count + 9'd1;
                            m_axi_araddr  <= m_axi_araddr + 32'd4;
                            m_axi_arvalid <= 1'b1;
                            dma_state     <= DMA_READ_REQ;
                        end
                    end
                end

                DMA_BRAM_WAIT1: begin
                    dma_state <= DMA_BRAM_WAIT2;
                end

                DMA_BRAM_WAIT2: begin
                    dma_state <= DMA_WRITE_REQ;
                end

                DMA_WRITE_REQ: begin
                    m_axi_awaddr  <= dma_mem_addr + {21'd0, word_count, 2'b00};
                    m_axi_awvalid <= 1'b1;
                    m_axi_wdata   <= {20'd0, coproc_rdata};
                    m_axi_wvalid  <= 1'b1;
                    dma_state     <= DMA_WRITE_DATA;
                end

                DMA_WRITE_DATA: begin
                    if (m_axi_awready)
                        m_axi_awvalid <= 1'b0;
                    if (m_axi_wready)
                        m_axi_wvalid <= 1'b0;

                    if ((!m_axi_awvalid || m_axi_awready) && (!m_axi_wvalid || m_axi_wready)) begin
                        m_axi_bready <= 1'b1;
                        dma_state    <= DMA_WRITE_RESP;
                    end
                end

                DMA_WRITE_RESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        if (word_count == 9'd255) begin
                            dma_state <= DMA_DONE_ST;
                        end else begin
                            word_count   <= word_count + 9'd1;
                            coproc_ren   <= 1'b1;
                            coproc_raddr <= word_count[7:0] + 8'd1;
                            dma_state    <= DMA_BRAM_WAIT1;
                        end
                    end
                end

                DMA_DONE_ST: begin
                    dma_done  <= 1'b1;
                    dma_busy  <= 1'b0;
                    dma_state <= DMA_IDLE;
                end

                default: dma_state <= DMA_IDLE;
            endcase
        end
    end

endmodule
