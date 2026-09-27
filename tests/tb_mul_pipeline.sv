`include "ALUOp.vh"

module tb_mul_pipeline;
  reg clk = 1'b0;
  reg rst = 1'b1;
  reg [31:0] busA = 32'h0;
  reg [31:0] busB = 32'h0;
  reg [7:0] aluOp = 8'h0;
  wire [31:0] aluOut;
  wire mulStall;
  integer stalledCycles;

  ALU dut(
    .clk(clk), .rst(rst), .busA(busA), .busB(busB), .aluOp(aluOp),
    .aluOut(aluOut), .mulStall(mulStall)
  );

  always #5 clk = ~clk;

  initial begin
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    busA = 32'hfffffff9;
    busB = 32'd11;
    aluOp = `ALU_MUL;
    stalledCycles = 0;
    #1;
    while (mulStall) begin
      @(posedge clk);
      #1;
      stalledCycles = stalledCycles + 1;
      if (stalledCycles > 5)
        $fatal(1, "multiplier did not complete");
    end
    if (stalledCycles != 1)
      $fatal(1, "unexpected pipeline latency: %0d", stalledCycles);
    if (aluOut !== 32'hffffffb3)
      $fatal(1, "bad product: %08x", aluOut);
    @(negedge clk);
    aluOp = `ALU_ADD;
    busA = 32'h1;
    busB = 32'h3;
    #1;
    if (mulStall || (aluOut !== 32'h4))
      $fatal(1, "non-multiply ALU operation failed");
    $display("PASS registered multiplier latency=%0d", stalledCycles);
    $finish;
  end
endmodule
