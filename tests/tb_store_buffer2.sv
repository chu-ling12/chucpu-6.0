module tb_store_buffer2;
  reg clk = 1'b0;
  reg rst = 1'b1;
  reg dataRead = 1'b0;
  reg dataWrite = 1'b0;
  reg [31:0] dataAddress = 32'h0;
  reg [31:0] dataWriteData = 32'h0;
  reg [3:0] dataByteEnable = 4'h0;
  reg dataChipSelect = 1'b0;
  reg dataBaseSelect = 1'b0;
  wire requestReady;
  wire responseValid;
  wire [31:0] readData;
  wire instrHold;
  wire [31:0] baseBus;
  wire [19:0] baseAddr;
  wire [3:0] baseBeN;
  wire baseOeN;
  wire baseWeN;
  wire [31:0] extBus;
  wire [19:0] extAddr;
  wire [3:0] extBeN;
  wire extOeN;
  wire extWeN;
  reg [31:0] baseMem [0:31];
  reg [31:0] extMem [0:31];
  integer i;

  RAM dut(
    .clk(clk), .rst(rst), .txd(), .rxd(1'b1),
    .instrMemAddress(32'h1c000000),
    .instrMemAddressNext(32'h1c000004), .instrMemData(),
    .dataMemReadEnable(dataRead), .dataMemWriteEnable(dataWrite),
    .dataMemRequestReady(requestReady),
    .dataMemResponseValid(responseValid), .dataMemReadData(readData),
    .dataMemWriteData(dataWriteData), .dataMemAddress(dataAddress),
    .dataMemByteEnable(dataByteEnable),
    .dataMemChipSelect(dataChipSelect),
    .dataMemBaseRamSelect(dataBaseSelect),
    .dataMemExtRamSelect(dataChipSelect && !dataBaseSelect),
    .dataMemUartSelect(1'b0), .instrMemHold(instrHold),
    .icacheReadRequest(1'b0), .icacheReadAddress(32'h0),
    .icacheReadRequestReady(), .icacheReadResponseValid(),
    .icacheReadData(), .base_ram_data(baseBus),
    .base_ram_addr(baseAddr), .base_ram_be_n(baseBeN),
    .base_ram_ce_n(), .base_ram_oe_n(baseOeN),
    .base_ram_we_n(baseWeN), .ext_ram_data(extBus),
    .ext_ram_addr(extAddr), .ext_ram_be_n(extBeN),
    .ext_ram_ce_n(), .ext_ram_oe_n(extOeN), .ext_ram_we_n(extWeN)
  );

  always #5 clk = ~clk;
  assign baseBus = (!baseOeN && baseWeN) ? baseMem[baseAddr] : 32'hzzzzzzzz;
  assign extBus = (!extOeN && extWeN) ? extMem[extAddr] : 32'hzzzzzzzz;

  always @(posedge clk) begin
    if (!baseWeN) begin
      if (!baseBeN[0]) baseMem[baseAddr][7:0] <= baseBus[7:0];
      if (!baseBeN[1]) baseMem[baseAddr][15:8] <= baseBus[15:8];
      if (!baseBeN[2]) baseMem[baseAddr][23:16] <= baseBus[23:16];
      if (!baseBeN[3]) baseMem[baseAddr][31:24] <= baseBus[31:24];
    end
  end

  task store(input [31:0] address, input [31:0] value,
             input [3:0] byteEnable);
    begin
      @(negedge clk);
      dataChipSelect = 1'b1;
      dataWrite = 1'b1;
      dataBaseSelect = 1'b1;
      dataAddress = address;
      dataWriteData = value;
      dataByteEnable = byteEnable;
      while (!requestReady) @(negedge clk);
      @(negedge clk);
      dataChipSelect = 1'b0;
      dataWrite = 1'b0;
    end
  endtask

  task load(input [31:0] address, input [3:0] byteEnable,
            input [31:0] expected);
    begin
      @(negedge clk);
      dataChipSelect = 1'b1;
      dataRead = 1'b1;
      dataBaseSelect = 1'b1;
      dataAddress = address;
      dataByteEnable = byteEnable;
      while (!requestReady) @(negedge clk);
      @(negedge clk);
      dataChipSelect = 1'b0;
      dataRead = 1'b0;
      wait (responseValid);
      #1;
      if (readData !== expected)
        $fatal(1, "load mismatch got=%08x expected=%08x", readData, expected);
    end
  endtask

  initial begin
    for (i = 0; i < 32; i = i + 1) begin
      baseMem[i] = 32'h0;
      extMem[i] = 32'h0;
    end
    repeat (3) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    store(32'h1c000020, 32'h11223344, 4'hf);
    store(32'h1c000024, 32'h55667788, 4'hf);
    load(32'h1c000024, 4'hf, 32'h55667788);
    wait (dut.sbCount == 0 && dut.busState == 0);
    if (baseMem[8] !== 32'h11223344 || baseMem[9] !== 32'h55667788)
      $fatal(1, "FIFO drain order/data mismatch");
    store(32'h1c000028, 32'h000000aa, 4'b0001);
    load(32'h1c000028, 4'b0001, 32'h000000aa);
    $display("PASS two-entry store buffer FIFO and forwarding");
    $finish;
  end
endmodule
