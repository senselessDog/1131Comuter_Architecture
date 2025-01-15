//=========================================================================
// Cache Base Design
//=========================================================================

`ifndef RISCV_CACHE_BASE_V
`define RISCV_CACHE_BASE_V
`include "vc-RAMs.v"
module riscv_CacheBase (
    input clk,
    input reset,

    // Cache Interface
    input                                  memreq_val,
    output                                 memreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,

    output                               memresp_val,
    input                                memresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0] memresp_msg,

    // Memory Interface  
    output                                 cachereq_val,
    input                                  cachereq_rdy, 
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    input                                cacheresp_val,
    output                               cacheresp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0] cacheresp_msg,

    // Flush Interface
    input  flush,
    output flush_done
);

  // Extract fields from memory request
  wire [`VC_MEM_REQ_MSG_TYPE_SZ(32,32)-1:0] memreq_msg_type;
  wire [`VC_MEM_REQ_MSG_ADDR_SZ(32,32)-1:0] memreq_msg_addr;
  wire [`VC_MEM_REQ_MSG_LEN_SZ(32,32)-1:0]  memreq_msg_len;
  wire [`VC_MEM_REQ_MSG_DATA_SZ(32,32)-1:0] memreq_msg_data;

  
  vc_MemReqMsgFromBits#(32,32) memreq_msg_from_bits (
    .bits (memreq_msg),
    .type (memreq_msg_type),
    .addr (memreq_msg_addr),
    .len  (memreq_msg_len),
    .data (memreq_msg_data)
  );

  // Extract fields from memory response
  wire [`VC_MEM_RESP_MSG_TYPE_SZ(32)-1:0] cacheresp_msg_type;
  wire [`VC_MEM_RESP_MSG_DATA_SZ(32)-1:0] cacheresp_msg_data;

  // 内存返回的响应消息解包
  vc_MemRespMsgFromBits#(32) cacheresp_msg_from_bits (
    .bits (cacheresp_msg),
    .type (cacheresp_msg_type),
    .len  (),
    .data (cacheresp_msg_data)
  );

  // Cache state machine states
  localparam STATE_IDLE = 4'd0;       // Wait for request
  localparam STATE_TAG_CHECK = 4'd1;   // Check if hit/miss
  localparam STATE_READ_DATA = 4'd2;   // Read data from cache
  localparam STATE_WRITE_DATA = 4'd3;  // Write data to cache
  localparam STATE_WRITEBACK = 4'd4;   // Write dirty block back
  localparam STATE_WRITEBACK_WAIT = 4'd5; // Wait for writeback to complete
  localparam STATE_REFILL = 4'd6;      // Refill cache block
  localparam STATE_REFILL_WAIT = 4'd7; // Wait for refill to complete
  localparam STATE_REFILL_UPDATE = 4'd8; // Update cache with refill data
  localparam STATE_FLUSH_START = 4'd9;  // Start flushing cache
  localparam STATE_FLUSH_WAIT = 4'd10;  // Wait for flush writeback

  // State registers
  reg [3:0] state;
  reg [3:0] next_state;

  // Address parsing
  wire [5:0]  offset    = memreq_msg_addr[5:0];   // 64B blocks -> 6 bits
  wire [4:0]  index     = memreq_msg_addr[10:6];  // 32 sets -> 5 bits  
  wire [20:0] tag       = memreq_msg_addr[31:11]; // Rest is tag
  
  // XXX: Block offset handling
  wire [3:0]  word_offset = offset[5:2];  // Which word in block
  reg  [3:0]  refill_count;               // Counter for refill
  reg  [3:0]  writeback_count;            // Counter for writeback
  reg  [4:0]  flush_count;                // Counter for flush

  // XXX: Cache line tracking
  reg  [31:0] refill_addr;    // Address for current refill
  reg  [4:0]  read_index;     // Index being read
  wire [31:0] block_addr;     // Current block address
  
  assign block_addr = {memreq_msg_addr[31:6], 6'b0};

  // Tag RAM signals
  reg  tag_wen;
  wire [22:0] tag_wdata;  // 21 tag + 1 valid + 1 dirty
  wire [22:0] tag_rdata;
  
  assign tag_wdata = {tag, 1'b1, state == STATE_WRITE_DATA}; // {tag, valid, dirty}

  // Data RAM signals  
  reg  data_wen;
  reg  [31:0] data_wdata;
  wire [31:0] data_rdata;
  reg  [8:0]  data_addr;   // 9 bits = 5 bits index + 4 bits word offset
  reg  [8:0] memreq_data_addr;
  // // change data_addr
  // always @(posedge clk) begin
  //   if 
  // end
  // Tag RAM 
  vc_RAM_1w1r_pf #(
    .DATA_SZ(23),          // tag + valid + dirty
    .ENTRIES(32),          // 32 sets
    .ADDR_SZ(5)           // 5-bit index
  ) tag_ram (
    .clk(clk),
    .raddr(read_index),
    .rdata(tag_rdata), //只有這個是output
    .wen_p(tag_wen),
    .waddr_p(state == STATE_FLUSH_START ? flush_count : index),
    .wdata_p(tag_wdata)
  );

  // Data RAM
  vc_RAM_1w1r_pf #(
    .DATA_SZ(32),         // 32-bit words
    .ENTRIES(512),        // 32 sets * 16 words per block
    .ADDR_SZ(9)          // 9-bit address (5-bit index + 4-bit word offset)
  ) data_ram (
    .clk(clk),
    .raddr(data_addr),
    .rdata(data_rdata),
    .wen_p(data_wen),
    .waddr_p(data_addr),
    .wdata_p(data_wdata)
  );

  // Tag comparison and status
  wire tag_match = (tag_rdata[22:2] == tag) && tag_rdata[1];  // Compare tag and check valid
  wire is_dirty = tag_rdata[0];    // Check dirty bit
  wire is_write = memreq_msg_type == `VC_MEM_REQ_MSG_TYPE_WRITE;
  wire cache_hit = tag_match && state == STATE_TAG_CHECK;

  // Response message construction
  vc_MemRespMsgToBits#(32) memresp_msg_to_bits (
    .type(memreq_msg_type),  
    .len(memreq_msg_len),
    .data(data_rdata),
    .bits(memresp_msg)
  );
  // cache向memory发送请求
  // Request message to memory construction  
  vc_MemReqMsgToBits#(32,32) cachereq_msg_to_bits (
    .type(state == STATE_WRITEBACK ? `VC_MEM_REQ_MSG_TYPE_WRITE : `VC_MEM_REQ_MSG_TYPE_READ),
    .addr(state == STATE_WRITEBACK ? {memreq_msg_addr[31:6], writeback_count[3:0], 2'b0} : {memreq_msg_addr[31:6], refill_count[3:0], 2'b0}),
    .len(2'b0),
    .data(data_rdata),
    .bits(cachereq_msg)
  );

  // FSM Next State Logic
  always @(*) begin
    next_state = state;
    
    case (state)
      STATE_IDLE: begin
        if (flush)
          next_state = STATE_FLUSH_START;
        else if (memreq_val)
          next_state = STATE_TAG_CHECK;
      end
      
      STATE_TAG_CHECK: begin
        if (tag_match) begin
          if (is_write)
            next_state = STATE_WRITE_DATA;
          else
            next_state = STATE_READ_DATA;
        end else begin
          if (is_dirty)
            next_state = STATE_WRITEBACK;
          else
            next_state = STATE_REFILL;
        end
      end

      STATE_READ_DATA: begin
        next_state = STATE_IDLE;
      end

      STATE_WRITE_DATA: begin
        next_state = STATE_IDLE;
      end
      
      STATE_WRITEBACK: begin
        if (cachereq_rdy)
          next_state = STATE_WRITEBACK_WAIT;
      end

      STATE_WRITEBACK_WAIT: begin
        if (cacheresp_val) begin
          if (writeback_count == 4'd15)
            next_state = STATE_REFILL;
          else
            next_state = STATE_WRITEBACK;
        end
      end
      
      STATE_REFILL: begin
        if (cachereq_rdy)
          next_state = STATE_REFILL_WAIT;
      end

      STATE_REFILL_WAIT: begin
        if (cacheresp_val)
          next_state = STATE_REFILL_UPDATE;
      end

      STATE_REFILL_UPDATE: begin
        if (refill_count == 4'd15) begin
          if (is_write)
            next_state = STATE_WRITE_DATA;
          else
            next_state = STATE_READ_DATA;
        end else
          next_state = STATE_REFILL;
      end

      STATE_FLUSH_START: begin
        if (tag_rdata[1] && tag_rdata[0]) // 如果 valid 且 dirty
          next_state = STATE_WRITEBACK;
        else if (flush_count == 5'd31)
          next_state = STATE_IDLE;
        else
          next_state = STATE_FLUSH_START;
      end
    endcase
  end

  // State Register and Counters
  always @(posedge clk) begin
    if (reset) begin
      state <= STATE_IDLE;
      refill_count <= 0;
      writeback_count <= 0;
      flush_count <= 0;
      data_addr <= 9'd0;
    end else begin
      if (memreq_val)begin
        memreq_data_addr = {index, word_offset};
      end
      state <= next_state;
      
      case (state)
        STATE_WRITEBACK_WAIT: begin
          if (cacheresp_val)
            writeback_count <= writeback_count + 1;
        end

        STATE_REFILL_UPDATE: begin
          refill_count <= refill_count + 1;
        end

        STATE_FLUSH_START: begin
          if (flush_count != 5'd31)
            flush_count <= flush_count + 1;
        end

        STATE_IDLE: begin
          refill_count <= 0;
          writeback_count <= 0;
          if (!flush)
            flush_count <= 0;
        end
      endcase
    end
  end

  // Data path control signals
  always @(*) begin
    // Default values
    tag_wen = 0;
    data_wen = 0;
    data_addr = memreq_data_addr;
    data_wdata = memreq_msg_data;
    read_index = index;

    case (state)
      STATE_WRITE_DATA: begin
        tag_wen = 1;
        data_wen = 1;
        data_addr = {index, word_offset};
      end

      STATE_WRITEBACK: begin
        data_addr = {index, writeback_count};
      end

      STATE_REFILL_UPDATE: begin
        tag_wen = (refill_count == 0);
        data_wen = 1;
        data_addr = {index, refill_count};
        data_wdata = cacheresp_msg_data;
      end

      STATE_FLUSH_START: begin
        read_index = flush_count;
      end
    endcase
  end

//   // Control Signal Logic
  assign memreq_rdy = (state == STATE_IDLE && !flush);
  assign memresp_val = (state == STATE_READ_DATA);
  assign cachereq_val = (state == STATE_WRITEBACK || state == STATE_REFILL);
  // assign cacheresp_rdy = (state == STATE_WRITEBACK_WAIT || state == STATE_REFILL_WAIT);
  //MODIFY: 更改flush_done邏輯
  assign flush_done = (!flush || flush_count == 5'd31);
  
  // assign cachereq_val = memreq_val;
  //assign memreq_rdy = cachereq_rdy;
  //assign cachereq_msg = memreq_msg;

  // assign memresp_val = cacheresp_val;
  assign cacheresp_rdy = memresp_rdy;
  //assign memresp_msg = cacheresp_msg;
//   assign flush_done = flush;


endmodule


`endif  /* RISCV_CACHE_BASE_V */
