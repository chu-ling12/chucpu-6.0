`include "OpCode.vh"
`include "ALUOp.vh"
`include "MEMOp.vh"

module ID1(
  input wire validIn,
  input wire [31:0] pc,
  input wire [31:0] instr,

  output reg validOut,
  output reg [31:0] pcOut,
  output reg src1Enable,
  output reg [4:0] src1Reg,
  output reg src2Enable,
  output reg [4:0] src2Reg,
  output reg writeEnable,
  output reg [4:0] writeReg,
  output reg [31:0] writeData,
  output reg [1:0] op1Sel,
  output reg [1:0] op2Sel,
  output reg [31:0] immediate,
  output reg [7:0] aluOp,
  output reg [1:0] aluDst,
  output reg [7:0] memOp,
  output reg [2:0] branchType,
  output reg [2:0] specialOp,
  output reg [13:0] csrNum
);

  localparam OP1_ZERO = 2'd0;
  localparam OP1_SRC1 = 2'd1;
  localparam OP1_PC   = 2'd2;
  localparam OP2_ZERO = 2'd0;
  localparam OP2_SRC2 = 2'd1;
  localparam OP2_IMM  = 2'd2;

  localparam BR_NONE = 3'd0;
  localparam BR_JIRL = 3'd1;
  localparam BR_B    = 3'd2;
  localparam BR_BEQ  = 3'd3;
  localparam BR_BNE  = 3'd4;
  localparam BR_BLTU = 3'd5;
  localparam SPECIAL_NONE = 3'd0;
  localparam SPECIAL_CPUCFG = 3'd1;
  localparam SPECIAL_CSRRD = 3'd2;
  localparam SPECIAL_CSRWR = 3'd3;
  localparam SPECIAL_CSRXCHG = 3'd4;
  localparam SPECIAL_CACOP = 3'd5;

  wire [16:0] opcode17 = instr[31:15];
  wire [9:0] opcode10 = instr[31:22];
  wire [7:0] opcode8 = instr[31:24];
  wire [6:0] opcode7 = instr[31:25];
  wire [5:0] opcode6 = instr[31:26];
  wire [4:0] rk = instr[14:10];
  wire [4:0] rj = instr[9:5];
  wire [4:0] rd = instr[4:0];
  wire [31:0] signImm12 = {{20{instr[21]}}, instr[21:10]};
  wire [31:0] zeroImm12 = {20'h0, instr[21:10]};
  wire [31:0] branchImm16 = {{14{instr[25]}}, instr[25:10], 2'b00};
  wire [25:0] offs26 = {instr[9:0], instr[25:10]};
  wire [31:0] branchImm26 = {{4{offs26[25]}}, offs26, 2'b00};
  wire [31:0] upperImm20 = {instr[24:5], 12'h000};

  always @(*) begin
    validOut = validIn;
    pcOut = pc;
    src1Enable = 1'b0;
    src1Reg = 5'h0;
    src2Enable = 1'b0;
    src2Reg = 5'h0;
    writeEnable = 1'b0;
    writeReg = 5'h0;
    writeData = 32'h0;
    op1Sel = OP1_ZERO;
    op2Sel = OP2_ZERO;
    immediate = 32'h0;
    aluOp = `ALU_ADD;
    aluDst = `DST_NOP;
    memOp = `MEM_NOP;
    branchType = BR_NONE;
    specialOp = SPECIAL_NONE;
    csrNum = instr[23:10];

    if (validIn) begin
      case (opcode6)
        `JIRL: begin
          src1Enable = 1'b1;
          src1Reg = rj;
          writeEnable = 1'b1;
          writeReg = rd;
          writeData = pc + 32'd4;
          immediate = branchImm16;
          branchType = BR_JIRL;
        end
        `B: begin
          immediate = branchImm26;
          branchType = BR_B;
        end
        `BL: begin
          writeEnable = 1'b1;
          writeReg = 5'd1;
          writeData = pc + 32'd4;
          immediate = branchImm26;
          branchType = BR_B;
        end
        `BEQ, `BNE, `BLTU: begin
          src1Enable = 1'b1;
          src1Reg = rj;
          src2Enable = 1'b1;
          src2Reg = rd;
          immediate = branchImm16;
          branchType = (opcode6 == `BEQ) ? BR_BEQ :
                       (opcode6 == `BNE) ? BR_BNE : BR_BLTU;
        end
        default: begin
          if (opcode8 == `CSR_OP) begin
            writeEnable = 1'b1;
            writeReg = rd;
            if (rj == 5'd0) begin
              specialOp = SPECIAL_CSRRD;
            end else if (rj == 5'd1) begin
              src1Enable = 1'b1;
              src1Reg = rd;
              specialOp = SPECIAL_CSRWR;
            end else begin
              src1Enable = 1'b1;
              src1Reg = rd;
              src2Enable = 1'b1;
              src2Reg = rj;
              specialOp = SPECIAL_CSRXCHG;
            end
          end else begin
          case (opcode7)
            `LU12I_W: begin
              writeEnable = 1'b1;
              writeReg = rd;
              writeData = upperImm20;
            end
            `PCADDU12I: begin
              writeEnable = 1'b1;
              writeReg = rd;
              op1Sel = OP1_PC;
              op2Sel = OP2_IMM;
              immediate = upperImm20;
              aluOp = `ALU_ADD;
              aluDst = `DST_REG;
            end
            default: begin
              case (opcode10)
                `ADDI_W, `ORI, `ANDI, `SLTI: begin
                  src1Enable = 1'b1;
                  src1Reg = rj;
                  writeEnable = 1'b1;
                  writeReg = rd;
                  op1Sel = OP1_SRC1;
                  op2Sel = OP2_IMM;
                  immediate = (opcode10 == `ORI || opcode10 == `ANDI) ? zeroImm12 : signImm12;
                  aluOp = (opcode10 == `ORI) ? `ALU_OR :
                          (opcode10 == `ANDI) ? `ALU_AND :
                          (opcode10 == `SLTI) ? `ALU_SLT : `ALU_ADD;
                  aluDst = `DST_REG;
                end
                `LD_W, `LD_B: begin
                  src1Enable = 1'b1;
                  src1Reg = rj;
                  writeEnable = 1'b1;
                  writeReg = rd;
                  op1Sel = OP1_SRC1;
                  op2Sel = OP2_IMM;
                  immediate = signImm12;
                  aluOp = `ALU_ADD;
                  aluDst = `DST_MEM;
                  memOp = (opcode10 == `LD_W) ? `MEM_LW : `MEM_LB;
                end
                `ST_W, `ST_B: begin
                  src1Enable = 1'b1;
                  src1Reg = rj;
                  src2Enable = 1'b1;
                  src2Reg = rd;
                  op1Sel = OP1_SRC1;
                  op2Sel = OP2_IMM;
                  immediate = signImm12;
                  aluOp = `ALU_ADD;
                  aluDst = `DST_MEM;
                  memOp = (opcode10 == `ST_W) ? `MEM_SW : `MEM_SB;
                end
                `CACOP: begin
                  src1Enable = 1'b1;
                  src1Reg = rj;
                  op1Sel = OP1_SRC1;
                  op2Sel = OP2_IMM;
                  immediate = signImm12;
                  aluOp = `ALU_ADD;
                  specialOp = (rd == 5'd0) ? SPECIAL_CACOP : SPECIAL_NONE;
                end
                default: begin
                  case (opcode17)
                    `ADD_W, `SUB_W, `OR, `AND, `XOR, `MUL_W, `SRL_W: begin
                      src1Enable = 1'b1;
                      src1Reg = rj;
                      src2Enable = 1'b1;
                      src2Reg = rk;
                      writeEnable = 1'b1;
                      writeReg = rd;
                      op1Sel = OP1_SRC1;
                      op2Sel = OP2_SRC2;
                      aluOp = (opcode17 == `SUB_W) ? `ALU_SUB :
                              (opcode17 == `OR) ? `ALU_OR :
                              (opcode17 == `AND) ? `ALU_AND :
                              (opcode17 == `XOR) ? `ALU_XOR :
                              (opcode17 == `MUL_W) ? `ALU_MUL :
                              (opcode17 == `SRL_W) ? `ALU_SRL : `ALU_ADD;
                      aluDst = `DST_REG;
                    end
                    `SRLI_W, `SLLI_W: begin
                      src1Enable = 1'b1;
                      src1Reg = rj;
                      writeEnable = 1'b1;
                      writeReg = rd;
                      op1Sel = OP1_SRC1;
                      op2Sel = OP2_IMM;
                      immediate = {27'h0, instr[14:10]};
                      aluOp = (opcode17 == `SRLI_W) ? `ALU_SRL : `ALU_SLL;
                      aluDst = `DST_REG;
                    end
                    `CPUCFG: begin
                      src1Enable = 1'b1;
                      src1Reg = rj;
                      writeEnable = 1'b1;
                      writeReg = rd;
                      specialOp = SPECIAL_CPUCFG;
                    end
                    default: begin
                    end
                  endcase
                end
              endcase
            end
          endcase
          end
        end
      endcase
    end
  end

endmodule
