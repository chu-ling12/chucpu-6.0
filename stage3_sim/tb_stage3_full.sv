module tb_stage3_full;
  localparam KERNEL_WORDS = 2242;
  localparam HOST_BYTES = 152;

  reg clk = 1'b0;
  reg rst = 1'b1;
  wire [31:0] instr_addr;
  wire [31:0] instr_addr_next;
  wire [31:0] instr_data;
  wire data_read;
  wire data_write;
  wire [31:0] data_rdata;
  wire [31:0] data_wdata;
  wire [31:0] data_addr;
  wire [3:0] data_be;
  wire data_cs;
  wire data_base;
  wire data_ext;
  wire data_uart;
  wire data_ready;
  wire data_response_valid;
  wire instr_hold;
  wire [31:0] base_bus;
  wire [19:0] base_addr;
  wire [3:0] base_be_n;
  wire base_ce_n;
  wire base_oe_n;
  wire base_we_n;
  wire [31:0] ext_bus;
  wire [19:0] ext_addr;
  wire [3:0] ext_be_n;
  wire ext_ce_n;
  wire ext_oe_n;
  wire ext_we_n;
  wire txd;
  wire [31:0] instr_pa;
  wire [31:0] instr_pa_next;
  wire instr_cached;
  wire cacop_inv;
  wire [31:0] cacop_addr;
  wire icache_stall;
  wire icache_req;
  wire [31:0] icache_addr;
  wire icache_ready;
  wire icache_valid;
  wire [31:0] icache_cpu_data;
  wire [31:0] icache_ram_data;
  wire ram_instr_hold;
  wire [31:0] ram_instr_data;
  wire base_store_fire = data_write && data_ready && data_base;
  assign instr_data = instr_cached ? icache_cpu_data : ram_instr_data;
  assign instr_hold = icache_stall || (!instr_cached && ram_instr_hold);

  reg [31:0] base_mem [0:270000];
  reg [31:0] ext_mem [0:1048575];
  reg [7:0] host_stream [0:HOST_BYTES-1];
  reg [7:0] tx_stream [0:255];
  integer tx_count = 0;
  integer user_writes = 0;
  integer cycles = 0;
  integer uart_reads = 0;
  integer base_reads = 0;
  integer wb_writes = 0;
  integer uart_pops = 0;
  integer post_boot_writes = 0;
  integer cached_cycles = 0;
  integer icache_requests = 0;
  integer icache_responses = 0;
  integer csr_writes = 0;
  integer i;
  integer bht_i;
  integer conditional_branches = 0;
  integer static_mispredicts = 0;
  integer bht16_mispredicts = 0;
  integer bht32_mispredicts = 0;
  integer bht64_mispredicts = 0;
  integer bht128_mispredicts = 0;
  reg [1:0] bht16 [0:15];
  reg [1:0] bht32 [0:31];
  reg [1:0] bht64 [0:63];
  reg [1:0] bht128 [0:127];
  reg bht16_valid [0:15];
  reg bht32_valid [0:31];
  reg bht64_valid [0:63];
  reg bht128_valid [0:127];

  CPU cpu(
    .clk(clk), .rst(rst),
    .instrMemAddress(instr_addr), .instrMemAddressNext(instr_addr_next),
    .instrMemPhysicalAddress(instr_pa),
    .instrMemPhysicalAddressNext(instr_pa_next),
    .instrMemCached(instr_cached),
    .cacopInvalidate(cacop_inv), .cacopAddress(cacop_addr),
    .instrMemData(instr_data), .dataMemReadEnable(data_read),
    .dataMemWriteEnable(data_write), .dataMemRequestReady(data_ready),
    .dataMemResponseValid(data_response_valid), .dataMemReadData(data_rdata),
    .dataMemWriteData(data_wdata), .dataMemAddress(data_addr),
    .dataMemByteEnable(data_be), .dataMemChipSelect(data_cs),
    .dataMemBaseRamSelect(data_base), .dataMemExtRamSelect(data_ext),
    .dataMemUartSelect(data_uart), .instrMemHold(instr_hold)
  );

  ICache icache(
    .clk(clk), .rst(rst), .cpu_addr(instr_pa), .cpu_cached(instr_cached),
    .cpu_data(icache_cpu_data), .stall_req(icache_stall),
    .ram_req(icache_req), .ram_addr(icache_addr),
    .ram_req_ready(icache_ready), .ram_resp_valid(icache_valid),
    .ram_data(icache_ram_data), .invalidate_en(base_store_fire),
    .invalidate_addr(data_addr), .cacop_inv_en(cacop_inv),
    .cacop_inv_addr(cacop_addr)
  );

  RAM ram(
    .clk(clk), .rst(rst), .txd(txd), .rxd(1'b1),
    .instrMemAddress(instr_pa), .instrMemAddressNext(instr_pa_next),
    .instrMemData(ram_instr_data), .dataMemReadEnable(data_read),
    .dataMemWriteEnable(data_write), .dataMemRequestReady(data_ready),
    .dataMemResponseValid(data_response_valid), .dataMemReadData(data_rdata),
    .dataMemWriteData(data_wdata), .dataMemAddress(data_addr),
    .dataMemByteEnable(data_be), .dataMemChipSelect(data_cs),
    .dataMemBaseRamSelect(data_base), .dataMemExtRamSelect(data_ext),
    .dataMemUartSelect(data_uart), .instrMemHold(ram_instr_hold),
    .icacheReadRequest(icache_req), .icacheReadAddress(icache_addr),
    .icacheReadRequestReady(icache_ready),
    .icacheReadResponseValid(icache_valid), .icacheReadData(icache_ram_data),
    .base_ram_data(base_bus),
    .base_ram_addr(base_addr), .base_ram_be_n(base_be_n),
    .base_ram_ce_n(base_ce_n), .base_ram_oe_n(base_oe_n),
    .base_ram_we_n(base_we_n), .ext_ram_data(ext_bus),
    .ext_ram_addr(ext_addr), .ext_ram_be_n(ext_be_n),
    .ext_ram_ce_n(ext_ce_n), .ext_ram_oe_n(ext_oe_n),
    .ext_ram_we_n(ext_we_n)
  );

  always #5 clk = ~clk;
  assign base_bus = (!base_ce_n && !base_oe_n && base_we_n) ? base_mem[base_addr] : 32'hzzzzzzzz;
  assign ext_bus = (!ext_ce_n && !ext_oe_n && ext_we_n) ? ext_mem[ext_addr] : 32'hzzzzzzzz;

  always @(posedge clk) begin
    cycles <= cycles + 1;
    if (instr_cached) cached_cycles <= cached_cycles + 1;
    if (icache_req && icache_ready) icache_requests <= icache_requests + 1;
    if (icache_valid) icache_responses <= icache_responses + 1;
    if (cpu.u_csr.csr_we) begin
      csr_writes <= csr_writes + 1;
      $display("CSR_WRITE cycle=%0d addr=%04x data=%08x",
               cycles, cpu.u_csr.csr_waddr, cpu.u_csr.csr_wdata);
    end
    if (!base_ce_n && !base_we_n) begin
      if (!base_be_n[0]) base_mem[base_addr][7:0] <= base_bus[7:0];
      if (!base_be_n[1]) base_mem[base_addr][15:8] <= base_bus[15:8];
      if (!base_be_n[2]) base_mem[base_addr][23:16] <= base_bus[23:16];
      if (!base_be_n[3]) base_mem[base_addr][31:24] <= base_bus[31:24];
      if (base_addr >= 20'h40000 && base_addr < 20'h4000b) begin
        user_writes <= user_writes + 1;
        $display("USER_WRITE cycle=%0d addr=%08x be=%x data=%08x", cycles,
                 {10'h070, base_addr, 2'b00}, ~base_be_n, base_bus);
      end
    end
    if (!ext_ce_n && !ext_we_n) begin
      if (!ext_be_n[0]) ext_mem[ext_addr][7:0] <= ext_bus[7:0];
      if (!ext_be_n[1]) ext_mem[ext_addr][15:8] <= ext_bus[15:8];
      if (!ext_be_n[2]) ext_mem[ext_addr][23:16] <= ext_bus[23:16];
      if (!ext_be_n[3]) ext_mem[ext_addr][31:24] <= ext_bus[31:24];
    end
    if (cycles > 200000 && data_write) begin
      post_boot_writes <= post_boot_writes + 1;
      if (post_boot_writes < 100)
        $display("DATA_WRITE cycle=%0d addr=%08x be=%x data=%08x base=%b ext=%b uart=%b pc=%08x",
                 cycles, data_addr, data_be, data_wdata, data_base, data_ext,
                 data_uart, instr_addr);
    end
    if (data_read && data_uart) begin
      uart_reads <= uart_reads + 1;
      if (uart_reads < 30)
        $display("UART_READ cycle=%0d addr=%08x data=%08x pc=%08x", cycles,
                 data_addr, data_rdata, instr_addr);
    end
    if (data_read && data_base) begin
      base_reads <= base_reads + 1;
      if (base_reads < 30)
        $display("BASE_READ cycle=%0d addr=%08x data=%08x pc=%08x", cycles,
                 data_addr, data_rdata, instr_addr);
    end
    if (cpu.regWriteEnable) begin
      wb_writes <= wb_writes + 1;
      if (cycles > 340 && cycles < 430)
        $display("WB cycle=%0d reg=%0d data=%08x mdop=%02x mdaddr=%08x rdata=%08x",
                 cycles, cpu.regWriteReg, cpu.regWriteData, cpu.mdMemOp,
                 cpu.mdMemAddress, data_rdata);
    end
    if (cycles > 200000 && cpu.regWriteEnable && cpu.mdMemOp == 8'h01)
      $display("LOAD_BYTE_WB cycle=%0d reg=%0d value=%08x addr=%08x pc=%08x",
               cycles, cpu.regWriteReg, cpu.regWriteData, cpu.mdMemAddress,
               instr_addr);
    if (ram.txdStart) begin
      tx_stream[tx_count] <= ram.txdData;
      tx_count <= tx_count + 1;
      if (tx_count >= 37)
        $display("TX cycle=%0d index=%0d byte=%02x pc=%08x", cycles, tx_count,
                 ram.txdData, instr_addr);
    end
    if (ram.rxdFifoPop) begin
      uart_pops <= uart_pops + 1;
      if (uart_pops < 180)
        $display("RX_POP cycle=%0d index=%0d byte=%02x count=%0d pc=%08x",
                 cycles, uart_pops, ram.rxdFifoDout, ram.rxdCount, instr_addr);
    end
    if (cpu.branchDecisionValid && (cpu.id2BranchType >= 3'd3) &&
        !cpu.exMemWait && !instr_hold && !cpu.loadPipelineHold) begin
      conditional_branches <= conditional_branches + 1;
      if (cpu.id2PredictedTaken != cpu.branchResolved)
        static_mispredicts <= static_mispredicts + 1;
      if ((bht16_valid[cpu.id2Pc[5:2]] ? bht16[cpu.id2Pc[5:2]][1] :
           cpu.id2PredictedTaken) != cpu.branchResolved)
        bht16_mispredicts <= bht16_mispredicts + 1;
      if ((bht32_valid[cpu.id2Pc[6:2]] ? bht32[cpu.id2Pc[6:2]][1] :
           cpu.id2PredictedTaken) != cpu.branchResolved)
        bht32_mispredicts <= bht32_mispredicts + 1;
      if ((bht64_valid[cpu.id2Pc[7:2]] ? bht64[cpu.id2Pc[7:2]][1] :
           cpu.id2PredictedTaken) != cpu.branchResolved)
        bht64_mispredicts <= bht64_mispredicts + 1;
      if ((bht128_valid[cpu.id2Pc[8:2]] ? bht128[cpu.id2Pc[8:2]][1] :
           cpu.id2PredictedTaken) != cpu.branchResolved)
        bht128_mispredicts <= bht128_mispredicts + 1;

      bht16_valid[cpu.id2Pc[5:2]] <= 1'b1;
      bht32_valid[cpu.id2Pc[6:2]] <= 1'b1;
      bht64_valid[cpu.id2Pc[7:2]] <= 1'b1;
      bht128_valid[cpu.id2Pc[8:2]] <= 1'b1;
      if (cpu.branchResolved) begin
        if (bht16[cpu.id2Pc[5:2]] != 2'b11)
          bht16[cpu.id2Pc[5:2]] <= bht16[cpu.id2Pc[5:2]] + 2'b01;
        if (bht32[cpu.id2Pc[6:2]] != 2'b11)
          bht32[cpu.id2Pc[6:2]] <= bht32[cpu.id2Pc[6:2]] + 2'b01;
        if (bht64[cpu.id2Pc[7:2]] != 2'b11)
          bht64[cpu.id2Pc[7:2]] <= bht64[cpu.id2Pc[7:2]] + 2'b01;
        if (bht128[cpu.id2Pc[8:2]] != 2'b11)
          bht128[cpu.id2Pc[8:2]] <= bht128[cpu.id2Pc[8:2]] + 2'b01;
      end else begin
        if (bht16[cpu.id2Pc[5:2]] != 2'b00)
          bht16[cpu.id2Pc[5:2]] <= bht16[cpu.id2Pc[5:2]] - 2'b01;
        if (bht32[cpu.id2Pc[6:2]] != 2'b00)
          bht32[cpu.id2Pc[6:2]] <= bht32[cpu.id2Pc[6:2]] - 2'b01;
        if (bht64[cpu.id2Pc[7:2]] != 2'b00)
          bht64[cpu.id2Pc[7:2]] <= bht64[cpu.id2Pc[7:2]] - 2'b01;
        if (bht128[cpu.id2Pc[8:2]] != 2'b00)
          bht128[cpu.id2Pc[8:2]] <= bht128[cpu.id2Pc[8:2]] - 2'b01;
      end
    end
    if (1'b0) begin
      $display("PIPE cycle=%0d pc=%08x hold=%b br=%b/%b ex_we=%b ex_r=%0d ex_wd=%08x ex_op=%02x ex_addr=%08x ma_we=%b ma_r=%0d ma_wd=%08x ma_op=%02x ma_addr=%08x md_we=%b md_r=%0d md_wd=%08x md_op=%02x md_addr=%08x wb_we=%b wb_r=%0d wb_wd=%08x req_r=%b req_w=%b req_addr=%08x req_sel=%b%b%b ready=%b rsp=%b bus=%0d sb=%b pop=%b rdata=%08x",
               cycles, instr_addr, cpu.frontendHold, cpu.branchResolved,
               cpu.branchCommit, cpu.exWriteEnable, cpu.exWriteReg,
               cpu.exWriteData, cpu.exMemOp, cpu.exMemAddress,
               cpu.memWriteEnable, cpu.memWriteReg, cpu.memWriteDataIn,
               cpu.memMemOp, cpu.memMemAddress, cpu.mdWriteEnable,
               cpu.mdWriteReg, cpu.mdWriteDataIn, cpu.mdMemOp,
               cpu.mdMemAddress, cpu.regWriteEnable, cpu.regWriteReg,
               cpu.regWriteData, data_read, data_write, data_addr,
               data_base, data_ext, data_uart, data_ready,
               data_response_valid, ram.busState, (ram.sbCount != 0),
               ram.rxdFifoPop, data_rdata);
    end
  end

  task inject_rx(input [7:0] value);
    begin
      force ram.rxdData = value;
      force ram.rxdDataReady = 1'b1;
      @(posedge clk);
      #1;
      release ram.rxdDataReady;
      release ram.rxdData;
      repeat (440) @(posedge clk);
    end
  endtask

  initial begin
    for (bht_i = 0; bht_i < 128; bht_i = bht_i + 1) begin
      if (bht_i < 16) begin
        bht16[bht_i] = 2'b01;
        bht16_valid[bht_i] = 1'b0;
      end
      if (bht_i < 32) begin
        bht32[bht_i] = 2'b01;
        bht32_valid[bht_i] = 1'b0;
      end
      if (bht_i < 64) begin
        bht64[bht_i] = 2'b01;
        bht64_valid[bht_i] = 1'b0;
      end
      bht128[bht_i] = 2'b01;
      bht128_valid[bht_i] = 1'b0;
    end
    for (i = 0; i < 270001; i = i + 1)
      base_mem[i] = 32'h00000000;
    for (i = 1044480; i < 1048576; i = i + 1)
      ext_mem[i] = 32'h00000000;
    ext_mem[20'hfc020] = 32'h1f000000;
    ext_mem[20'hfc021] = 32'h1f000005;
    $readmemh("kernel_words.hex", base_mem, 0, KERNEL_WORDS-1);
    $readmemh("host_bytes.hex", host_stream, 0, HOST_BYTES-1);
    repeat (10) @(posedge clk);
    rst = 1'b0;

    repeat (200000) @(posedge clk);
    $display("PRE_INJECT cycle=%0d pc=%08x tx_count=%0d uart_reads=%0d", cycles,
             instr_addr, tx_count, uart_reads);

    for (i = 0; i < HOST_BYTES; i = i + 1)
      inject_rx(host_stream[i]);

    repeat (200000) @(posedge clk);
    $display("TIMEOUT cycles=%0d pc=%08x tx_count=%0d user_writes=%0d", cycles,
             instr_addr, tx_count, user_writes);
    $display("ICACHE_STATS cached_cycles=%0d requests=%0d responses=%0d csr_writes=%0d crmd=%08x dmw0=%08x dmw1=%08x",
             cached_cycles, icache_requests, icache_responses, csr_writes,
             cpu.u_csr.crmd, cpu.u_csr.dmw0, cpu.u_csr.dmw1);
    $display("BHT_STATS branches=%0d static=%0d bht16=%0d bht32=%0d bht64=%0d bht128=%0d",
             conditional_branches, static_mispredicts, bht16_mispredicts,
             bht32_mispredicts, bht64_mispredicts, bht128_mispredicts);
    $display("UART read=%b write=%b addr=%08x rxd_count=%0d", data_read,
             data_write, data_addr, ram.rxdCount);
    $finish;
  end

  initial begin
    repeat (2000000) @(posedge clk);
    $display("GLOBAL_TIMEOUT pc=%08x tx_count=%0d user_writes=%0d", instr_addr,
             tx_count, user_writes);
    $finish;
  end
endmodule
