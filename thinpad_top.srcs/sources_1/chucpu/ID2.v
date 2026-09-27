`include "MEMOp.vh"

module ID2(
  input wire validIn,
  input wire [31:0] pc,
  input wire src1Enable,
  input wire [4:0] src1Reg,
  input wire [31:0] src1Data,
  input wire src2Enable,
  input wire [4:0] src2Reg,
  input wire [31:0] src2Data,
  input wire writeEnableIn,
  input wire [4:0] writeRegIn,
  input wire [31:0] writeDataIn,
  input wire [1:0] op1Sel,
  input wire [1:0] op2Sel,
  input wire [31:0] immediate,
  input wire [7:0] aluOpIn,
  input wire [1:0] aluDstIn,
  input wire [7:0] memOpIn,
  input wire [2:0] branchType,
  input wire [2:0] specialOp,
  input wire [13:0] csrNum,
  input wire [31:0] csrReadData,

  input wire writeEnableEX,
  input wire [4:0] writeRegEX,
  input wire [31:0] writeDataEX,
  input wire [7:0] memOpEX,
  input wire [31:0] memAddressEX,
  input wire writeEnableMEM,
  input wire [4:0] writeRegMEM,
  input wire [31:0] writeDataMEM,
  input wire [7:0] memOpMEM,
  input wire writeEnableMD,
  input wire [4:0] writeRegMD,
  input wire [31:0] writeDataMD,
  input wire [31:0] lastStoreAddress,
  input wire [31:0] lastStoreData,

  output wire readEnable1,
  output wire [4:0] readReg1,
  output wire readEnable2,
  output wire [4:0] readReg2,
  output wire writeEnableOut,
  output wire [4:0] writeRegOut,
  output wire [31:0] writeDataOut,
  output reg [31:0] busAOut,
  output reg [31:0] busBOut,
  output wire [31:0] memWriteDataOut,
  output wire [7:0] aluOpOut,
  output wire [1:0] aluDstOut,
  output wire [7:0] memOpOut,
  output reg csrWriteEnable,
  output reg [13:0] csrWriteAddr,
  output reg [31:0] csrWriteData,
  output reg cacopInvalidate,
  output reg [31:0] cacopAddress,
  output reg branch,
  output reg [31:0] branchAddress,
  output wire stallReq
);

  localparam OP1_SRC1 = 2'd1;
  localparam OP1_PC = 2'd2;
  localparam OP2_SRC2 = 2'd1;
  localparam OP2_IMM = 2'd2;
  localparam BR_JIRL = 3'd1;
  localparam BR_B = 3'd2;
  localparam BR_BEQ = 3'd3;
  localparam BR_BNE = 3'd4;
  localparam BR_BLTU = 3'd5;
  localparam SPECIAL_CPUCFG = 3'd1;
  localparam SPECIAL_CSRRD = 3'd2;
  localparam SPECIAL_CSRWR = 3'd3;
  localparam SPECIAL_CSRXCHG = 3'd4;
  localparam SPECIAL_CACOP = 3'd5;

  wire lastInstrLoad = (memOpEX == `MEM_LW) || (memOpEX == `MEM_LB);
  wire memInstrLoad = (memOpMEM == `MEM_LW) || (memOpMEM == `MEM_LB);
  wire [31:0] operand1Raw;
  wire [31:0] operand2Raw;
  wire [31:0] operand1 = src1Enable ? operand1Raw : 32'h0;
  wire [31:0] operand2 = src2Enable ? operand2Raw : 32'h0;
  wire stall1;
  wire stall2;

  assign readEnable1 = validIn && src1Enable;
  assign readReg1 = src1Reg;
  assign readEnable2 = validIn && src2Enable;
  assign readReg2 = src2Reg;

  ForwardingUnit u_forward_src1(
    .readReg(src1Reg),
    .readData(src1Data),
    .lastInstrLoad(lastInstrLoad),
    .memInstrLoad(memInstrLoad),
    .lastInstrStore(lastStoreAddress == memAddressEX),
    .writeRegEX(writeRegEX),
    .writeDataEX(writeDataEX),
    .writeEnableEX(writeEnableEX),
    .writeRegMEM(writeRegMEM),
    .writeDataMEM(writeDataMEM),
    .writeEnableMEM(writeEnableMEM),
    .writeRegMD(writeRegMD),
    .writeDataMD(writeDataMD),
    .writeEnableMD(writeEnableMD),
    .memAddressEX(memAddressEX),
    .lastStoreAddress(lastStoreAddress),
    .lastStoreData(lastStoreData),
    .result(operand1Raw),
    .stallReq(stall1)
  );

  ForwardingUnit u_forward_src2(
    .readReg(src2Reg),
    .readData(src2Data),
    .lastInstrLoad(lastInstrLoad),
    .memInstrLoad(memInstrLoad),
    .lastInstrStore(lastStoreAddress == memAddressEX),
    .writeRegEX(writeRegEX),
    .writeDataEX(writeDataEX),
    .writeEnableEX(writeEnableEX),
    .writeRegMEM(writeRegMEM),
    .writeDataMEM(writeDataMEM),
    .writeEnableMEM(writeEnableMEM),
    .writeRegMD(writeRegMD),
    .writeDataMD(writeDataMD),
    .writeEnableMD(writeEnableMD),
    .memAddressEX(memAddressEX),
    .lastStoreAddress(lastStoreAddress),
    .lastStoreData(lastStoreData),
    .result(operand2Raw),
    .stallReq(stall2)
  );

  assign stallReq = validIn && ((src1Enable && stall1) || (src2Enable && stall2));
  assign writeEnableOut = validIn && writeEnableIn;
  assign writeRegOut = writeRegIn;
  function [31:0] cpucfg_data;
    input [31:0] index;
    begin
      case (index)
        32'h00000010: cpucfg_data = 32'h00000001;
        // 2-word lines, 256 indices, direct mapped (max way = 0).
        32'h00000011: cpucfg_data = 32'h03080000;
        32'h00000012: cpucfg_data = 32'h00000000;
        default: cpucfg_data = 32'h00000000;
      endcase
    end
  endfunction

  assign writeDataOut = (specialOp == SPECIAL_CPUCFG) ? cpucfg_data(operand1) :
                        ((specialOp == SPECIAL_CSRRD) ||
                         (specialOp == SPECIAL_CSRWR) ||
                         (specialOp == SPECIAL_CSRXCHG)) ? csrReadData :
                        writeDataIn;
  assign memWriteDataOut = operand2;
  assign aluOpOut = aluOpIn;
  assign aluDstOut = validIn ? aluDstIn : 2'b00;
  assign memOpOut = validIn ? memOpIn : `MEM_NOP;

  always @(*) begin
    case (op1Sel)
      OP1_SRC1: busAOut = operand1;
      OP1_PC: busAOut = pc;
      default: busAOut = 32'h0;
    endcase
    case (op2Sel)
      OP2_SRC2: busBOut = operand2;
      OP2_IMM: busBOut = immediate;
      default: busBOut = 32'h0;
    endcase

    branch = 1'b0;
    branchAddress = 32'h0;
    csrWriteEnable = 1'b0;
    csrWriteAddr = csrNum;
    csrWriteData = 32'h00000000;
    cacopInvalidate = 1'b0;
    cacopAddress = operand1 + immediate;
    if (validIn && !stallReq) begin
      if (specialOp == SPECIAL_CSRWR) begin
        csrWriteEnable = 1'b1;
        csrWriteData = operand1;
      end else if (specialOp == SPECIAL_CSRXCHG) begin
        csrWriteEnable = 1'b1;
        csrWriteData = (csrReadData & ~operand2) | (operand1 & operand2);
      end else if (specialOp == SPECIAL_CACOP) begin
        cacopInvalidate = 1'b1;
      end
    end
    if (validIn && !stallReq) begin
      case (branchType)
        BR_JIRL: begin
          branch = 1'b1;
          branchAddress = operand1 + immediate;
        end
        BR_B: begin
          branch = 1'b1;
          branchAddress = pc + immediate;
        end
        BR_BEQ: begin
          branch = (operand1 == operand2);
          branchAddress = pc + immediate;
        end
        BR_BNE: begin
          branch = (operand1 != operand2);
          branchAddress = pc + immediate;
        end
        BR_BLTU: begin
          branch = ($unsigned(operand1) < $unsigned(operand2));
          branchAddress = pc + immediate;
        end
        default: begin
        end
      endcase
    end
  end

endmodule
