`timescale 1ns/1ps

// Active-high external reset conditioner for the single 50 MHz domain.
// Assertion is asynchronous. Deassertion shifts through STAGES rising edges,
// so every downstream module observes a common, synchronously released reset.
module reset_conditioner #(
    parameter integer STAGES = 3
) (
    input  wire clk,
    input  wire arst_p,
    output wire rst
);
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [STAGES-1:0] sync_ff;

    initial begin
        if (STAGES < 2)
            $error("reset_conditioner requires at least two stages");
    end

    always @(posedge clk or posedge arst_p) begin
        if (arst_p)
            sync_ff <= {STAGES{1'b1}};
        else
            sync_ff <= {sync_ff[STAGES-2:0], 1'b0};
    end

    assign rst = sync_ff[STAGES-1];
endmodule
