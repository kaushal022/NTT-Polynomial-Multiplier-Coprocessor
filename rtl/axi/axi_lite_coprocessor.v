`timescale 1ns / 1ps
module axi_lite_coprocessor #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)(
    input  wire                                clk,
    input  wire                                rst_n,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  wire [2:0]                          s_axi_awprot,
    input  wire                                s_axi_awvalid,
    output reg                                 s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   s_axi_wstrb,
    input  wire                                s_axi_wvalid,
    output reg                                 s_axi_wready,

    output reg  [1:0]                          s_axi_bresp,
    output reg                                 s_axi_bvalid,
    input  wire                                s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  wire [2:0]                          s_axi_arprot,
    input  wire                                s_axi_arvalid,
    output reg                                 s_axi_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output reg  [1:0]                          s_axi_rresp,
    output reg                                 s_axi_rvalid,
    input  wire                                s_axi_rready,

    output reg                                 core_start,
    input  wire                                core_done,
    input  wire                                core_busy,
    input  wire [15:0]                         core_cycle_count,

    output reg                                 core_ext_wen_f,
    output reg                                 core_ext_wen_g,
    output reg  [7:0]                          core_ext_addr,
    output reg  [11:0]                         core_ext_wdata_f,
    output reg  [11:0]                         core_ext_wdata_g,

    output reg                                 core_ext_ren,
    output reg  [7:0]                          core_ext_raddr,
    input  wire [11:0]                         core_ext_rdata,

    output wire                                irq
);

    localparam ADDR_CONTROL   = 6'h00;
    localparam ADDR_STATUS    = 6'h04;
    localparam ADDR_CYCLES    = 6'h08;
    localparam ADDR_ADDR_PTR  = 6'h0C;
    localparam ADDR_COEFF_F   = 6'h10;
    localparam ADDR_COEFF_G   = 6'h14;
    localparam ADDR_COEFF_OUT = 6'h18;
    localparam ADDR_VERSION   = 6'h1C;

    localparam [31:0] COPROC_VERSION_ID = 32'h4D4C4B31;

    reg        reg_ie;
    reg        reg_done_latched;
    reg [7:0]  reg_addr_ptr;
    reg        read_inc_ptr;

    assign irq = reg_ie & reg_done_latched;

    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_latched;
    reg                          aw_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready      <= 1'b0;
            s_axi_wready       <= 1'b0;
            s_axi_bvalid       <= 1'b0;
            s_axi_bresp        <= 2'b00;
            aw_en              <= 1'b1;
            axi_awaddr_latched <= {C_S_AXI_ADDR_WIDTH{1'b0}};

            core_start         <= 1'b0;
            reg_ie             <= 1'b0;
            reg_done_latched   <= 1'b0;
            reg_addr_ptr       <= 8'd0;
            core_ext_wen_f     <= 1'b0;
            core_ext_wen_g     <= 1'b0;
            core_ext_addr      <= 8'd0;
            core_ext_wdata_f   <= 12'd0;
            core_ext_wdata_g   <= 12'd0;
        end else begin
            core_start     <= 1'b0;
            core_ext_wen_f <= 1'b0;
            core_ext_wen_g <= 1'b0;

            if (core_done)
                reg_done_latched <= 1'b1;

            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready      <= 1'b1;
                aw_en              <= 1'b0;
                axi_awaddr_latched <= s_axi_awaddr;
            end else begin
                s_axi_awready <= 1'b0;
            end

            if (!s_axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en) begin
                s_axi_wready <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end

            if (s_axi_awready && s_axi_wready) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;

                case (axi_awaddr_latched[5:0])
                    ADDR_CONTROL: begin
                        if (s_axi_wdata[0]) begin
                            core_start       <= 1'b1;
                            reg_done_latched <= 1'b0;
                        end
                        reg_ie <= s_axi_wdata[1];
                        if (s_axi_wdata[2]) begin
                            reg_done_latched <= 1'b0;
                            reg_addr_ptr     <= 8'd0;
                        end
                    end

                    ADDR_STATUS: begin
                        if (s_axi_wdata[1])
                            reg_done_latched <= 1'b0;
                    end

                    ADDR_ADDR_PTR: begin
                        reg_addr_ptr <= s_axi_wdata[7:0];
                    end

                    ADDR_COEFF_F: begin
                        core_ext_wen_f   <= 1'b1;
                        core_ext_addr    <= reg_addr_ptr;
                        core_ext_wdata_f <= s_axi_wdata[11:0];
                        reg_addr_ptr     <= reg_addr_ptr + 8'd1;
                    end

                    ADDR_COEFF_G: begin
                        core_ext_wen_g   <= 1'b1;
                        core_ext_addr    <= reg_addr_ptr;
                        core_ext_wdata_g <= s_axi_wdata[11:0];
                        reg_addr_ptr     <= reg_addr_ptr + 8'd1;
                    end

                    default: ;
                endcase
            end else if (read_inc_ptr) begin
                reg_addr_ptr <= reg_addr_ptr + 8'd1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                aw_en        <= 1'b1;
            end
        end
    end

    localparam R_IDLE      = 3'd0;
    localparam R_WAIT_1    = 3'd1;
    localparam R_WAIT_2    = 3'd2;
    localparam R_DATA_REG  = 3'd3;
    localparam R_DATA_BRAM = 4'd4;
    localparam R_RESP      = 3'd5;

    reg [2:0]                    r_state;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state            <= R_IDLE;
            s_axi_arready      <= 1'b0;
            s_axi_rvalid       <= 1'b0;
            s_axi_rresp        <= 2'b00;
            s_axi_rdata        <= 32'd0;
            core_ext_ren       <= 1'b0;
            core_ext_raddr     <= 8'd0;
            axi_araddr_latched <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            read_inc_ptr       <= 1'b0;
        end else begin
            core_ext_ren <= 1'b0;
            read_inc_ptr <= 1'b0;

            case (r_state)
                R_IDLE: begin
                    if (s_axi_arvalid && !s_axi_rvalid) begin
                        s_axi_arready      <= 1'b1;
                        axi_araddr_latched <= s_axi_araddr;

                        if (s_axi_araddr[5:0] == ADDR_COEFF_OUT) begin
                            core_ext_ren   <= 1'b1;
                            core_ext_raddr <= reg_addr_ptr;
                            r_state        <= R_WAIT_1;
                        end else begin
                            r_state        <= R_DATA_REG;
                        end
                    end else begin
                        s_axi_arready <= 1'b0;
                    end
                end

                R_WAIT_1: begin
                    s_axi_arready <= 1'b0;
                    r_state <= R_WAIT_2;
                end

                R_WAIT_2: begin
                    r_state <= R_DATA_BRAM;
                end

                R_DATA_REG: begin
                    s_axi_arready <= 1'b0;
                    s_axi_rvalid  <= 1'b1;
                    s_axi_rresp   <= 2'b00;
                    case (axi_araddr_latched[5:0])
                        ADDR_CONTROL:  s_axi_rdata <= {30'd0, reg_ie, 1'b0};
                        ADDR_STATUS:   s_axi_rdata <= {29'd0, reg_done_latched, reg_done_latched, core_busy};
                        ADDR_CYCLES:   s_axi_rdata <= {16'd0, core_cycle_count};
                        ADDR_ADDR_PTR: s_axi_rdata <= {24'd0, reg_addr_ptr};
                        ADDR_VERSION:  s_axi_rdata <= COPROC_VERSION_ID;
                        default:       s_axi_rdata <= 32'hDEADBEEF;
                    endcase
                    r_state <= R_RESP;
                end

                R_DATA_BRAM: begin
                    s_axi_arready <= 1'b0;
                    s_axi_rvalid  <= 1'b1;
                    s_axi_rresp   <= 2'b00;
                    s_axi_rdata   <= {20'd0, core_ext_rdata};
                    r_state <= R_RESP;
                end

                R_RESP: begin
                    s_axi_arready <= 1'b0;
                    if (s_axi_rready && s_axi_rvalid) begin
                        s_axi_rvalid <= 1'b0;
                        if (axi_araddr_latched[5:0] == ADDR_COEFF_OUT) begin
                            read_inc_ptr <= 1'b1;
                        end
                        r_state <= R_IDLE;
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

endmodule
