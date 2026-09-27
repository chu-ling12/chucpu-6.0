module MA_MD(
  input wire clk,
  input wire rst,
  input wire hold,

  input wire writeEnableMA,
  input wire [4:0] writeRegMA,
  input wire [31:0] writeDataMA,
  input wire [7:0] memOpMA,
  input wire [31:0] memAddressMA,

  output reg writeEnableMD,
  output reg [4:0] writeRegMD,
  output reg [31:0] writeDataMD,
  output reg [7:0] memOpMD,
  output reg [31:0] memAddressMD
);

  always @(posedge clk) begin
    if (rst) begin
      writeEnableMD <= 1'b0;
      writeRegMD <= 5'h0;
      writeDataMD <= 32'h0;
      memOpMD <= 8'h0;
      memAddressMD <= 32'h0;
    end else if (!hold) begin
      writeEnableMD <= writeEnableMA;
      writeRegMD <= writeRegMA;
      writeDataMD <= writeDataMA;
      memOpMD <= memOpMA;
      memAddressMD <= memAddressMA;
    end
  end

endmodule
