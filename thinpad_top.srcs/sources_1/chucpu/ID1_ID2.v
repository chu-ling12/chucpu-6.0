module ID1_ID2(
  input wire clk,
  input wire rst,
  input wire hold,
  input wire flush,

  input wire validIn,
  input wire [31:0] pcIn,
  input wire predictedTakenIn,
  input wire src1EnableIn,
  input wire [4:0] src1RegIn,
  input wire src2EnableIn,
  input wire [4:0] src2RegIn,
  input wire writeEnableIn,
  input wire [4:0] writeRegIn,
  input wire [31:0] writeDataIn,
  input wire [1:0] op1SelIn,
  input wire [1:0] op2SelIn,
  input wire [31:0] immediateIn,
  input wire [7:0] aluOpIn,
  input wire [1:0] aluDstIn,
  input wire [7:0] memOpIn,
  input wire [2:0] branchTypeIn,
  input wire [2:0] specialOpIn,
  input wire [13:0] csrNumIn,

  output reg validOut,
  output reg [31:0] pcOut,
  output reg predictedTakenOut,
  output reg src1EnableOut,
  output reg [4:0] src1RegOut,
  output reg src2EnableOut,
  output reg [4:0] src2RegOut,
  output reg writeEnableOut,
  output reg [4:0] writeRegOut,
  output reg [31:0] writeDataOut,
  output reg [1:0] op1SelOut,
  output reg [1:0] op2SelOut,
  output reg [31:0] immediateOut,
  output reg [7:0] aluOpOut,
  output reg [1:0] aluDstOut,
  output reg [7:0] memOpOut,
  output reg [2:0] branchTypeOut,
  output reg [2:0] specialOpOut,
  output reg [13:0] csrNumOut
);

  always @(posedge clk) begin
    if (rst || flush) begin
      validOut <= 1'b0;
      pcOut <= 32'h0;
      predictedTakenOut <= 1'b0;
      src1EnableOut <= 1'b0;
      src1RegOut <= 5'h0;
      src2EnableOut <= 1'b0;
      src2RegOut <= 5'h0;
      writeEnableOut <= 1'b0;
      writeRegOut <= 5'h0;
      writeDataOut <= 32'h0;
      op1SelOut <= 2'h0;
      op2SelOut <= 2'h0;
      immediateOut <= 32'h0;
      aluOpOut <= 8'h0;
      aluDstOut <= 2'h0;
      memOpOut <= 8'h0;
      branchTypeOut <= 3'h0;
      specialOpOut <= 3'h0;
      csrNumOut <= 14'h0;
    end else if (!hold) begin
      validOut <= validIn;
      pcOut <= pcIn;
      predictedTakenOut <= predictedTakenIn;
      src1EnableOut <= src1EnableIn;
      src1RegOut <= src1RegIn;
      src2EnableOut <= src2EnableIn;
      src2RegOut <= src2RegIn;
      writeEnableOut <= writeEnableIn;
      writeRegOut <= writeRegIn;
      writeDataOut <= writeDataIn;
      op1SelOut <= op1SelIn;
      op2SelOut <= op2SelIn;
      immediateOut <= immediateIn;
      aluOpOut <= aluOpIn;
      aluDstOut <= aluDstIn;
      memOpOut <= memOpIn;
      branchTypeOut <= branchTypeIn;
      specialOpOut <= specialOpIn;
      csrNumOut <= csrNumIn;
    end
  end

endmodule
