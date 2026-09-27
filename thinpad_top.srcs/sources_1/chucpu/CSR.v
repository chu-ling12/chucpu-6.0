module CSR(
  input wire clk,
  input wire rst,
  input wire [13:0] csr_raddr,
  output reg [31:0] csr_rdata,
  input wire csr_we,
  input wire [13:0] csr_waddr,
  input wire [31:0] csr_wdata,
  input wire [31:0] instr_virt_addr,
  output reg [31:0] instr_phys_addr,
  output reg instr_cached,
  input wire [31:0] instr_next_virt_addr,
  output reg [31:0] instr_next_phys_addr,
  input wire [31:0] data_virt_addr,
  output reg [31:0] data_phys_addr,
  output reg data_cached,
  input wire [31:0] cacop_virt_addr,
  output reg [31:0] cacop_phys_addr
);

  reg [31:0] crmd;
  reg [31:0] dmw0;
  reg [31:0] dmw1;
  reg address_mode_configured;

  wire direct_address_mode = crmd[3] && !crmd[4];

  always @(posedge clk) begin
    if (rst) begin
      crmd <= 32'h00000008;
      dmw0 <= 32'h00000000;
      dmw1 <= 32'h00000000;
      address_mode_configured <= 1'b0;
    end else if (csr_we) begin
      case (csr_waddr)
        14'h000: begin
          crmd <= csr_wdata;
          address_mode_configured <= 1'b1;
        end
        14'h180: begin
          dmw0 <= csr_wdata;
          address_mode_configured <= 1'b1;
        end
        14'h181: begin
          dmw1 <= csr_wdata;
          address_mode_configured <= 1'b1;
        end
        default: begin
        end
      endcase
    end
  end

  always @(*) begin
    case (csr_raddr)
      14'h000: csr_rdata = crmd;
      14'h180: csr_rdata = dmw0;
      14'h181: csr_rdata = dmw1;
      default: csr_rdata = 32'h00000000;
    endcase
  end

  wire plv0 = (crmd[1:0] == 2'd0);
  wire plv3 = (crmd[1:0] == 2'd3);

  wire instr_dmw0_hit = !crmd[3] && crmd[4] &&
                         (instr_virt_addr[31:29] == dmw0[31:29]) &&
                         ((plv0 && dmw0[0]) || (plv3 && dmw0[3]));
  wire instr_dmw1_hit = !crmd[3] && crmd[4] &&
                         (instr_virt_addr[31:29] == dmw1[31:29]) &&
                         ((plv0 && dmw1[0]) || (plv3 && dmw1[3]));
  wire instr_next_dmw0_hit = !crmd[3] && crmd[4] &&
                              (instr_next_virt_addr[31:29] == dmw0[31:29]) &&
                              ((plv0 && dmw0[0]) || (plv3 && dmw0[3]));
  wire instr_next_dmw1_hit = !crmd[3] && crmd[4] &&
                              (instr_next_virt_addr[31:29] == dmw1[31:29]) &&
                              ((plv0 && dmw1[0]) || (plv3 && dmw1[3]));
  wire data_dmw0_hit = !crmd[3] && crmd[4] &&
                        (data_virt_addr[31:29] == dmw0[31:29]) &&
                        ((plv0 && dmw0[0]) || (plv3 && dmw0[3]));
  wire data_dmw1_hit = !crmd[3] && crmd[4] &&
                        (data_virt_addr[31:29] == dmw1[31:29]) &&
                        ((plv0 && dmw1[0]) || (plv3 && dmw1[3]));
  wire cacop_dmw0_hit = !crmd[3] && crmd[4] &&
                         (cacop_virt_addr[31:29] == dmw0[31:29]) &&
                         ((plv0 && dmw0[0]) || (plv3 && dmw0[3]));
  wire cacop_dmw1_hit = !crmd[3] && crmd[4] &&
                         (cacop_virt_addr[31:29] == dmw1[31:29]) &&
                         ((plv0 && dmw1[0]) || (plv3 && dmw1[3]));

  always @(*) begin
    if (instr_dmw0_hit) begin
      instr_phys_addr = {dmw0[27:25], instr_virt_addr[28:0]};
      instr_cached = (dmw0[5:4] == 2'b01);
    end else if (instr_dmw1_hit) begin
      instr_phys_addr = {dmw1[27:25], instr_virt_addr[28:0]};
      instr_cached = (dmw1[5:4] == 2'b01);
    end else begin
      instr_phys_addr = instr_virt_addr;
      // Some legacy monitors do not program CRMD/DMW after detecting an
      // I-cache. Cache only the BaseRAM boot window until software writes one
      // of the address-mode CSRs; data accesses and CSR readback stay exact.
      instr_cached = (!address_mode_configured &&
                      (instr_virt_addr[31:22] == 10'b0001110000)) ? 1'b1 :
                     direct_address_mode ? 1'b0 :
                     (crmd[6:5] == 2'b01);
    end

    if (instr_next_dmw0_hit)
      instr_next_phys_addr = {dmw0[27:25], instr_next_virt_addr[28:0]};
    else if (instr_next_dmw1_hit)
      instr_next_phys_addr = {dmw1[27:25], instr_next_virt_addr[28:0]};
    else
      instr_next_phys_addr = instr_next_virt_addr;

    if (data_dmw0_hit) begin
      data_phys_addr = {dmw0[27:25], data_virt_addr[28:0]};
      data_cached = (dmw0[5:4] == 2'b01);
    end else if (data_dmw1_hit) begin
      data_phys_addr = {dmw1[27:25], data_virt_addr[28:0]};
      data_cached = (dmw1[5:4] == 2'b01);
    end else begin
      data_phys_addr = data_virt_addr;
      data_cached = (crmd[8:7] == 2'b01);
    end

    if (cacop_dmw0_hit)
      cacop_phys_addr = {dmw0[27:25], cacop_virt_addr[28:0]};
    else if (cacop_dmw1_hit)
      cacop_phys_addr = {dmw1[27:25], cacop_virt_addr[28:0]};
    else
      cacop_phys_addr = cacop_virt_addr;
  end

endmodule
