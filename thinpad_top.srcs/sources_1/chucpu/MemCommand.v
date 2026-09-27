`include "MEMOp.vh"

module MemCommand(
  input wire [7:0] memOp,
  input wire [31:0] memAddress,
  input wire [31:0] memWriteData,

  output reg readEnable,
  output reg writeEnable,
  output reg [31:0] address,
  output reg [31:0] writeData,
  output reg [3:0] byteEnable,
  output reg chipSelect,
  output reg baseRamSelect,
  output reg extRamSelect,
  output reg uartSelect
);

  always @(*) begin
    readEnable = 1'b0;
    writeEnable = 1'b0;
    address = 32'h0;
    writeData = 32'h0;
    byteEnable = 4'b0000;
    chipSelect = 1'b0;
    baseRamSelect = 1'b0;
    extRamSelect = 1'b0;
    uartSelect = 1'b0;

    case (memOp)
      `MEM_LB: begin
        readEnable = 1'b1;
        address = memAddress;
        byteEnable = 4'b0001 << memAddress[1:0];
        chipSelect = 1'b1;
      end
      `MEM_LW: begin
        readEnable = 1'b1;
        address = memAddress;
        byteEnable = 4'b1111;
        chipSelect = 1'b1;
      end
      `MEM_SB: begin
        writeEnable = 1'b1;
        address = memAddress;
        byteEnable = 4'b0001 << memAddress[1:0];
        chipSelect = 1'b1;
        case (memAddress[1:0])
          2'b00: writeData = {24'h0, memWriteData[7:0]};
          2'b01: writeData = {16'h0, memWriteData[7:0], 8'h0};
          2'b10: writeData = {8'h0, memWriteData[7:0], 16'h0};
          2'b11: writeData = {memWriteData[7:0], 24'h0};
        endcase
      end
      `MEM_SW: begin
        writeEnable = 1'b1;
        address = memAddress;
        writeData = memWriteData;
        byteEnable = 4'b1111;
        chipSelect = 1'b1;
      end
      default: begin
      end
    endcase

    if (chipSelect) begin
      baseRamSelect = (memAddress[31:22] == 10'h070);
      extRamSelect = (memAddress[31:22] == 10'h071);
      uartSelect = (memAddress[31:20] == 12'h1F0);
    end
  end

endmodule
