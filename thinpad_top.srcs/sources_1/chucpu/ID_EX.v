module ID_EX(
  input wire clk,
  input wire rst,
  input wire hold,
  input wire bubble,

  input wire writeEnableID,
  input wire [4:0] writeRegID,
  input wire [31:0] writeDataID,
  output reg writeEnableEX,
  output reg [4:0] writeRegEX,
  output reg [31:0] writeDataEX,

  input wire [7:0] memOpID,
  input wire [31:0] memWriteDataID,
  output reg [7:0] memOpEX,
  output reg [31:0] memWriteDataEX,

  input wire [31:0] busAID,
  input wire [31:0] busBID,
  input wire [7:0] aluOpID,
  input wire [1:0] aluDstID,
  output reg [31:0] busAEX,
  output reg [31:0] busBEX,
  output reg [7:0] aluOpEX,
  output reg [1:0] aluDstEX,

  // CSR 控制信号
  input  wire        csrOpID,
  input  wire [13:0] csrNumID,
  output reg         csrOpEX,
  output reg  [13:0] csrNumEX
);

  always @(posedge clk) begin
    if (rst) begin
      writeEnableEX <= 1'b0;
      writeRegEX <= 5'h0;
      writeDataEX <= 32'h0;
      memOpEX <= 3'h0;
      memWriteDataEX <= 32'h0;
      busAEX <= 32'h0;
      busBEX <= 32'h0;
      aluOpEX <= 3'h0;
      aluDstEX <= 2'h0;
      csrOpEX   <= 1'b0;
      csrNumEX  <= 14'h0;
    end else if (hold) begin
      // Keep the current EX request stable until the memory side accepts it.
    end else if (!bubble) begin
      writeEnableEX <= writeEnableID;
      writeRegEX <= writeRegID;
      writeDataEX <= writeDataID;
      memOpEX <= memOpID;
      memWriteDataEX <= memWriteDataID;
      busAEX <= busAID;
      busBEX <= busBID;
      aluOpEX <= aluOpID;
      aluDstEX <= aluDstID;
      csrOpEX   <= csrOpID;
      csrNumEX  <= csrNumID;
    end else begin
      // stall=1: 插入 NOP 气泡, 防止后续指令提前进入 EX
      writeEnableEX <= 1'b0;
      writeRegEX <= 5'h0;
      writeDataEX <= 32'h0;
      memOpEX <= 3'h0;
      memWriteDataEX <= 32'h0;
      busAEX <= 32'h0;
      busBEX <= 32'h0;
      aluOpEX <= 3'h0;
      aluDstEX <= 2'h0;
      csrOpEX   <= 1'b0;
      csrNumEX  <= 14'h0;
    end
  end

endmodule
