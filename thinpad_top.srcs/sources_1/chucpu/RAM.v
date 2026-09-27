module RAM(
  input wire clk,
  input wire rst,

  output wire txd,
  input wire rxd,

  input wire [31:0] instrMemAddress,
  input wire [31:0] instrMemAddressNext,
  output reg [31:0] instrMemData,

  input wire dataMemReadEnable,
  input wire dataMemWriteEnable,
  output wire dataMemRequestReady,
  output reg dataMemResponseValid,
  output reg [31:0] dataMemReadData,
  input wire [31:0] dataMemWriteData,
  input wire [31:0] dataMemAddress,
  input wire [3:0] dataMemByteEnable,
  input wire dataMemChipSelect,
  input wire dataMemBaseRamSelect,
  input wire dataMemExtRamSelect,
  input wire dataMemUartSelect,
  output wire instrMemHold,

  input wire icacheReadRequest,
  input wire [31:0] icacheReadAddress,
  output wire icacheReadRequestReady,
  output reg icacheReadResponseValid,
  output reg [31:0] icacheReadData,

  inout wire [31:0] base_ram_data,
  output wire [19:0] base_ram_addr,
  output wire [3:0] base_ram_be_n,
  output wire base_ram_ce_n,
  output wire base_ram_oe_n,
  output wire base_ram_we_n,

  inout wire [31:0] ext_ram_data,
  output wire [19:0] ext_ram_addr,
  output wire [3:0] ext_ram_be_n,
  output wire ext_ram_ce_n,
  output wire ext_ram_oe_n,
  output wire ext_ram_we_n
);

  parameter CLK_FREQ = 50000000;
  parameter BAUD = 115200;

  localparam BUS_IDLE = 2'd0;
  localparam BUS_BASE_READ = 2'd1;
  localparam BUS_EXT_READ = 2'd2;
  localparam BUS_STORE = 2'd3;

  (* DONT_TOUCH = "TRUE", max_fanout = 256 *) reg ramRst;
  always @(posedge clk or posedge rst) begin
    if (rst)
      ramRst <= 1'b1;
    else
      ramRst <= 1'b0;
  end

  reg [1:0] busState;
  reg busReadIsICache;

  // Two-entry FIFO; the head entry remains valid while its SRAM write runs.
  reg [1:0] sbCount;
  reg sbHead;
  reg sbTail;
  reg sbBase [0:1];
  reg sbExt [0:1];
  reg [31:0] sbAddress [0:1];
  reg [31:0] sbWriteData [0:1];
  reg [3:0] sbByteEnable [0:1];

  reg fastReadPending;
  reg [31:0] fastReadData;
  reg responsePending;
  reg [31:0] responseData;

  (* IOB = "TRUE" *) reg [19:0] baseAddrQ;
  (* IOB = "TRUE" *) reg [3:0] baseBeNQ;
  (* IOB = "TRUE" *) reg baseOeNQ;
  (* IOB = "TRUE" *) reg baseWeNQ;
  (* IOB = "TRUE" *) reg [31:0] baseWriteDataQ;
  (* IOB = "TRUE", DONT_TOUCH = "TRUE" *) reg [31:0] baseDataTQ;

  (* IOB = "TRUE" *) reg [19:0] extAddrQ;
  (* IOB = "TRUE" *) reg [3:0] extBeNQ;
  (* IOB = "TRUE" *) reg extOeNQ;
  (* IOB = "TRUE" *) reg extWeNQ;
  (* IOB = "TRUE" *) reg [31:0] extWriteDataQ;
  (* IOB = "TRUE", DONT_TOUCH = "TRUE" *) reg [31:0] extDataTQ;

  wire [31:0] baseRAMOut;
  wire [31:0] extRAMOut;

  wire requestValid = dataMemChipSelect &&
                      (dataMemReadEnable || dataMemWriteEnable);
  wire mappedSram = dataMemBaseRamSelect || dataMemExtRamSelect;
  wire mappedUart = dataMemUartSelect;
  wire sbEmpty = (sbCount == 2'd0);
  wire sbFull = (sbCount == 2'd2);
  wire sbNewest = (sbCount == 2'd2) ? ~sbHead : sbHead;
  wire sbHeadBase = sbBase[sbHead];
  wire sbHeadExt = sbExt[sbHead];
  wire [31:0] sbHeadAddress = sbAddress[sbHead];
  wire [31:0] sbHeadWriteData = sbWriteData[sbHead];
  wire [3:0] sbHeadByteEnable = sbByteEnable[sbHead];
  wire sbNewestSameWord = !sbEmpty &&
                          (sbBase[sbNewest] == dataMemBaseRamSelect) &&
                          (sbExt[sbNewest] == dataMemExtRamSelect) &&
                          (sbAddress[sbNewest][21:2] ==
                           dataMemAddress[21:2]);
  wire sbNewestCoversLoad = sbNewestSameWord &&
                            ((dataMemByteEnable &
                              ~sbByteEnable[sbNewest]) == 4'b0000);
  wire sbHeadSameWord = !sbEmpty &&
                        (sbHeadBase == dataMemBaseRamSelect) &&
                        (sbHeadExt == dataMemExtRamSelect) &&
                        (sbHeadAddress[21:2] == dataMemAddress[21:2]);
  wire sbHeadCoversLoad = sbHeadSameWord &&
                          ((dataMemByteEnable &
                            ~sbHeadByteEnable) == 4'b0000);
  wire canForwardLoad = dataMemReadEnable && mappedSram &&
                        (sbNewestCoversLoad ||
                         (!sbNewestSameWord && sbHeadCoversLoad));
  wire [31:0] forwardedStoreData = sbNewestSameWord ?
                                   sbWriteData[sbNewest] :
                                   sbHeadWriteData;
  wire canAcceptStore = dataMemWriteEnable && mappedSram && !sbFull;
  wire canAcceptLoad = dataMemReadEnable &&
                       ((mappedSram && ((busState == BUS_IDLE && sbEmpty) ||
                                        canForwardLoad)) ||
                        (!mappedSram && !mappedUart));
  wire canAcceptUart = mappedUart && sbEmpty && (busState == BUS_IDLE);
  wire canAcceptUnmappedStore = dataMemWriteEnable && !mappedSram && !mappedUart;

  assign dataMemRequestReady = !requestValid || canAcceptStore ||
                               canAcceptLoad || canAcceptUart ||
                               canAcceptUnmappedStore;

  wire requestFire = requestValid && dataMemRequestReady;
  wire sramStoreFire = requestFire && dataMemWriteEnable && mappedSram;
  wire sramLoadFire = requestFire && dataMemReadEnable && mappedSram;
  wire forwardedLoadFire = sramLoadFire && canForwardLoad;
  wire uartFire = requestFire && mappedUart;
  wire unmappedLoadFire = requestFire && dataMemReadEnable &&
                          !mappedSram && !mappedUart;
  assign icacheReadRequestReady = (busState == BUS_IDLE) && sbEmpty &&
                                  !requestValid;
  wire icacheReadFire = icacheReadRequest && icacheReadRequestReady;

  // BaseRAM stores are fenced until their physical write completes so that
  // self-modifying code cannot fetch stale instructions.
  wire sbHasBase = !sbEmpty &&
                   (sbHeadBase || ((sbCount == 2'd2) && sbBase[~sbHead]));
  assign instrMemHold = (busState == BUS_BASE_READ) || sbHasBase;

  genvar baseBit;
  generate
    for (baseBit = 0; baseBit < 32; baseBit = baseBit + 1) begin : gen_base_iobuf
      IOBUF u_base_iobuf(
        .I(baseWriteDataQ[baseBit]),
        .T(baseDataTQ[baseBit]),
        .O(baseRAMOut[baseBit]),
        .IO(base_ram_data[baseBit])
      );
    end
  endgenerate

  assign base_ram_addr = baseAddrQ;
  assign base_ram_be_n = baseBeNQ;
  assign base_ram_ce_n = 1'b0;
  assign base_ram_oe_n = baseOeNQ;
  assign base_ram_we_n = baseWeNQ;
  always @(*) instrMemData = baseRAMOut;

  genvar extBit;
  generate
    for (extBit = 0; extBit < 32; extBit = extBit + 1) begin : gen_ext_iobuf
      IOBUF u_ext_iobuf(
        .I(extWriteDataQ[extBit]),
        .T(extDataTQ[extBit]),
        .O(extRAMOut[extBit]),
        .IO(ext_ram_data[extBit])
      );
    end
  endgenerate

  assign ext_ram_addr = extAddrQ;
  assign ext_ram_be_n = extBeNQ;
  assign ext_ram_ce_n = 1'b0;
  assign ext_ram_oe_n = extOeNQ;
  assign ext_ram_we_n = extWeNQ;

  localparam RX_FIFO_ADDR_WIDTH = 6;
  localparam RX_FIFO_DEPTH = (1 << RX_FIFO_ADDR_WIDTH);
  reg [7:0] rxdFifoMem [0:RX_FIFO_DEPTH-1];
  reg [RX_FIFO_ADDR_WIDTH-1:0] rxdWritePtr;
  reg [RX_FIFO_ADDR_WIDTH-1:0] rxdReadPtr;
  reg [RX_FIFO_ADDR_WIDTH:0] rxdCount;
  wire rxdFifoEmpty = (rxdCount == 0);
  wire rxdFifoFull = (rxdCount == RX_FIFO_DEPTH);
  wire [7:0] rxdFifoDout = rxdFifoMem[rxdReadPtr];

  reg [7:0] txdHold;
  reg txdHoldValid;
  wire txdReady;
  reg dlab;

  wire rxdDataReady;
  wire rxdClear;
  wire [7:0] rxdData;
  wire txdStart;
  wire [7:0] txdData;
  wire txdBusy;

  wire [3:0] requestUartReg = dataMemAddress[3:0];
  wire [7:0] requestWriteByte =
    (dataMemAddress[1:0] == 2'b00) ? dataMemWriteData[7:0] :
    (dataMemAddress[1:0] == 2'b01) ? dataMemWriteData[15:8] :
    (dataMemAddress[1:0] == 2'b10) ? dataMemWriteData[23:16] :
                                             dataMemWriteData[31:24];
  wire [7:0] requestReadByte =
    ((requestUartReg == 4'h0) && !dlab) ? rxdFifoDout :
    ((requestUartReg == 4'h0) &&  dlab) ? 8'h00 :
    (requestUartReg == 4'h5) ?
      {2'b00, txdReady, 4'h0, !rxdFifoEmpty} : 8'h00;

  wire uartReadFire = uartFire && dataMemReadEnable;
  wire uartWriteFire = uartFire && dataMemWriteEnable;
  wire uartDataReadFire = uartReadFire &&
                          (requestUartReg == 4'h0) && !dlab;
  wire uartDataWriteFire = uartWriteFire &&
                           (requestUartReg == 4'h0) && !dlab;
  wire rxdFifoPush = rxdDataReady && !rxdFifoFull;
  wire rxdFifoPop = uartDataReadFire && !rxdFifoEmpty;

  assign txdReady = !txdHoldValid && !txdBusy;
  assign rxdClear = rxdFifoPush;
  assign txdStart = txdHoldValid && !txdBusy;
  assign txdData = txdHold;

  async_receiver #(.ClkFrequency(CLK_FREQ), .Baud(BAUD)) u_async_receiver(
    .clk(clk),
    .RxD(rxd),
    .RxD_data_ready(rxdDataReady),
    .RxD_clear(rxdClear),
    .RxD_data(rxdData)
  );

  async_transmitter #(.ClkFrequency(CLK_FREQ), .Baud(BAUD)) u_async_transmitter(
    .clk(clk),
    .TxD_start(txdStart),
    .TxD_data(txdData),
    .TxD(txd),
    .TxD_busy(txdBusy)
  );

  always @(posedge clk or posedge ramRst) begin
    if (ramRst) begin
      rxdWritePtr <= 0;
      rxdReadPtr <= 0;
      rxdCount <= 0;
    end else begin
      if (rxdFifoPush) begin
        rxdFifoMem[rxdWritePtr] <= rxdData;
        rxdWritePtr <= rxdWritePtr + 1'b1;
      end
      if (rxdFifoPop)
        rxdReadPtr <= rxdReadPtr + 1'b1;

      case ({rxdFifoPush, rxdFifoPop})
        2'b10: rxdCount <= rxdCount + 1'b1;
        2'b01: rxdCount <= rxdCount - 1'b1;
        default: rxdCount <= rxdCount;
      endcase
    end
  end

  always @(posedge clk or posedge ramRst) begin
    if (ramRst) begin
      txdHold <= 8'h00;
      txdHoldValid <= 1'b0;
    end else if (uartDataWriteFire) begin
      txdHold <= requestWriteByte;
      txdHoldValid <= 1'b1;
    end else if (txdStart) begin
      txdHoldValid <= 1'b0;
    end
  end

  always @(posedge clk or posedge ramRst) begin
    if (ramRst) begin
      dlab <= 1'b0;
    end else if (uartWriteFire && (requestUartReg == 4'h3)) begin
      dlab <= requestWriteByte[7];
    end
  end

  always @(posedge clk or posedge ramRst) begin
    if (ramRst) begin
      busState <= BUS_IDLE;
      sbCount <= 2'd0;
      sbHead <= 1'b0;
      sbTail <= 1'b0;
      sbBase[0] <= 1'b0;
      sbBase[1] <= 1'b0;
      sbExt[0] <= 1'b0;
      sbExt[1] <= 1'b0;
      sbAddress[0] <= 32'h0;
      sbAddress[1] <= 32'h0;
      sbWriteData[0] <= 32'h0;
      sbWriteData[1] <= 32'h0;
      sbByteEnable[0] <= 4'h0;
      sbByteEnable[1] <= 4'h0;
      fastReadPending <= 1'b0;
      fastReadData <= 32'h0;
      responsePending <= 1'b0;
      responseData <= 32'h0;
      dataMemResponseValid <= 1'b0;
      dataMemReadData <= 32'h0;
      icacheReadResponseValid <= 1'b0;
      icacheReadData <= 32'h0;
      busReadIsICache <= 1'b0;

      baseAddrQ <= 20'h00000;
      baseBeNQ <= 4'b0000;
      baseOeNQ <= 1'b0;
      baseWeNQ <= 1'b1;

      extAddrQ <= 20'h0;
      extBeNQ <= 4'b0000;
      extOeNQ <= 1'b1;
      extWeNQ <= 1'b1;
    end else begin
      dataMemResponseValid <= responsePending;
      icacheReadResponseValid <= (busState == BUS_BASE_READ) &&
                                 busReadIsICache;
      if ((busState == BUS_BASE_READ) && busReadIsICache)
        icacheReadData <= baseRAMOut;
      if (responsePending)
        dataMemReadData <= responseData;
      responsePending <= fastReadPending ||
                         ((busState == BUS_BASE_READ) && !busReadIsICache) ||
                         (busState == BUS_EXT_READ);
      fastReadPending <= forwardedLoadFire || uartReadFire || unmappedLoadFire;

      if ((busState == BUS_BASE_READ) && !busReadIsICache)
        responseData <= baseRAMOut;
      else if (busState == BUS_EXT_READ)
        responseData <= extRAMOut;
      else if (fastReadPending)
        responseData <= fastReadData;

      if (forwardedLoadFire)
        fastReadData <= forwardedStoreData;
      else if (uartReadFire)
        fastReadData <= {requestReadByte, requestReadByte,
                         requestReadByte, requestReadByte};
      else if (unmappedLoadFire)
        fastReadData <= 32'h0;

      if (icacheReadFire) begin
        busState <= BUS_BASE_READ;
        busReadIsICache <= 1'b1;
        baseAddrQ <= icacheReadAddress[21:2];
        baseBeNQ <= 4'b0000;
        baseOeNQ <= 1'b0;
        baseWeNQ <= 1'b1;
      end else begin

      case (busState)
        BUS_BASE_READ: begin
          busState <= BUS_IDLE;
          busReadIsICache <= 1'b0;
          baseAddrQ <= instrMemAddressNext[21:2];
          baseBeNQ <= 4'b0000;
          baseOeNQ <= 1'b0;
          baseWeNQ <= 1'b1;
        end
        BUS_EXT_READ: begin
          busState <= BUS_IDLE;
          baseAddrQ <= instrMemAddressNext[21:2];
          baseBeNQ <= 4'b0000;
          baseOeNQ <= 1'b0;
          baseWeNQ <= 1'b1;
          extOeNQ <= 1'b1;
          extWeNQ <= 1'b1;
        end
        BUS_STORE: begin
          busState <= BUS_IDLE;
          sbCount <= sbCount - 1'b1;
          sbHead <= ~sbHead;
          if (sbHeadBase) begin
            baseAddrQ <= instrMemAddressNext[21:2];
            baseBeNQ <= 4'b0000;
            baseOeNQ <= 1'b0;
            baseWeNQ <= 1'b1;
          end
          if (sbHeadExt) begin
            baseAddrQ <= instrMemAddressNext[21:2];
            baseBeNQ <= 4'b0000;
            baseOeNQ <= 1'b0;
            baseWeNQ <= 1'b1;
            extOeNQ <= 1'b1;
            extWeNQ <= 1'b1;
          end
        end
        default: begin
          // A queued store starts when the SRAM bus becomes idle.
          if (!sbEmpty) begin
            busState <= BUS_STORE;
            if (sbHeadBase) begin
              baseAddrQ <= sbHeadAddress[21:2];
              baseBeNQ <= ~sbHeadByteEnable;
              baseOeNQ <= 1'b1;
              baseWeNQ <= 1'b0;
            end else begin
              baseAddrQ <= instrMemAddressNext[21:2];
              baseBeNQ <= 4'b0000;
              baseOeNQ <= 1'b0;
              baseWeNQ <= 1'b1;
              extAddrQ <= sbHeadAddress[21:2];
              extBeNQ <= ~sbHeadByteEnable;
              extOeNQ <= 1'b1;
              extWeNQ <= 1'b0;
            end
          end else if (sramStoreFire) begin
            sbCount <= 2'd1;
            sbBase[sbTail] <= dataMemBaseRamSelect;
            sbExt[sbTail] <= dataMemExtRamSelect;
            sbAddress[sbTail] <= dataMemAddress;
            sbWriteData[sbTail] <= dataMemWriteData;
            sbByteEnable[sbTail] <= dataMemByteEnable;
            sbTail <= ~sbTail;
            busState <= BUS_STORE;
            if (dataMemBaseRamSelect) begin
              baseAddrQ <= dataMemAddress[21:2];
              baseBeNQ <= ~dataMemByteEnable;
              baseOeNQ <= 1'b1;
              baseWeNQ <= 1'b0;
            end else begin
              baseAddrQ <= instrMemAddressNext[21:2];
              baseBeNQ <= 4'b0000;
              baseOeNQ <= 1'b0;
              baseWeNQ <= 1'b1;
              extAddrQ <= dataMemAddress[21:2];
              extBeNQ <= ~dataMemByteEnable;
              extOeNQ <= 1'b1;
              extWeNQ <= 1'b0;
            end
          end else if (sramLoadFire && !forwardedLoadFire) begin
            if (dataMemBaseRamSelect) begin
              busState <= BUS_BASE_READ;
              busReadIsICache <= 1'b0;
              baseAddrQ <= dataMemAddress[21:2];
              baseBeNQ <= ~dataMemByteEnable;
              baseOeNQ <= 1'b0;
              baseWeNQ <= 1'b1;
            end else begin
              baseAddrQ <= instrMemAddressNext[21:2];
              baseBeNQ <= 4'b0000;
              baseOeNQ <= 1'b0;
              baseWeNQ <= 1'b1;
              busState <= BUS_EXT_READ;
              extAddrQ <= dataMemAddress[21:2];
              extBeNQ <= ~dataMemByteEnable;
              extOeNQ <= 1'b0;
              extWeNQ <= 1'b1;
            end
          end else if (icacheReadFire) begin
            busState <= BUS_BASE_READ;
            busReadIsICache <= 1'b1;
            baseAddrQ <= icacheReadAddress[21:2];
            baseBeNQ <= 4'b0000;
            baseOeNQ <= 1'b0;
            baseWeNQ <= 1'b1;
          end else begin
            baseAddrQ <= instrMemAddressNext[21:2];
            baseBeNQ <= 4'b0000;
            baseOeNQ <= 1'b0;
            baseWeNQ <= 1'b1;
            extOeNQ <= 1'b1;
            extWeNQ <= 1'b1;
          end
        end
      endcase
      end

      // Enqueue behind an older transaction, including the cycle in which an
      // idle bus starts draining the current FIFO head.
      if (sramStoreFire && ((busState != BUS_IDLE) || !sbEmpty)) begin
        if (busState == BUS_STORE)
          sbCount <= sbCount;
        else
          sbCount <= sbCount + 1'b1;
        sbBase[sbTail] <= dataMemBaseRamSelect;
        sbExt[sbTail] <= dataMemExtRamSelect;
        sbAddress[sbTail] <= dataMemAddress;
        sbWriteData[sbTail] <= dataMemWriteData;
        sbByteEnable[sbTail] <= dataMemByteEnable;
        sbTail <= ~sbTail;
      end
    end
  end

  // Keep the per-bit IOBUF tristate flops free of reset so they can pack into
  // the IOB and meet the SRAM output-delay constraint.
  always @(posedge clk) begin
    if (ramRst) begin
      baseDataTQ <= 32'hffffffff;
      extDataTQ <= 32'hffffffff;
    end else begin
      if ((busState == BUS_IDLE) && !sbEmpty && sbHeadBase)
        baseDataTQ <= 32'h00000000;
      else if ((busState == BUS_IDLE) && sramStoreFire &&
               dataMemBaseRamSelect)
        baseDataTQ <= 32'h00000000;
      else
        baseDataTQ <= 32'hffffffff;

      if ((busState == BUS_IDLE) && !sbEmpty && sbHeadExt)
        extDataTQ <= 32'h00000000;
      else if ((busState == BUS_IDLE) && sramStoreFire &&
               dataMemExtRamSelect)
        extDataTQ <= 32'h00000000;
      else
        extDataTQ <= 32'hffffffff;
    end
  end

  always @(posedge clk) begin
    if (ramRst) begin
      baseWriteDataQ <= 32'h0;
      extWriteDataQ <= 32'h0;
    end else begin
      if ((busState == BUS_IDLE) && !sbEmpty && sbHeadBase)
        baseWriteDataQ <= sbHeadWriteData;
      else if ((busState == BUS_IDLE) && sramStoreFire &&
               dataMemBaseRamSelect)
        baseWriteDataQ <= dataMemWriteData;

      if ((busState == BUS_IDLE) && !sbEmpty && sbHeadExt)
        extWriteDataQ <= sbHeadWriteData;
      else if ((busState == BUS_IDLE) && sramStoreFire &&
               dataMemExtRamSelect)
        extWriteDataQ <= dataMemWriteData;
    end
  end

endmodule

