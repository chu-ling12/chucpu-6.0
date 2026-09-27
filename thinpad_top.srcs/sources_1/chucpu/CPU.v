`include "OpCode.vh"

module CPU(
  input wire clk,
  input wire rst,

  output wire [31:0] instrMemAddress,
  output wire [31:0] instrMemAddressNext,
  output wire [31:0] instrMemPhysicalAddress,
  output wire [31:0] instrMemPhysicalAddressNext,
  output wire instrMemCached,
  output wire cacopInvalidate,
  output wire [31:0] cacopAddress,
  input wire [31:0] instrMemData,

  output wire dataMemReadEnable,
  output wire dataMemWriteEnable,
  input wire dataMemRequestReady,
  input wire dataMemResponseValid,
  input wire [31:0] dataMemReadData,
  output wire [31:0] dataMemWriteData,
  output wire [31:0] dataMemAddress,
  output wire [3:0] dataMemByteEnable,
  output wire dataMemChipSelect,
  output wire dataMemBaseRamSelect,
  output wire dataMemExtRamSelect,
  output wire dataMemUartSelect,
  input wire instrMemHold
);

  reg cpuRst;
  always @(posedge clk or posedge rst) begin
    if (rst)
      cpuRst <= 1'b1;
    else
      cpuRst <= 1'b0;
  end

  wire frontendHold;
  wire branchResolved;
  wire branchCommit;
  wire redirectCommit;
  wire specialCommit;
  wire [31:0] branchAddress;
  wire exMemWait;
  wire loadPipelineHold;
  wire mdLoadWait;
  wire mulStall;

  wire ifIdValid;
  wire [31:0] ifIdPc;
  wire [31:0] ifIdInstr;
  wire ifIdPredictedTaken;

  wire id1Valid;
  wire [31:0] id1Pc;
  wire id1Src1Enable;
  wire [4:0] id1Src1Reg;
  wire id1Src2Enable;
  wire [4:0] id1Src2Reg;
  wire id1WriteEnable;
  wire [4:0] id1WriteReg;
  wire [31:0] id1WriteData;
  wire [1:0] id1Op1Sel;
  wire [1:0] id1Op2Sel;
  wire [31:0] id1Immediate;
  wire [7:0] id1AluOp;
  wire [1:0] id1AluDst;
  wire [7:0] id1MemOp;
  wire [2:0] id1BranchType;
  wire [2:0] id1SpecialOp;
  wire [13:0] id1CsrNum;

  wire id2Valid;
  wire [31:0] id2Pc;
  wire id2PredictedTaken;
  wire id2Src1Enable;
  wire [4:0] id2Src1Reg;
  wire id2Src2Enable;
  wire [4:0] id2Src2Reg;
  wire id2WriteEnableIn;
  wire [4:0] id2WriteRegIn;
  wire [31:0] id2WriteDataIn;
  wire [1:0] id2Op1Sel;
  wire [1:0] id2Op2Sel;
  wire [31:0] id2Immediate;
  wire [7:0] id2AluOpIn;
  wire [1:0] id2AluDstIn;
  wire [7:0] id2MemOpIn;
  wire [2:0] id2BranchType;
  wire [2:0] id2SpecialOp;
  wire [13:0] id2CsrNum;

  wire regReadEnable1;
  wire [4:0] regReadReg1;
  wire [31:0] regReadData1;
  wire regReadEnable2;
  wire [4:0] regReadReg2;
  wire [31:0] regReadData2;
  wire regWriteEnable;
  wire [4:0] regWriteReg;
  wire [31:0] regWriteData;

  wire idWriteEnable;
  wire [4:0] idWriteReg;
  wire [31:0] idWriteData;
  wire [31:0] idBusA;
  wire [31:0] idBusB;
  wire [31:0] idMemWriteData;
  wire [7:0] idAluOp;
  wire [1:0] idAluDst;
  wire [7:0] idMemOp;
  wire stallReqID;
  wire [31:0] csrReadData;
  wire csrWriteEnableRaw;
  wire [13:0] csrWriteAddr;
  wire [31:0] csrWriteData;
  wire cacopInvalidateRaw;
  wire [31:0] cacopVirtualAddress;
  wire [31:0] cacopPhysicalAddress;

  wire exWriteEnable;
  wire [4:0] exWriteReg;
  wire [31:0] exWriteDataIn;
  wire [31:0] exWriteData;
  wire [7:0] exMemOp;
  wire [31:0] exMemWriteData;
  wire [1:0] exAluDst;
  wire [31:0] aluBusA;
  wire [31:0] aluBusB;
  wire [7:0] aluOp;
  wire [31:0] aluOut;
  wire [31:0] exMemAddress;
  wire [31:0] exMemPhysicalAddress;
  wire exMemAddressCached;

  wire exDataMemReadEnable;
  wire exDataMemWriteEnable;
  wire [31:0] exDataMemAddress;
  wire [31:0] exDataMemWriteData;
  wire [3:0] exDataMemByteEnable;
  wire exDataMemChipSelect;
  wire exDataMemBaseRamSelect;
  wire exDataMemExtRamSelect;
  wire exDataMemUartSelect;

  wire memWriteEnable;
  wire [4:0] memWriteReg;
  wire [31:0] memWriteDataIn;
  wire [7:0] memMemOp;
  wire [31:0] memMemAddress;
  wire [31:0] memMemWriteData;
  wire memDataMemReadEnable;
  wire memDataMemWriteEnable;
  wire [31:0] memDataMemAddress;
  wire [31:0] memDataMemWriteData;
  wire [3:0] memDataMemByteEnable;
  wire memDataMemChipSelect;
  wire memDataMemBaseRamSelect;
  wire memDataMemExtRamSelect;
  wire memDataMemUartSelect;
  wire stallReqMEM;
  wire mdWriteEnable;
  wire [4:0] mdWriteReg;
  wire [31:0] mdWriteDataIn;
  wire [31:0] mdWriteDataOut;
  wire [7:0] mdMemOp;
  wire [31:0] mdMemAddress;
  wire mdIsLoad;
  wire mdWriteEnableEffective;
  wire [31:0] lastStoreAddress;
  wire [31:0] lastStoreData;

  reg [1:0] branchHistory [0:31];
  reg branchHistoryValid [0:31];
  (* ram_style = "distributed" *) reg [24:0] branchTargetTag [0:31];
  (* ram_style = "distributed" *) reg [31:0] branchTarget [0:31];
  reg branchTargetValid [0:31];
  integer branchHistoryIndex;

  assign exMemWait = memDataMemChipSelect && !dataMemRequestReady;
  assign mdLoadWait = mdIsLoad && !dataMemResponseValid;
  assign loadPipelineHold = (memDataMemReadEnable && !mdIsLoad) || mdLoadWait;
  assign frontendHold = stallReqID || exMemWait || mulStall || instrMemHold ||
                         loadPipelineHold;
  wire [4:0] fetchHistoryIndex = instrMemAddress[6:2];
  wire fetchTargetHit = branchTargetValid[fetchHistoryIndex] &&
                        (branchTargetTag[fetchHistoryIndex] ==
                         instrMemAddress[31:7]);
  wire fetchDynamicTaken = branchHistoryValid[fetchHistoryIndex] ?
                           branchHistory[fetchHistoryIndex][1] :
                           1'b0;
  wire fetchPredictedTaken = fetchTargetHit && fetchDynamicTaken;
  wire [31:0] fetchPredictedAddress = branchTarget[fetchHistoryIndex];
  wire branchDecisionValid = id2Valid && (id2BranchType != 3'd0) &&
                             !stallReqID;
  wire branchMispredict = branchDecisionValid &&
                          (branchResolved != id2PredictedTaken);
  wire [31:0] branchRecoveryAddress = branchResolved ? branchAddress :
                                      id2Pc + 32'd4;
  wire branchResolutionCommit = branchDecisionValid && !exMemWait &&
                                !mulStall &&
                                !instrMemHold && !loadPipelineHold;

  always @(posedge clk) begin
    if (cpuRst) begin
      for (branchHistoryIndex = 0; branchHistoryIndex < 32;
           branchHistoryIndex = branchHistoryIndex + 1) begin
        branchHistory[branchHistoryIndex] = 2'b01;
        branchHistoryValid[branchHistoryIndex] = 1'b0;
        branchTargetValid[branchHistoryIndex] = 1'b0;
      end
    end else begin
      if (branchResolutionCommit) begin
        if (id2BranchType >= 3'd2) begin
          branchTargetTag[id2Pc[6:2]] <= id2Pc[31:7];
          branchTarget[id2Pc[6:2]] <= branchAddress;
          branchTargetValid[id2Pc[6:2]] <= 1'b1;
        end
        if (id2BranchType == 3'd2) begin
          branchHistoryValid[id2Pc[6:2]] <= 1'b1;
          branchHistory[id2Pc[6:2]] <= 2'b11;
        end else if (id2BranchType >= 3'd3) begin
          branchHistoryValid[id2Pc[6:2]] <= 1'b1;
          if (!branchHistoryValid[id2Pc[6:2]]) begin
            branchHistory[id2Pc[6:2]] <= branchResolved ? 2'b10 : 2'b01;
          end else if (branchResolved) begin
            if (branchHistory[id2Pc[6:2]] != 2'b11)
              branchHistory[id2Pc[6:2]] <= branchHistory[id2Pc[6:2]] + 2'b01;
          end else if (branchHistory[id2Pc[6:2]] != 2'b00) begin
            branchHistory[id2Pc[6:2]] <= branchHistory[id2Pc[6:2]] - 2'b01;
          end
        end
      end
      // Program loading and self-modifying code must not reuse an old target.
      if (memDataMemWriteEnable && memDataMemBaseRamSelect &&
          dataMemRequestReady)
        branchTargetValid[memDataMemAddress[6:2]] <= 1'b0;
    end
  end

  assign branchCommit = branchMispredict && !exMemWait && !mulStall &&
                         !instrMemHold &&
                         !loadPipelineHold;
  assign specialCommit = (csrWriteEnableRaw || cacopInvalidateRaw) &&
                         !exMemWait && !mulStall && !instrMemHold &&
                         !loadPipelineHold;
  assign redirectCommit = branchCommit || specialCommit;
  assign instrMemAddressNext = branchCommit ? branchRecoveryAddress :
                                specialCommit ? id2Pc + 32'd4 :
                                frontendHold ? instrMemAddress :
                                fetchPredictedTaken ? fetchPredictedAddress :
                                instrMemAddress + 32'd4;
  assign dataMemReadEnable = memDataMemReadEnable;
  assign dataMemWriteEnable = memDataMemWriteEnable;
  assign dataMemAddress = memDataMemAddress;
  assign dataMemWriteData = memDataMemWriteData;
  assign dataMemByteEnable = memDataMemByteEnable;
  assign dataMemChipSelect = memDataMemChipSelect;
  assign dataMemBaseRamSelect = memDataMemBaseRamSelect;
  assign dataMemExtRamSelect = memDataMemExtRamSelect;
  assign dataMemUartSelect = memDataMemUartSelect;
  assign cacopInvalidate = cacopInvalidateRaw && specialCommit;
  assign cacopAddress = cacopPhysicalAddress;

  PC u_pc(
    .clk(clk),
    .rst(cpuRst),
    .hold(frontendHold),
    .branch(redirectCommit),
    .branchAddress(branchCommit ? branchRecoveryAddress : id2Pc + 32'd4),
    .predictTaken(fetchPredictedTaken),
    .predictAddress(fetchPredictedAddress),
    .pc(instrMemAddress)
  );

  IF_ID u_if_id(
    .clk(clk),
    .rst(cpuRst),
    .hold(frontendHold),
    .flush(redirectCommit),
    .pcIF(instrMemAddress),
    .instrIF(instrMemData),
    .predictedTakenIF(fetchPredictedTaken),
    .validID(ifIdValid),
    .pcID(ifIdPc),
    .instrID(ifIdInstr),
    .predictedTakenID(ifIdPredictedTaken)
  );

  ID u_id1(
    .validIn(ifIdValid),
    .pc(ifIdPc),
    .instr(ifIdInstr),
    .validOut(id1Valid),
    .pcOut(id1Pc),
    .src1Enable(id1Src1Enable),
    .src1Reg(id1Src1Reg),
    .src2Enable(id1Src2Enable),
    .src2Reg(id1Src2Reg),
    .writeEnable(id1WriteEnable),
    .writeReg(id1WriteReg),
    .writeData(id1WriteData),
    .op1Sel(id1Op1Sel),
    .op2Sel(id1Op2Sel),
    .immediate(id1Immediate),
    .aluOp(id1AluOp),
    .aluDst(id1AluDst),
    .memOp(id1MemOp),
    .branchType(id1BranchType),
    .specialOp(id1SpecialOp),
    .csrNum(id1CsrNum)
  );

  ID1_ID2 u_id1_id2(
    .clk(clk),
    .rst(cpuRst),
    .hold(frontendHold),
    .flush(redirectCommit),
    .validIn(id1Valid),
    .pcIn(id1Pc),
    .predictedTakenIn(ifIdPredictedTaken),
    .src1EnableIn(id1Src1Enable),
    .src1RegIn(id1Src1Reg),
    .src2EnableIn(id1Src2Enable),
    .src2RegIn(id1Src2Reg),
    .writeEnableIn(id1WriteEnable),
    .writeRegIn(id1WriteReg),
    .writeDataIn(id1WriteData),
    .op1SelIn(id1Op1Sel),
    .op2SelIn(id1Op2Sel),
    .immediateIn(id1Immediate),
    .aluOpIn(id1AluOp),
    .aluDstIn(id1AluDst),
    .memOpIn(id1MemOp),
    .branchTypeIn(id1BranchType),
    .specialOpIn(id1SpecialOp),
    .csrNumIn(id1CsrNum),
    .validOut(id2Valid),
    .pcOut(id2Pc),
    .predictedTakenOut(id2PredictedTaken),
    .src1EnableOut(id2Src1Enable),
    .src1RegOut(id2Src1Reg),
    .src2EnableOut(id2Src2Enable),
    .src2RegOut(id2Src2Reg),
    .writeEnableOut(id2WriteEnableIn),
    .writeRegOut(id2WriteRegIn),
    .writeDataOut(id2WriteDataIn),
    .op1SelOut(id2Op1Sel),
    .op2SelOut(id2Op2Sel),
    .immediateOut(id2Immediate),
    .aluOpOut(id2AluOpIn),
    .aluDstOut(id2AluDstIn),
    .memOpOut(id2MemOpIn),
    .branchTypeOut(id2BranchType),
    .specialOpOut(id2SpecialOp),
    .csrNumOut(id2CsrNum)
  );

  RegFile u_regfile(
    .clk(clk),
    .rst(cpuRst),
    .readEnable1(regReadEnable1),
    .readReg1(regReadReg1),
    .readData1(regReadData1),
    .readEnable2(regReadEnable2),
    .readReg2(regReadReg2),
    .readData2(regReadData2),
    .writeEnable(regWriteEnable),
    .writeReg(regWriteReg),
    .writeData(regWriteData)
  );

  ID2 u_id2(
    .validIn(id2Valid),
    .pc(id2Pc),
    .src1Enable(id2Src1Enable),
    .src1Reg(id2Src1Reg),
    .src1Data(regReadData1),
    .src2Enable(id2Src2Enable),
    .src2Reg(id2Src2Reg),
    .src2Data(regReadData2),
    .writeEnableIn(id2WriteEnableIn),
    .writeRegIn(id2WriteRegIn),
    .writeDataIn(id2WriteDataIn),
    .op1Sel(id2Op1Sel),
    .op2Sel(id2Op2Sel),
    .immediate(id2Immediate),
    .aluOpIn(id2AluOpIn),
    .aluDstIn(id2AluDstIn),
    .memOpIn(id2MemOpIn),
    .branchType(id2BranchType),
    .specialOp(id2SpecialOp),
    .csrNum(id2CsrNum),
    .csrReadData(csrReadData),
    .writeEnableEX(exWriteEnable),
    .writeRegEX(exWriteReg),
    .writeDataEX(exWriteData),
    .memOpEX(exMemOp),
    .memAddressEX(exMemAddress),
    .writeEnableMEM(memWriteEnable),
    .writeRegMEM(memWriteReg),
    .writeDataMEM(memWriteDataIn),
    .memOpMEM(memMemOp),
    .writeEnableMD(mdWriteEnableEffective),
    .writeRegMD(mdWriteReg),
    .writeDataMD(mdWriteDataOut),
    .lastStoreAddress(lastStoreAddress),
    .lastStoreData(lastStoreData),
    .readEnable1(regReadEnable1),
    .readReg1(regReadReg1),
    .readEnable2(regReadEnable2),
    .readReg2(regReadReg2),
    .writeEnableOut(idWriteEnable),
    .writeRegOut(idWriteReg),
    .writeDataOut(idWriteData),
    .busAOut(idBusA),
    .busBOut(idBusB),
    .memWriteDataOut(idMemWriteData),
    .aluOpOut(idAluOp),
    .aluDstOut(idAluDst),
    .memOpOut(idMemOp),
    .csrWriteEnable(csrWriteEnableRaw),
    .csrWriteAddr(csrWriteAddr),
    .csrWriteData(csrWriteData),
    .cacopInvalidate(cacopInvalidateRaw),
    .cacopAddress(cacopVirtualAddress),
    .branch(branchResolved),
    .branchAddress(branchAddress),
    .stallReq(stallReqID)
  );

  ID_EX u_id_ex(
    .clk(clk),
    .rst(cpuRst),
    // Backpressure holds EX; other front-end stalls insert a bubble.
    .hold(exMemWait || loadPipelineHold || mulStall),
    .bubble(frontendHold && !exMemWait && !loadPipelineHold && !mulStall &&
            !redirectCommit),
    .writeEnableID(idWriteEnable),
    .writeRegID(idWriteReg),
    .writeDataID(idWriteData),
    .writeEnableEX(exWriteEnable),
    .writeRegEX(exWriteReg),
    .writeDataEX(exWriteDataIn),
    .memOpID(idMemOp),
    .memWriteDataID(idMemWriteData),
    .memOpEX(exMemOp),
    .memWriteDataEX(exMemWriteData),
    .busAID(idBusA),
    .busBID(idBusB),
    .aluOpID(idAluOp),
    .aluDstID(idAluDst),
    .busAEX(aluBusA),
    .busBEX(aluBusB),
    .aluOpEX(aluOp),
    .aluDstEX(exAluDst),
    .csrOpID(1'b0),
    .csrNumID(14'h0),
    .csrOpEX(),
    .csrNumEX()
  );

  ALU u_alu(
    .clk(clk),
    .rst(cpuRst),
    .busA(aluBusA),
    .busB(aluBusB),
    .aluOp(aluOp),
    .aluOut(aluOut),
    .mulStall(mulStall)
  );

  wire [31:0] exMemAddressFast = aluBusA + aluBusB;

  EX u_ex(
    .clk(clk),
    .rst(cpuRst),
    .aluDst(exAluDst),
    .aluOut(aluOut),
    .memAddressIn(exMemAddressFast),
    .writeDataIn(exWriteDataIn),
    .writeDataOut(exWriteData),
    .memAddress(exMemAddress),
    .csrOp(1'b0),
    .csrNum(14'h0),
    .csrWe(),
    .csrWAddr(),
    .csrWData()
  );

  MemCommand u_mem_command(
    .memOp(exMemOp),
    .memAddress(exMemPhysicalAddress),
    .memWriteData(exMemWriteData),
    .readEnable(exDataMemReadEnable),
    .writeEnable(exDataMemWriteEnable),
    .address(exDataMemAddress),
    .writeData(exDataMemWriteData),
    .byteEnable(exDataMemByteEnable),
    .chipSelect(exDataMemChipSelect),
    .baseRamSelect(exDataMemBaseRamSelect),
    .extRamSelect(exDataMemExtRamSelect),
    .uartSelect(exDataMemUartSelect)
  );

  CSR u_csr(
    .clk(clk),
    .rst(cpuRst),
    .csr_raddr(id2CsrNum),
    .csr_rdata(csrReadData),
    .csr_we(csrWriteEnableRaw && specialCommit),
    .csr_waddr(csrWriteAddr),
    .csr_wdata(csrWriteData),
    .instr_virt_addr(instrMemAddress),
    .instr_phys_addr(instrMemPhysicalAddress),
    .instr_cached(instrMemCached),
    .instr_next_virt_addr(instrMemAddressNext),
    .instr_next_phys_addr(instrMemPhysicalAddressNext),
    .data_virt_addr(exMemAddress),
    .data_phys_addr(exMemPhysicalAddress),
    .data_cached(exMemAddressCached),
    .cacop_virt_addr(cacopVirtualAddress),
    .cacop_phys_addr(cacopPhysicalAddress)
  );

  EX_MEM u_ex_mem(
    .clk(clk),
    .rst(cpuRst),
    .hold(exMemWait),
    .bubble(loadPipelineHold || mulStall),
    .writeEnableEX(exWriteEnable),
    .writeRegEX(exWriteReg),
    .writeDataEX(exWriteData),
    .writeEnableMEM(memWriteEnable),
    .writeRegMEM(memWriteReg),
    .writeDataMEM(memWriteDataIn),
    .memOpEX(exMemOp),
    .memAddressEX(exMemAddress),
    .memWriteDataEX(exMemWriteData),
    .memOpMEM(memMemOp),
    .memAddressMEM(memMemAddress),
    .memWriteDataMEM(memMemWriteData),
    .dataMemReadEnableEX(exDataMemReadEnable),
    .dataMemWriteEnableEX(exDataMemWriteEnable),
    .dataMemAddressEX(exDataMemAddress),
    .dataMemWriteDataEX(exDataMemWriteData),
    .dataMemByteEnableEX(exDataMemByteEnable),
    .dataMemChipSelectEX(exDataMemChipSelect),
    .dataMemBaseRamSelectEX(exDataMemBaseRamSelect),
    .dataMemExtRamSelectEX(exDataMemExtRamSelect),
    .dataMemUartSelectEX(exDataMemUartSelect),
    .dataMemReadEnableMEM(memDataMemReadEnable),
    .dataMemWriteEnableMEM(memDataMemWriteEnable),
    .dataMemAddressMEM(memDataMemAddress),
    .dataMemWriteDataMEM(memDataMemWriteData),
    .dataMemByteEnableMEM(memDataMemByteEnable),
    .dataMemChipSelectMEM(memDataMemChipSelect),
    .dataMemBaseRamSelectMEM(memDataMemBaseRamSelect),
    .dataMemExtRamSelectMEM(memDataMemExtRamSelect),
    .dataMemUartSelectMEM(memDataMemUartSelect),
    .lastStoreAddress(lastStoreAddress),
    .lastStoreData(lastStoreData)
  );

  MEM u_mem(
    .clk(clk),
    .rst(cpuRst),
    .writeDataIn(mdWriteDataIn),
    .writeDataOut(mdWriteDataOut),
    .memOp(mdMemOp),
    .memAddress(mdMemAddress),
    .dataMemReadEnableIn(memDataMemReadEnable),
    .dataMemWriteEnableIn(memDataMemWriteEnable),
    .dataMemAddressIn(memDataMemAddress),
    .dataMemWriteDataIn(memDataMemWriteData),
    .dataMemByteEnableIn(memDataMemByteEnable),
    .dataMemChipSelectIn(memDataMemChipSelect),
    .dataMemReadEnable(),
    .dataMemWriteEnable(),
    .dataMemReadData(dataMemReadData),
    .dataMemWriteData(),
    .dataMemAddress(),
    .dataMemByteEnable(),
    .dataMemChipSelect(),
    .stallReq(stallReqMEM)
  );

  MA_MD u_ma_md(
    .clk(clk),
    .rst(cpuRst),
    .hold(mdLoadWait),
    .writeEnableMA(memWriteEnable),
    .writeRegMA(memWriteReg),
    .writeDataMA(memWriteDataIn),
    .memOpMA(memMemOp),
    .memAddressMA(memMemAddress),
    .writeEnableMD(mdWriteEnable),
    .writeRegMD(mdWriteReg),
    .writeDataMD(mdWriteDataIn),
    .memOpMD(mdMemOp),
    .memAddressMD(mdMemAddress)
  );

  assign mdIsLoad = (mdMemOp == 8'b00000001) ||
                    (mdMemOp == 8'b00000010);
  assign mdWriteEnableEffective = mdWriteEnable &&
                                  (!mdIsLoad || dataMemResponseValid);

  MEM_WB u_mem_wb(
    .clk(clk),
    .rst(cpuRst),
    .writeEnableMEM(mdWriteEnableEffective),
    .writeRegMEM(mdWriteReg),
    .writeDataMEM(mdWriteDataOut),
    .writeEnableWB(regWriteEnable),
    .writeRegWB(regWriteReg),
    .writeDataWB(regWriteData)
  );

endmodule
