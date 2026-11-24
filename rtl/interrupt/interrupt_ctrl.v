`timescale 1ns / 1ps

module interrupt_ctrl (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        coproc_done_pulse,
    input  wire        dma_done_pulse,
    input  wire        error_pulse,

    input  wire [2:0]  ier,
    input  wire [2:0]  icr,
    output wire [2:0]  isr,

    output wire        irq_out
);

    reg [2:0] isr_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            isr_reg <= 3'b000;
        end else begin
            if (coproc_done_pulse) isr_reg[0] <= 1'b1;
            else if (icr[0])       isr_reg[0] <= 1'b0;

            if (dma_done_pulse)    isr_reg[1] <= 1'b1;
            else if (icr[1])       isr_reg[1] <= 1'b0;

            if (error_pulse)       isr_reg[2] <= 1'b1;
            else if (icr[2])       isr_reg[2] <= 1'b0;
        end
    end

    assign isr     = isr_reg;
    assign irq_out = |(isr_reg & ier);

endmodule
