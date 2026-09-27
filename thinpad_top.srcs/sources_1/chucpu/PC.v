module PC(
  input wire clk,
  input wire rst,
  input wire hold,
  input wire branch,
  input wire [31:0] branchAddress,
  input wire predictTaken,
  input wire [31:0] predictAddress,
  output reg [31:0] pc
);

  always @(posedge clk) begin
    if (rst) begin
      pc <= 32'h1C000000;
    end else if (branch) begin
      pc <= branchAddress;
    end else if (!hold) begin
      pc <= predictTaken ? predictAddress : pc + 32'd4;
    end
  end

endmodule
