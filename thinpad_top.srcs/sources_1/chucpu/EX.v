`include "ALUOp.vh"

module EX(
  input wire clk,
  input wire rst,

  input wire [1:0] aluDst,
  input wire [31:0] aluOut,
  input wire [31:0] memAddressIn,
  input wire [31:0] writeDataIn,
  output reg [31:0] writeDataOut,
  output reg [31:0] memAddress,

  // CSR 控制 (来自 ID_EX)
  input  wire        csrOp,
  input  wire [13:0] csrNum,

  // CSR 写接口 (到 CSR 模块)
  output reg         csrWe,
  output reg  [13:0] csrWAddr,
  output reg  [31:0] csrWData
);

  always @(*) begin
    csrWe    = 1'b0;
    csrWAddr = 14'h0;
    csrWData = 32'h0;

    case (aluDst)
      `DST_REG: begin
        writeDataOut = aluOut;
        memAddress = 32'h0;
      end
      `DST_MEM: begin
        writeDataOut = writeDataIn;
        memAddress = memAddressIn;
      end
      default: begin  // DST_NOP
        writeDataOut = writeDataIn;
        memAddress = 32'h0;

        // CSR 写 (csrwr / csrxchg)
        if (csrOp) begin
          csrWe    = 1'b1;
          csrWAddr = csrNum;
          csrWData = aluOut;
        end
      end
    endcase
  end

endmodule
