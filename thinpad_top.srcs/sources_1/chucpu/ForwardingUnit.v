module ForwardingUnit(
  input wire [4:0] readReg,
  input wire [31:0] readData,
  input wire lastInstrLoad,
  input wire memInstrLoad,
  input wire lastInstrStore,
  input wire [4:0] writeRegEX,
  input wire [31:0] writeDataEX,
  input wire writeEnableEX,
  input wire [4:0] writeRegMEM,
  input wire [31:0] writeDataMEM,
  input wire writeEnableMEM,
  input wire [4:0] writeRegMD,
  input wire [31:0] writeDataMD,
  input wire writeEnableMD,
  input wire [31:0] memAddressEX,
  input wire [31:0] lastStoreAddress,
  input wire [31:0] lastStoreData,
  output wire [31:0] result,
  output wire stallReq
);

  wire exMatch = writeEnableEX && (readReg == writeRegEX);
  wire memMatch = writeEnableMEM && (readReg == writeRegMEM);
  wire mdMatch = writeEnableMD && (readReg == writeRegMD);
  // Store-to-load forwarding is now performed by the valid, byte-aware
  // store buffer in RAM.v.
  wire storeBypass = 1'b0;

  assign stallReq = (readReg != 5'h0) &&
                    ((lastInstrLoad && exMatch && !storeBypass) ||
                     (memInstrLoad && memMatch));

  assign result =
    (readReg == 5'h0) ? 32'h0 :
    storeBypass ? lastStoreData :
    (exMatch && !lastInstrLoad) ? writeDataEX :
    (memMatch && !memInstrLoad) ? writeDataMEM :
    mdMatch ? writeDataMD :
    readData;

endmodule
