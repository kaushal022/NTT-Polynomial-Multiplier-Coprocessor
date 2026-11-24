`timescale 1ns / 1ps

module axi_mailbox #(
    parameter integer ADDR_WIDTH = 12,
    parameter integer DATA_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    resetn,

    input  wire [ADDR_WIDTH-1:0]   s0_axi_awaddr,
    input  wire [2:0]              s0_axi_awprot,
    input  wire                    s0_axi_awvalid,
    output wire                    s0_axi_awready,
    input  wire [DATA_WIDTH-1:0]   s0_axi_wdata,
    input  wire [3:0]              s0_axi_wstrb,
    input  wire                    s0_axi_wvalid,
    output wire                    s0_axi_wready,
    output wire [1:0]              s0_axi_bresp,
    output wire                    s0_axi_bvalid,
    input  wire                    s0_axi_bready,
    input  wire [ADDR_WIDTH-1:0]   s0_axi_araddr,
    input  wire [2:0]              s0_axi_arprot,
    input  wire                    s0_axi_arvalid,
    output wire                    s0_axi_arready,
    output wire [DATA_WIDTH-1:0]   s0_axi_rdata,
    output wire [1:0]              s0_axi_rresp,
    output wire                    s0_axi_rvalid,
    input  wire                    s0_axi_rready,

    input  wire [ADDR_WIDTH-1:0]   s1_axi_awaddr,
    input  wire [2:0]              s1_axi_awprot,
    input  wire                    s1_axi_awvalid,
    output wire                    s1_axi_awready,
    input  wire [DATA_WIDTH-1:0]   s1_axi_wdata,
    input  wire [3:0]              s1_axi_wstrb,
    input  wire                    s1_axi_wvalid,
    output wire                    s1_axi_wready,
    output wire [1:0]              s1_axi_bresp,
    output wire                    s1_axi_bvalid,
    input  wire                    s1_axi_bready,
    input  wire [ADDR_WIDTH-1:0]   s1_axi_araddr,
    input  wire [2:0]              s1_axi_arprot,
    input  wire                    s1_axi_arvalid,
    output wire                    s1_axi_arready,
    output wire [DATA_WIDTH-1:0]   s1_axi_rdata,
    output wire [1:0]              s1_axi_rresp,
    output wire                    s1_axi_rvalid,
    input  wire                    s1_axi_rready,

    output wire                    req_pending_o,
    output wire                    resp_ready_o,
    output wire                    rv_running_o
);

    localparam [31:0] MB_MAGIC_VAL = 32'h4D4C_4B4D;

    (* ram_style = "block" *) reg [31:0] shared_mem [0:1023];

    integer init_i;
    initial begin
        for (init_i = 0; init_i < 1024; init_i = init_i + 1)
            shared_mem[init_i] = 32'd0;
    end

    reg        reg_req_pending;
    reg        reg_cmd_uart_ok;
    reg [15:0] reg_seq_id;
    reg [31:0] reg_resp_status;
    reg [31:0] reg_cycles;
    reg [31:0] reg_heartbeat;

    assign req_pending_o = reg_req_pending;
    assign resp_ready_o  = reg_resp_status[0];
    assign rv_running_o  = reg_resp_status[1];

    reg [ADDR_WIDTH-1:0] p0_waddr_r;
    reg [31:0]           p0_wdata_r;
    reg [3:0]            p0_wstrb_r;
    reg                  p0_aw_done, p0_w_done, p0_bvalid_r;

    assign s0_axi_awready = !p0_aw_done && !p0_bvalid_r;
    assign s0_axi_wready  = !p0_w_done  && !p0_bvalid_r;
    assign s0_axi_bresp   = 2'b00;
    assign s0_axi_bvalid  = p0_bvalid_r;

    wire p0_aw_fire = s0_axi_awvalid && s0_axi_awready;
    wire p0_w_fire  = s0_axi_wvalid  && s0_axi_wready;
    wire [9:0]  p0_eff_widx  = p0_aw_fire ? s0_axi_awaddr[11:2] : p0_waddr_r[11:2];
    wire [31:0] p0_eff_wdata = p0_w_fire  ? s0_axi_wdata        : p0_wdata_r;
    wire [3:0]  p0_eff_wstrb = p0_w_fire  ? s0_axi_wstrb        : p0_wstrb_r;
    wire p0_do_wr   = (p0_aw_fire || p0_aw_done) && (p0_w_fire || p0_w_done) && !p0_bvalid_r;
    wire p0_wr_mem  = p0_do_wr && (p0_eff_widx >= 10'd64);

    reg [ADDR_WIDTH-1:0] p1_waddr_r;
    reg [31:0]           p1_wdata_r;
    reg [3:0]            p1_wstrb_r;
    reg                  p1_aw_done, p1_w_done, p1_bvalid_r;

    assign s1_axi_awready = !p1_aw_done && !p1_bvalid_r;
    assign s1_axi_wready  = !p1_w_done  && !p1_bvalid_r;
    assign s1_axi_bresp   = 2'b00;
    assign s1_axi_bvalid  = p1_bvalid_r;

    wire p1_aw_fire = s1_axi_awvalid && s1_axi_awready;
    wire p1_w_fire  = s1_axi_wvalid  && s1_axi_wready;
    wire [9:0]  p1_eff_widx  = p1_aw_fire ? s1_axi_awaddr[11:2] : p1_waddr_r[11:2];
    wire [31:0] p1_eff_wdata = p1_w_fire  ? s1_axi_wdata        : p1_wdata_r;
    wire [3:0]  p1_eff_wstrb = p1_w_fire  ? s1_axi_wstrb        : p1_wstrb_r;
    wire p1_do_wr   = (p1_aw_fire || p1_aw_done) && (p1_w_fire || p1_w_done) && !p1_bvalid_r;
    wire p1_wr_mem  = p1_do_wr && (p1_eff_widx >= 10'd64);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            p0_aw_done      <= 1'b0;
            p0_w_done       <= 1'b0;
            p0_bvalid_r     <= 1'b0;
            p0_waddr_r      <= {ADDR_WIDTH{1'b0}};
            p0_wdata_r      <= 32'd0;
            p0_wstrb_r      <= 4'd0;

            p1_aw_done      <= 1'b0;
            p1_w_done       <= 1'b0;
            p1_bvalid_r     <= 1'b0;
            p1_waddr_r      <= {ADDR_WIDTH{1'b0}};
            p1_wdata_r      <= 32'd0;
            p1_wstrb_r      <= 4'd0;

            reg_req_pending <= 1'b0;
            reg_cmd_uart_ok <= 1'b0;
            reg_seq_id      <= 16'd0;
            reg_resp_status <= 32'd0;
            reg_cycles      <= 32'd0;
            reg_heartbeat   <= 32'd0;
        end else begin
            if (p0_aw_fire) begin
                p0_waddr_r <= s0_axi_awaddr;
                p0_aw_done <= 1'b1;
            end
            if (p0_w_fire) begin
                p0_wdata_r <= s0_axi_wdata;
                p0_wstrb_r <= s0_axi_wstrb;
                p0_w_done  <= 1'b1;
            end
            if (p0_do_wr) begin
                p0_bvalid_r <= 1'b1;
                p0_aw_done  <= 1'b0;
                p0_w_done   <= 1'b0;
                if (p0_eff_widx < 10'd64) begin
                    case (p0_eff_widx[3:0])
                        4'd1: begin
                            reg_req_pending <= p0_eff_wdata[0];
                            reg_cmd_uart_ok <= p0_eff_wdata[1];
                            reg_seq_id      <= p0_eff_wdata[31:16];
                        end
                        4'd2: begin
                            reg_resp_status[0] <= p0_eff_wdata[0];
                        end
                        default: ;
                    endcase
                end
            end else if (p0_bvalid_r && s0_axi_bready) begin
                p0_bvalid_r <= 1'b0;
            end

            if (p1_aw_fire) begin
                p1_waddr_r <= s1_axi_awaddr;
                p1_aw_done <= 1'b1;
            end
            if (p1_w_fire) begin
                p1_wdata_r <= s1_axi_wdata;
                p1_wstrb_r <= s1_axi_wstrb;
                p1_w_done  <= 1'b1;
            end
            if (p1_do_wr) begin
                p1_bvalid_r <= 1'b1;
                p1_aw_done  <= 1'b0;
                p1_w_done   <= 1'b0;
                if (p1_eff_widx < 10'd64) begin
                    case (p1_eff_widx[3:0])
                        4'd2:    reg_resp_status <= p1_eff_wdata;
                        4'd3:    reg_cycles      <= p1_eff_wdata;
                        4'd4:    reg_heartbeat   <= p1_eff_wdata;
                        4'd5:    if (p1_eff_wdata[0]) reg_req_pending <= 1'b0;
                        default: ;
                    endcase
                end
            end else if (p1_bvalid_r && s1_axi_bready) begin
                p1_bvalid_r <= 1'b0;
            end
        end
    end

    reg [31:0] p0_mem_rdata_r, p1_mem_rdata_r;
    reg [31:0] p0_reg_rdata_r, p1_reg_rdata_r;
    reg        p0_rd_is_mem_r, p1_rd_is_mem_r;
    reg        p0_rvalid_r,    p1_rvalid_r;

    wire [9:0] p0_ram_addr = p0_wr_mem ? p0_eff_widx : s0_axi_araddr[11:2];
    wire [3:0] p0_ram_we   = p0_wr_mem ? p0_eff_wstrb : 4'b0000;
    wire       p0_ram_en   = p0_wr_mem || (s0_axi_arvalid && s0_axi_arready);

    wire [9:0] p1_ram_addr = p1_wr_mem ? p1_eff_widx : s1_axi_araddr[11:2];
    wire [3:0] p1_ram_we   = p1_wr_mem ? p1_eff_wstrb : 4'b0000;
    wire       p1_ram_en   = p1_wr_mem || (s1_axi_arvalid && s1_axi_arready);

    integer bi;
    always @(posedge clk) begin
        if (p0_ram_en) begin
            p0_mem_rdata_r <= shared_mem[p0_ram_addr];
            for (bi = 0; bi < 4; bi = bi + 1) begin
                if (p0_ram_we[bi])
                    shared_mem[p0_ram_addr][bi*8 +: 8] <= p0_eff_wdata[bi*8 +: 8];
            end
        end
    end

    integer bj;
    always @(posedge clk) begin
        if (p1_ram_en) begin
            p1_mem_rdata_r <= shared_mem[p1_ram_addr];
            for (bj = 0; bj < 4; bj = bj + 1) begin
                if (p1_ram_we[bj])
                    shared_mem[p1_ram_addr][bj*8 +: 8] <= p1_eff_wdata[bj*8 +: 8];
            end
        end
    end

    assign s0_axi_arready = !p0_rvalid_r && !p0_wr_mem;
    assign s0_axi_rdata   = p0_rd_is_mem_r ? p0_mem_rdata_r : p0_reg_rdata_r;
    assign s0_axi_rresp   = 2'b00;
    assign s0_axi_rvalid  = p0_rvalid_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            p0_rvalid_r    <= 1'b0;
            p0_rd_is_mem_r <= 1'b0;
            p0_reg_rdata_r <= 32'd0;
        end else begin
            if (s0_axi_arvalid && s0_axi_arready) begin
                p0_rd_is_mem_r <= (s0_axi_araddr[11:2] >= 10'd64);
                case (s0_axi_araddr[5:2])
                    4'd0:    p0_reg_rdata_r <= MB_MAGIC_VAL;
                    4'd1:    p0_reg_rdata_r <= {reg_seq_id, 14'd0, reg_cmd_uart_ok, reg_req_pending};
                    4'd2:    p0_reg_rdata_r <= reg_resp_status;
                    4'd3:    p0_reg_rdata_r <= reg_cycles;
                    4'd4:    p0_reg_rdata_r <= reg_heartbeat;
                    default: p0_reg_rdata_r <= 32'd0;
                endcase
                p0_rvalid_r <= 1'b1;
            end else if (p0_rvalid_r && s0_axi_rready) begin
                p0_rvalid_r <= 1'b0;
            end
        end
    end

    assign s1_axi_arready = !p1_rvalid_r && !p1_wr_mem;
    assign s1_axi_rdata   = p1_rd_is_mem_r ? p1_mem_rdata_r : p1_reg_rdata_r;
    assign s1_axi_rresp   = 2'b00;
    assign s1_axi_rvalid  = p1_rvalid_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            p1_rvalid_r    <= 1'b0;
            p1_rd_is_mem_r <= 1'b0;
            p1_reg_rdata_r <= 32'd0;
        end else begin
            if (s1_axi_arvalid && s1_axi_arready) begin
                p1_rd_is_mem_r <= (s1_axi_araddr[11:2] >= 10'd64);
                case (s1_axi_araddr[5:2])
                    4'd0:    p1_reg_rdata_r <= MB_MAGIC_VAL;
                    4'd1:    p1_reg_rdata_r <= {reg_seq_id, 14'd0, reg_cmd_uart_ok, reg_req_pending};
                    4'd2:    p1_reg_rdata_r <= reg_resp_status;
                    4'd3:    p1_reg_rdata_r <= reg_cycles;
                    4'd4:    p1_reg_rdata_r <= reg_heartbeat;
                    default: p1_reg_rdata_r <= 32'd0;
                endcase
                p1_rvalid_r <= 1'b1;
            end else if (p1_rvalid_r && s1_axi_rready) begin
                p1_rvalid_r <= 1'b0;
            end
        end
    end

endmodule
