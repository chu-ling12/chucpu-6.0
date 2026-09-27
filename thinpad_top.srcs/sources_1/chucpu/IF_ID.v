module IF_ID(
  input wire clk,
  input wire rst,
  input wire hold,
  input wire flush,

  input wire [31:0] pcIF,
  input wire [31:0] instrIF,
  input wire predictedTakenIF,
  output reg validID,
  output reg [31:0] pcID,
  output reg [31:0] instrID,
  output reg predictedTakenID
);

  always @(posedge clk) begin
    if (rst || flush) begin
      validID <= 1'b0;
      pcID <= 32'h0;
      instrID <= 32'h0;
      predictedTakenID <= 1'b0;
    end else if (!hold) begin
      validID <= 1'b1;
      pcID <= pcIF;
      instrID <= instrIF;
      predictedTakenID <= predictedTakenIF;
    end
  end

endmodule
