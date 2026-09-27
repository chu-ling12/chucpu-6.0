`include "ALUOp.vh"

module ALU(
  input wire clk,
  input wire rst,
  input wire [31:0] busA,
  input wire [31:0] busB,
  input wire [7:0] aluOp,
  output reg [31:0] aluOut,
  output wire mulStall
);

  reg [31:0] mulResult;
  reg mulReady;

  assign mulStall = (aluOp == `ALU_MUL) && !mulReady;

  // Register the DSP result before it enters forwarding and branch logic.
  always @(posedge clk) begin
    if (rst) begin
      mulResult <= 32'h0;
      mulReady <= 1'b0;
    end else if ((aluOp == `ALU_MUL) && !mulReady) begin
      mulResult <= busA * busB;
      mulReady <= 1'b1;
    end else begin
      mulReady <= 1'b0;
    end
  end

  always @(*) begin
    case (aluOp)
      `ALU_ADD: aluOut = busA + busB;
      `ALU_SUB: aluOut = busA - busB;
      `ALU_AND: aluOut = busA & busB;
      `ALU_OR : aluOut = busA | busB;
      `ALU_XOR: aluOut = busA ^ busB;
      `ALU_SLL: aluOut = busA << busB[4:0];
      `ALU_SRL: aluOut = busA >> busB[4:0];
      `ALU_SLT: aluOut = ($signed(busA) < $signed(busB)) ? 32'h1 : 32'h0;
      `ALU_MUL: aluOut = mulResult;
      default:  aluOut = 32'h0;
    endcase
  end

endmodule
