`default_nettype none

module thinpad_top(
    input wire clk_50M,           //50MHz 时钟输入
    input wire clk_11M0592,       //11.0592MHz 时钟输入（��用，可不用�?

    input wire clock_btn,         //BTN5手动时钟按钮开关，带消抖电�?，按下时�?1
    input wire reset_btn,         //BTN6手动复位按钮开关，带消抖电�?，按下时�?1

    input  wire[3:0]  touch_btn,  //BTN1~BTN4，按�?开关，按下时为1
    input  wire[31:0] dip_sw,     //32位拨码开关，拨到“ON”时�?1
    output wire[15:0] leds,       //16位LED，输出时1点亮
    output wire[7:0]  dpy0,       //数码管低位信号，包括小数点，输出1点亮
    output wire[7:0]  dpy1,       //数码管高位信号，包括小数点，输出1点亮

    //BaseRAM信号
    inout wire[31:0] base_ram_data,  //BaseRAM数据，低8位与CPLD串口控制器共�?
    output wire[19:0] base_ram_addr, //BaseRAM地址
    output wire[3:0] base_ram_be_n,  //BaseRAM字节使能，低有效。�?�果不使用字节使能，请保持为0
    output wire base_ram_ce_n,       //BaseRAM片选，低有�?
    output wire base_ram_oe_n,       //BaseRAM读使能，低有�?
    output wire base_ram_we_n,       //BaseRAM写使能，低有�?

    //ExtRAM信号
    inout wire[31:0] ext_ram_data,  //ExtRAM数据
    output wire[19:0] ext_ram_addr, //ExtRAM地址
    output wire[3:0] ext_ram_be_n,  //ExtRAM字节使能，低有效。�?�果不使用字节使能，请保持为0
    output wire ext_ram_ce_n,       //ExtRAM片选，低有�?
    output wire ext_ram_oe_n,       //ExtRAM读使能，低有�?
    output wire ext_ram_we_n,       //ExtRAM写使能，低有�?

    //直连串口信号
    output wire txd,  //直连串口发送�??
    input  wire rxd,  //直连串口接收�?

    //Flash存储器信号，参�? JS28F640 �?片手�?
    output wire [22:0]flash_a,      //Flash地址，a0仅在8bit模式有效�?16bit模式无意�?
    inout  wire [15:0]flash_d,      //Flash数据
    output wire flash_rp_n,         //Flash复位信号，低有效
    output wire flash_vpen,         //Flash写保护信号，低电平时不能擦除、烧�?
    output wire flash_ce_n,         //Flash片选信号，低有�?
    output wire flash_oe_n,         //Flash读使能信号，低有�?
    output wire flash_we_n,         //Flash写使能信号，低有�?
    output wire flash_byte_n,       //Flash 8bit模式选择，低有效。在使用flash�?16位模式时请�?�为1

    //图像输出信号
    output wire[2:0] video_red,    //红色像素�?3�?
    output wire[2:0] video_green,  //绿色像素�?3�?
    output wire[1:0] video_blue,   //蓝色像素�?2�?
    output wire video_hsync,       //行同步（水平同�?�）信号
    output wire video_vsync,       //场同步（垂直同�?�）信号
    output wire video_clk,         //像素时钟输出
    output wire video_de           //行数�?有效信号，用于区分消隐区
);

    assign leds = dip_sw[15:0];

    wire locked, clk_out;
    reg reset_of_clk_out;

    CPUClockGen #(
        .CLKFBOUT_MULT_F(26.500),
        .CLKOUT0_DIVIDE_F(20.000)
    ) clk_gen(
        .clk_in1(clk_50M),
        .clk_out1(clk_out),
        .reset(reset_btn),
        .locked(locked)
    );

    always @(posedge clk_out or negedge locked) begin
        if (~locked) reset_of_clk_out <= 1'b1;
        else reset_of_clk_out <= 1'b0;
    end

    wire [31:0] instrMemAddress;
    wire [31:0] instrMemAddressNext;
    wire [31:0] instrMemPhysicalAddress;
    wire [31:0] instrMemPhysicalAddressNext;
    wire instrMemCached;
    wire [31:0] instrMemData;
    wire [31:0] ramInstrMemData;
    wire dataMemReadEnable;
    wire dataMemWriteEnable;
    wire dataMemRequestReady;
    wire dataMemResponseValid;
    wire [31:0] dataMemReadData;
    wire [31:0] dataMemWriteData;
    wire [31:0] dataMemAddress;
    wire [3:0] dataMemByteEnable;
    wire dataMemChipSelect;
    wire dataMemBaseRamSelect;
    wire dataMemExtRamSelect;
    wire dataMemUartSelect;
    wire instrMemHold;
    wire ramInstrMemHold;
    wire cacopInvalidate;
    wire [31:0] cacopAddress;
    wire icacheStall;
    wire icacheReadRequest;
    wire [31:0] icacheReadAddress;
    wire icacheReadRequestReady;
    wire icacheReadResponseValid;
    wire [31:0] icacheReadData;
    wire [31:0] icacheInstrMemData;
    wire baseStoreAccepted;
    reg baseStoreFence;

    assign baseStoreAccepted = dataMemWriteEnable && dataMemRequestReady &&
                               dataMemBaseRamSelect;
    assign instrMemData = instrMemCached ? icacheInstrMemData :
                                          ramInstrMemData;
    assign instrMemHold = icacheStall || baseStoreFence ||
                          (!instrMemCached && ramInstrMemHold);

    always @(posedge clk_out) begin
        if (reset_of_clk_out)
            baseStoreFence <= 1'b0;
        else if (baseStoreAccepted)
            baseStoreFence <= 1'b1;
        else if (!ramInstrMemHold)
            baseStoreFence <= 1'b0;
    end

    CPU u_cpu(
        .clk(clk_out),
        .rst(reset_of_clk_out),
        .instrMemAddress(instrMemAddress),
        .instrMemAddressNext(instrMemAddressNext),
        .instrMemPhysicalAddress(instrMemPhysicalAddress),
        .instrMemPhysicalAddressNext(instrMemPhysicalAddressNext),
        .instrMemCached(instrMemCached),
        .cacopInvalidate(cacopInvalidate),
        .cacopAddress(cacopAddress),
        .instrMemData(instrMemData),
        .dataMemReadEnable(dataMemReadEnable),
        .dataMemWriteEnable(dataMemWriteEnable),
        .dataMemRequestReady(dataMemRequestReady),
        .dataMemResponseValid(dataMemResponseValid),
        .dataMemReadData(dataMemReadData),
        .dataMemWriteData(dataMemWriteData),
        .dataMemAddress(dataMemAddress),
        .dataMemByteEnable(dataMemByteEnable),
        .dataMemChipSelect(dataMemChipSelect),
        .dataMemBaseRamSelect(dataMemBaseRamSelect),
        .dataMemExtRamSelect(dataMemExtRamSelect),
        .dataMemUartSelect(dataMemUartSelect),
        .instrMemHold(instrMemHold)
    );

    ICache u_icache(
        .clk(clk_out),
        .rst(reset_of_clk_out),
        .cpu_addr(instrMemPhysicalAddress),
        .cpu_cached(instrMemCached),
        .cpu_data(icacheInstrMemData),
        .stall_req(icacheStall),
        .ram_req(icacheReadRequest),
        .ram_addr(icacheReadAddress),
        .ram_req_ready(icacheReadRequestReady),
        .ram_resp_valid(icacheReadResponseValid),
        .ram_data(icacheReadData),
        .invalidate_en(baseStoreAccepted),
        .invalidate_addr(dataMemAddress),
        .cacop_inv_en(cacopInvalidate),
        .cacop_inv_addr(cacopAddress)
    );

    RAM #(
        .CLK_FREQ(66250000),
        .BAUD(115200)
    ) u_ram(
        .clk(clk_out),
        .rst(reset_of_clk_out),
        .txd(txd),
        .rxd(rxd),
        .instrMemAddress(instrMemPhysicalAddress),
        .instrMemAddressNext(instrMemPhysicalAddressNext),
        .instrMemData(ramInstrMemData),
        .dataMemReadEnable(dataMemReadEnable),
        .dataMemWriteEnable(dataMemWriteEnable),
        .dataMemRequestReady(dataMemRequestReady),
        .dataMemResponseValid(dataMemResponseValid),
        .dataMemReadData(dataMemReadData),
        .dataMemWriteData(dataMemWriteData),
        .dataMemAddress(dataMemAddress),
        .dataMemByteEnable(dataMemByteEnable),
        .dataMemChipSelect(dataMemChipSelect),
        .dataMemBaseRamSelect(dataMemBaseRamSelect),
        .dataMemExtRamSelect(dataMemExtRamSelect),
        .dataMemUartSelect(dataMemUartSelect),
        .instrMemHold(ramInstrMemHold),
        .icacheReadRequest(icacheReadRequest),
        .icacheReadAddress(icacheReadAddress),
        .icacheReadRequestReady(icacheReadRequestReady),
        .icacheReadResponseValid(icacheReadResponseValid),
        .icacheReadData(icacheReadData),
        .base_ram_data(base_ram_data),
        .base_ram_addr(base_ram_addr),
        .base_ram_be_n(base_ram_be_n),
        .base_ram_ce_n(base_ram_ce_n),
        .base_ram_oe_n(base_ram_oe_n),
        .base_ram_we_n(base_ram_we_n),
        .ext_ram_data(ext_ram_data),
        .ext_ram_addr(ext_ram_addr),
        .ext_ram_be_n(ext_ram_be_n),
        .ext_ram_ce_n(ext_ram_ce_n),
        .ext_ram_oe_n(ext_ram_oe_n),
        .ext_ram_we_n(ext_ram_we_n)
    );

endmodule

module CPUClockGen #(
  parameter real CLKFBOUT_MULT_F = 20.250,
  parameter real CLKOUT0_DIVIDE_F = 20.000
)(
  input wire clk_in1,
  input wire reset,
  output wire clk_out1,
  output wire locked
);
  wire clk_in_buf;
  wire clk_fb;
  wire clk_fb_buf;
  wire clk_out;

  IBUF u_clk_in_buf(
    .I(clk_in1),
    .O(clk_in_buf)
  );

  MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKIN1_PERIOD(20.000),
    .DIVCLK_DIVIDE(1),
    .CLKFBOUT_MULT_F(CLKFBOUT_MULT_F),
    .CLKOUT0_DIVIDE_F(CLKOUT0_DIVIDE_F),
    .CLKOUT0_DUTY_CYCLE(0.500),
    .CLKOUT0_PHASE(0.000),
    .STARTUP_WAIT("FALSE")
  ) u_mmcm(
    .CLKIN1(clk_in_buf),
    .CLKFBIN(clk_fb_buf),
    .RST(reset),
    .PWRDWN(1'b0),
    .CLKFBOUT(clk_fb),
    .CLKOUT0(clk_out),
    .LOCKED(locked)
  );

  BUFG u_clk_fb_buf(
    .I(clk_fb),
    .O(clk_fb_buf)
  );

  BUFG u_clk_out_buf(
    .I(clk_out),
    .O(clk_out1)
  );
endmodule
