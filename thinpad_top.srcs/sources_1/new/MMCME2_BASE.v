// Xilinx 7-Series MMCME2_BASE Primitive Stub for Verilator Lint
module MMCME2_BASE #(
  parameter BANDWIDTH          = "OPTIMIZED",
  parameter CLKIN1_PERIOD      = 0.000,
  parameter DIVCLK_DIVIDE      = 1,
  parameter CLKFBOUT_MULT_F    = 5.000,
  parameter CLKOUT0_DIVIDE_F   = 1.000,
  parameter CLKOUT0_DUTY_CYCLE = 0.500,
  parameter CLKOUT0_PHASE      = 0.000,
  parameter STARTUP_WAIT       = "FALSE"
) (
  input  wire CLKIN1,
  input  wire CLKFBIN,
  input  wire RST,
  input  wire PWRDWN,
  output wire CLKFBOUT,
  output wire CLKOUT0,
  output wire LOCKED
);
  assign CLKFBOUT = CLKIN1;
  assign CLKOUT0  = CLKIN1;
  assign LOCKED   = ~RST;
endmodule
