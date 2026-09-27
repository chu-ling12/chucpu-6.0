`include "OpCode.vh"
`include "ALUOp.vh"
`include "MEMOp.vh"

// ID is the first decode stage. Operand selection and branch resolution live in ID2.
module ID(
  input wire validIn,
  input wire [31:0] pc,
  input wire [31:0] instr,
  output wire validOut,
  output wire [31:0] pcOut,
  output wire src1Enable,
  output wire [4:0] src1Reg,
  output wire src2Enable,
  output wire [4:0] src2Reg,
  output wire writeEnable,
  output wire [4:0] writeReg,
  output wire [31:0] writeData,
  output wire [1:0] op1Sel,
  output wire [1:0] op2Sel,
  output wire [31:0] immediate,
  output wire [7:0] aluOp,
  output wire [1:0] aluDst,
  output wire [7:0] memOp,
  output wire [2:0] branchType,
  output wire [2:0] specialOp,
  output wire [13:0] csrNum
);

  ID1 u_decode(
    .validIn(validIn),
    .pc(pc),
    .instr(instr),
    .validOut(validOut),
    .pcOut(pcOut),
    .src1Enable(src1Enable),
    .src1Reg(src1Reg),
    .src2Enable(src2Enable),
    .src2Reg(src2Reg),
    .writeEnable(writeEnable),
    .writeReg(writeReg),
    .writeData(writeData),
    .op1Sel(op1Sel),
    .op2Sel(op2Sel),
    .immediate(immediate),
    .aluOp(aluOp),
    .aluDst(aluDst),
    .memOp(memOp),
    .branchType(branchType),
    .specialOp(specialOp),
    .csrNum(csrNum)
  );

endmodule
