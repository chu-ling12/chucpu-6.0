`include "MEMOp.vh"

module EX_MEM(
  input wire clk,
  input wire rst,
  input wire hold,
  input wire bubble,

  input wire writeEnableEX,
  input wire [4:0] writeRegEX,
  input wire [31:0] writeDataEX,
  output reg writeEnableMEM,
  output reg [4:0] writeRegMEM,
  output reg [31:0] writeDataMEM,

  input wire [7:0] memOpEX,
  input wire [31:0] memAddressEX,
  input wire [31:0] memWriteDataEX,
  output reg [7:0] memOpMEM,
  output reg [31:0] memAddressMEM,
  output reg [31:0] memWriteDataMEM,

  input wire dataMemReadEnableEX,
  input wire dataMemWriteEnableEX,
  input wire [31:0] dataMemAddressEX,
  input wire [31:0] dataMemWriteDataEX,
  input wire [3:0] dataMemByteEnableEX,
  input wire dataMemChipSelectEX,
  input wire dataMemBaseRamSelectEX,
  input wire dataMemExtRamSelectEX,
  input wire dataMemUartSelectEX,
  output reg dataMemReadEnableMEM,
  output reg dataMemWriteEnableMEM,
  output reg [31:0] dataMemAddressMEM,
  output reg [31:0] dataMemWriteDataMEM,
  output reg [3:0] dataMemByteEnableMEM,
  output reg dataMemChipSelectMEM,
  output reg dataMemBaseRamSelectMEM,
  output reg dataMemExtRamSelectMEM,
  output reg dataMemUartSelectMEM,

  output reg [31:0] lastStoreAddress,
  output reg [31:0] lastStoreData
);

  always @(posedge clk) begin
    if (rst) begin
      writeEnableMEM <= 1'b0;
      writeRegMEM <= 5'h0;
      writeDataMEM <= 32'h0;
      memOpMEM <= 3'h0;
      memAddressMEM <= 32'h0;
      memWriteDataMEM <= 32'h0;
      dataMemReadEnableMEM <= 1'b0;
      dataMemWriteEnableMEM <= 1'b0;
      dataMemAddressMEM <= 32'h0;
      dataMemWriteDataMEM <= 32'h0;
      dataMemByteEnableMEM <= 4'b0000;
      dataMemChipSelectMEM <= 1'b0;
      dataMemBaseRamSelectMEM <= 1'b0;
      dataMemExtRamSelectMEM <= 1'b0;
      dataMemUartSelectMEM <= 1'b0;
      lastStoreAddress <= 32'h0;
      lastStoreData <= 32'h0;
    end else if (!hold && bubble) begin
      writeEnableMEM <= 1'b0;
      writeRegMEM <= 5'h0;
      writeDataMEM <= 32'h0;
      memOpMEM <= `MEM_NOP;
      memAddressMEM <= 32'h0;
      memWriteDataMEM <= 32'h0;
      dataMemReadEnableMEM <= 1'b0;
      dataMemWriteEnableMEM <= 1'b0;
      dataMemAddressMEM <= 32'h0;
      dataMemWriteDataMEM <= 32'h0;
      dataMemByteEnableMEM <= 4'b0000;
      dataMemChipSelectMEM <= 1'b0;
      dataMemBaseRamSelectMEM <= 1'b0;
      dataMemExtRamSelectMEM <= 1'b0;
      dataMemUartSelectMEM <= 1'b0;
    end else if (!hold) begin
      writeEnableMEM <= writeEnableEX;
      writeRegMEM <= writeRegEX;
      writeDataMEM <= writeDataEX;
      memOpMEM <= memOpEX;
      memAddressMEM <= memAddressEX;
      memWriteDataMEM <= memWriteDataEX;
      dataMemReadEnableMEM <= dataMemReadEnableEX;
      dataMemWriteEnableMEM <= dataMemWriteEnableEX;
      dataMemAddressMEM <= dataMemAddressEX;
      dataMemWriteDataMEM <= dataMemWriteDataEX;
      dataMemByteEnableMEM <= dataMemByteEnableEX;
      dataMemChipSelectMEM <= dataMemChipSelectEX;
      dataMemBaseRamSelectMEM <= dataMemBaseRamSelectEX;
      dataMemExtRamSelectMEM <= dataMemExtRamSelectEX;
      dataMemUartSelectMEM <= dataMemUartSelectEX;
      case (memOpEX)
        `MEM_SB: begin
          lastStoreAddress <= memAddressEX;
          case (memAddressEX[1:0])
            2'b00: lastStoreData <= {24'h0, memWriteDataEX[7:0]};
            2'b01: lastStoreData <= {16'h0, memWriteDataEX[7:0], 8'h0};
            2'b10: lastStoreData <= {8'h0, memWriteDataEX[7:0], 16'h0};
            2'b11: lastStoreData <= {memWriteDataEX[7:0], 24'h0};
            default: lastStoreData <= lastStoreData;
          endcase
        end
        `MEM_SW: begin
          lastStoreAddress <= memAddressEX;
          lastStoreData <= memWriteDataEX;
        end
        default: begin
          lastStoreAddress <= lastStoreAddress;
          lastStoreData <= lastStoreData;
        end
      endcase
    end
  end

endmodule
