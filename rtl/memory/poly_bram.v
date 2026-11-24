`timescale 1ns / 1ps

module poly_bram (
    input  wire        clk,

    input  wire        ena,
    input  wire        wea,
    input  wire [7:0]  addra,
    input  wire [11:0] dina,
    output reg  [11:0] douta,

    input  wire        enb,
    input  wire        web,
    input  wire [7:0]  addrb,
    input  wire [11:0] dinb,
    output reg  [11:0] doutb
);

    (* ram_style = "block" *) reg [11:0] mem [0:255];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 12'd0;
    end

    always @(posedge clk) begin
        if (ena) begin
            if (wea) begin
                mem[addra] <= dina;
                douta <= dina;
            end else begin
                douta <= mem[addra];
            end
        end
    end

    always @(posedge clk) begin
        if (enb) begin
            if (web) begin
                mem[addrb] <= dinb;
                doutb <= dinb;
            end else begin
                doutb <= mem[addrb];
            end
        end
    end

endmodule
