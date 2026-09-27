// Xilinx 7-Series Primitives Stubs
module IOBUF(input wire I, input wire T, output wire O, inout wire IO);
  assign IO = T ? 1'bz : I;
  assign O = IO;
endmodule

module IBUF(input wire I, output wire O);
  assign O = I;
endmodule

module BUFG(input wire I, output wire O);
  assign O = I;
endmodule

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

module fifo_generator_0(
  input wire clk,
  input wire rst,
  input wire [7:0] din,
  input wire wr_en,
  input wire rd_en,
  output wire [7:0] dout,
  output wire full,
  output wire empty
);
  reg [7:0] mem [0:31];
  reg [5:0] count;
  reg [4:0] rptr;
  reg [4:0] wptr;
  assign dout = mem[rptr];
  assign empty = (count == 0);
  assign full = (count == 32);
  always @(posedge clk) begin
    if (rst) begin
      count <= 0;
      rptr <= 0;
      wptr <= 0;
    end else begin
      case ({wr_en && !full, rd_en && !empty})
        2'b10: begin mem[wptr] <= din; wptr <= wptr + 1'b1; count <= count + 1'b1; end
        2'b01: begin rptr <= rptr + 1'b1; count <= count - 1'b1; end
        2'b11: begin mem[wptr] <= din; wptr <= wptr + 1'b1; rptr <= rptr + 1'b1; end
        default: begin end
      endcase
    end
  end
endmodule

module async_receiver(
  input wire clk,
  input wire RxD,
  output wire RxD_data_ready,
  input wire RxD_clear,
  output wire [7:0] RxD_data
);
  parameter ClkFrequency = 50000000;
  parameter Baud = 115200;
  assign RxD_data_ready = 1'b0;
  assign RxD_data = 8'h0;
endmodule

module async_transmitter(
  input wire clk,
  input wire TxD_start,
  input wire [7:0] TxD_data,
  output wire TxD,
  output wire TxD_busy
);
  parameter ClkFrequency = 50000000;
  parameter Baud = 115200;
  assign TxD = 1'b1;
  assign TxD_busy = 1'b0;
endmodule
