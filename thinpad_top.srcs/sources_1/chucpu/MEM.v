`include "MEMOp.vh"

module MEM(
  input wire clk,
  input wire rst,

  input wire [31:0] writeDataIn,
  output reg [31:0] writeDataOut,

  input wire [7:0] memOp,
  input wire [31:0] memAddress,

  input wire dataMemReadEnableIn,
  input wire dataMemWriteEnableIn,
  input wire [31:0] dataMemAddressIn,
  input wire [31:0] dataMemWriteDataIn,
  input wire [3:0] dataMemByteEnableIn,
  input wire dataMemChipSelectIn,

  output wire dataMemReadEnable,
  output wire dataMemWriteEnable,
  input wire [31:0] dataMemReadData,
  output wire [31:0] dataMemWriteData,
  output wire [31:0] dataMemAddress,
  output wire [3:0] dataMemByteEnable,
  output wire dataMemChipSelect,

  output wire stallReq
);

  assign dataMemReadEnable = dataMemReadEnableIn;
  assign dataMemWriteEnable = dataMemWriteEnableIn;
  assign dataMemAddress = dataMemAddressIn;
  assign dataMemWriteData = dataMemWriteDataIn;
  assign dataMemByteEnable = dataMemByteEnableIn;
  assign dataMemChipSelect = dataMemChipSelectIn;

  assign stallReq = dataMemChipSelectIn && (dataMemAddressIn[31:22] == 10'h070);

  always @(*) begin
    writeDataOut = writeDataIn;
    case (memOp)
      `MEM_LB: begin
        case (memAddress[1:0])
          2'b00: writeDataOut = {{24{dataMemReadData[7]}}, dataMemReadData[7:0]};
          2'b01: writeDataOut = {{24{dataMemReadData[15]}}, dataMemReadData[15:8]};
          2'b10: writeDataOut = {{24{dataMemReadData[23]}}, dataMemReadData[23:16]};
          2'b11: writeDataOut = {{24{dataMemReadData[31]}}, dataMemReadData[31:24]};
        endcase
      end
      `MEM_LW: writeDataOut = dataMemReadData;
      default: begin
      end
    endcase
  end

endmodule
