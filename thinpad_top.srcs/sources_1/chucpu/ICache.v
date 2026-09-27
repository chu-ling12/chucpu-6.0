`default_nettype none

// Blocking direct-mapped I-cache adapted from the reference design's
// two-word cache-line organization for this CPU's precise refill handshake.
module ICache(
  input wire clk,
  input wire rst,

  input wire [31:0] cpu_addr,
  input wire cpu_cached,
  output wire [31:0] cpu_data,
  output wire stall_req,

  output reg ram_req,
  output reg [31:0] ram_addr,
  input wire ram_req_ready,
  input wire ram_resp_valid,
  input wire [31:0] ram_data,

  input wire invalidate_en,
  input wire [31:0] invalidate_addr,
  input wire cacop_inv_en,
  input wire [31:0] cacop_inv_addr
);

  localparam LOOKUP = 2'd0;
  localparam REQUEST = 2'd1;
  localparam RESPONSE = 2'd2;

  localparam OFFSET_BITS = 3;
  localparam INDEX_BITS = 8;
  localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS;
  localparam SET_COUNT = 1 << INDEX_BITS;

  reg cacheRst;
  always @(posedge clk or posedge rst) begin
    if (rst)
      cacheRst <= 1'b1;
    else
      cacheRst <= 1'b0;
  end

  reg [1:0] state;
  reg [INDEX_BITS-1:0] fill_index;
  reg [TAG_BITS-1:0] fill_tag;
  reg fill_word;
  reg fill_critical_word;
  reg fill_count;
  reg [1:0] fill_word_valid;
  reg [31:0] fill_line_addr;
  reg critical_valid;
  reg [31:0] critical_addr;
  reg [31:0] critical_data;
  reg refill_was_invalidated;

  (* ram_style = "distributed" *) reg valid_ram [0:SET_COUNT-1];
  (* ram_style = "distributed" *) reg [TAG_BITS-1:0] tag_ram [0:SET_COUNT-1];
  (* ram_style = "distributed" *) reg [31:0] word0_ram [0:SET_COUNT-1];
  (* ram_style = "distributed" *) reg [31:0] word1_ram [0:SET_COUNT-1];

  wire [INDEX_BITS-1:0] req_index =
      cpu_addr[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];
  wire [TAG_BITS-1:0] req_tag =
      cpu_addr[31:INDEX_BITS+OFFSET_BITS];
  wire req_word = cpu_addr[2];
  wire [INDEX_BITS-1:0] invalidate_index =
      invalidate_addr[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];
  wire [TAG_BITS-1:0] invalidate_tag =
      invalidate_addr[31:INDEX_BITS+OFFSET_BITS];
  wire [INDEX_BITS-1:0] cacop_index =
      cacop_inv_addr[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];

  wire refill_invalidate_now = (state != LOOKUP) &&
      ((invalidate_en && (invalidate_index == fill_index) &&
        (invalidate_tag == fill_tag)) ||
       (cacop_inv_en && (cacop_index == fill_index)));
  wire cache_hit = cpu_cached && valid_ram[req_index] &&
                   (tag_ram[req_index] == req_tag);
  wire refill_hit = cpu_cached && (state != LOOKUP) &&
                    (fill_index == req_index) &&
                    (fill_tag == req_tag) && fill_word_valid[req_word];
  wire response_hit = cpu_cached && (state == RESPONSE) &&
                      ram_resp_valid && (fill_index == req_index) &&
                      (fill_tag == req_tag) && (fill_word == req_word);
  wire critical_hit = cpu_cached && critical_valid &&
                      (critical_addr == {cpu_addr[31:2], 2'b00});
  wire [31:0] cached_word = req_word ? word1_ram[req_index] :
                                               word0_ram[req_index];

  assign cpu_data = response_hit ? ram_data :
                    cache_hit ? cached_word :
                    refill_hit ? cached_word :
                    critical_hit ? critical_data : 32'h00000000;
  assign stall_req = cpu_cached && !cache_hit && !refill_hit &&
                     !response_hit && !critical_hit;

  always @(*) begin
    ram_req = (state == REQUEST);
    ram_addr = fill_line_addr + {29'h00000000, fill_word, 2'b00};
  end

  integer i;
  always @(posedge clk) begin
    if (cacheRst) begin
      state <= LOOKUP;
      fill_index <= {INDEX_BITS{1'b0}};
      fill_tag <= {TAG_BITS{1'b0}};
      fill_word <= 1'b0;
      fill_critical_word <= 1'b0;
      fill_count <= 1'b0;
      fill_word_valid <= 2'b00;
      fill_line_addr <= 32'h00000000;
      critical_valid <= 1'b0;
      critical_addr <= 32'h00000000;
      critical_data <= 32'h00000000;
      refill_was_invalidated <= 1'b0;
      for (i = 0; i < SET_COUNT; i = i + 1)
        valid_ram[i] = 1'b0;
    end else begin
      case (state)
        LOOKUP: begin
          if (cpu_cached && !cache_hit) begin
            fill_index <= req_index;
            fill_tag <= req_tag;
            fill_word <= req_word;
            fill_critical_word <= req_word;
            fill_count <= 1'b0;
            fill_word_valid <= 2'b00;
            fill_line_addr <= {cpu_addr[31:OFFSET_BITS],
                               {OFFSET_BITS{1'b0}}};
            critical_valid <= 1'b0;
            refill_was_invalidated <= 1'b0;
            state <= REQUEST;
          end
        end

        REQUEST: begin
          if (ram_req_ready)
            state <= RESPONSE;
        end

        RESPONSE: begin
          if (ram_resp_valid) begin
            if (fill_word)
              word1_ram[fill_index] <= ram_data;
            else
              word0_ram[fill_index] <= ram_data;
            fill_word_valid[fill_word] <= 1'b1;
            if (!fill_count) begin
              critical_data <= ram_data;
              critical_addr <= fill_line_addr +
                               {29'h00000000, fill_critical_word, 2'b00};
              critical_valid <= !refill_was_invalidated &&
                                !refill_invalidate_now;
              fill_count <= 1'b1;
              fill_word <= ~fill_word;
              state <= REQUEST;
            end else begin
              tag_ram[fill_index] <= fill_tag;
              valid_ram[fill_index] <= !refill_was_invalidated &&
                                       !refill_invalidate_now;
              critical_valid <= 1'b0;
              state <= LOOKUP;
            end
          end
        end

        default: state <= LOOKUP;
      endcase

      if (invalidate_en && valid_ram[invalidate_index] &&
          (tag_ram[invalidate_index] == invalidate_tag))
        valid_ram[invalidate_index] <= 1'b0;
      if (cacop_inv_en)
        valid_ram[cacop_index] <= 1'b0;
      if (refill_invalidate_now)
        refill_was_invalidated <= 1'b1;
      if (critical_valid &&
          ((invalidate_en &&
            (invalidate_addr[31:OFFSET_BITS] ==
             critical_addr[31:OFFSET_BITS])) ||
           (cacop_inv_en &&
            (cacop_index ==
             critical_addr[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS]))))
        critical_valid <= 1'b0;
    end
  end

endmodule

`default_nettype wire
