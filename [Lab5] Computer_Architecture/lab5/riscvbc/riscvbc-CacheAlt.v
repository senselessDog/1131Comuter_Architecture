//=========================================================================
// Cache Alt Design
//=========================================================================

`ifndef RISCV_CACHE_ALT_V
`define RISCV_CACHE_ALT_V
`include "vc-RAMs.v"

module riscv_CacheAlt (
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

  vc_MemRespMsgFromBits#(32) cacheresp_msg_from_bits (
    .bits (cacheresp_msg),
    .type (cacheresp_msg_type),
    .len  (),
    .data (cacheresp_msg_data)
  );

  // Cache state machine states
  localparam STATE_IDLE = 4'd0;           
  localparam STATE_TAG_CHECK = 4'd1;      
  localparam STATE_READ_DATA = 4'd2;      
  localparam STATE_WRITE_DATA = 4'd3;     
  localparam STATE_WRITEBACK = 4'd4;      
  localparam STATE_WRITEBACK_WAIT = 4'd5;  
  localparam STATE_REFILL = 4'd6;         
  localparam STATE_REFILL_WAIT = 4'd7;    
  localparam STATE_REFILL_UPDATE = 4'd8;   
  localparam STATE_FLUSH_START = 4'd9;     
  localparam STATE_FLUSH_WAIT = 4'd10;     

  // State registers
  reg [3:0] state;
  reg [3:0] next_state;

  // Address parsing
  wire [5:0]  offset    = memreq_msg_addr[5:0];   // 64B blocks -> 6 bits
  wire [4:0]  index     = memreq_msg_addr[10:6];  // 32 sets -> 5 bits  
  wire [20:0] tag       = memreq_msg_addr[31:11]; // Rest is tag
  
  wire [3:0]  word_offset = offset[5:2];  // Which word in block
  reg  [3:0]  refill_count;               
  reg  [3:0]  writeback_count;            
  reg  [4:0]  flush_count;                

  // Cache line tracking
  reg  [31:0] refill_addr;    
  reg  [4:0]  read_index;     
  wire [31:0] block_addr;     
  reg         way_select;     // Which way to access
  reg         lru_bits[31:0]; // LRU bits for each set
  
  assign block_addr = {memreq_msg_addr[31:6], 6'b0};

  // Tag RAM signals for both ways
  reg  tag_wen0, tag_wen1;
  wire [22:0] tag_wdata0, tag_wdata1;  // 21 tag + 1 valid + 1 dirty
  wire [22:0] tag_rdata0, tag_rdata1;
  
  assign tag_wdata0 = {tag, 1'b1, state == STATE_WRITE_DATA}; 
  assign tag_wdata1 = {tag, 1'b1, state == STATE_WRITE_DATA};

  // Data RAM signals  
  reg  data_wen0, data_wen1;
  reg  [31:0] data_wdata0, data_wdata1;
  wire [31:0] data_rdata0, data_rdata1;
  reg  [8:0]  data_addr;   
  reg  [8:0]  memreq_data_addr;

  // Tag RAMs 
  vc_RAM_1w1r_pf #(
    .DATA_SZ(23),         
    .ENTRIES(32),         
    .ADDR_SZ(5)           
  ) tag_ram0 (
    .clk(clk),
    .raddr(read_index),
    .rdata(tag_rdata0),
    .wen_p(tag_wen0),
    .waddr_p(state == STATE_FLUSH_START ? flush_count : index),
    .wdata_p(tag_wdata0)
  );

  vc_RAM_1w1r_pf #(
    .DATA_SZ(23),         
    .ENTRIES(32),         
    .ADDR_SZ(5)           
  ) tag_ram1 (
    .clk(clk),
    .raddr(read_index),
    .rdata(tag_rdata1),
    .wen_p(tag_wen1),
    .waddr_p(state == STATE_FLUSH_START ? flush_count : index),
    .wdata_p(tag_wdata1)
  );

  // Data RAMs
  vc_RAM_1w1r_pf #(
    .DATA_SZ(32),        
    .ENTRIES(512),       
    .ADDR_SZ(9)          
  ) data_ram0 (
    .clk(clk),
    .raddr(data_addr),
    .rdata(data_rdata0),
    .wen_p(data_wen0),
    .waddr_p(data_addr),
    .wdata_p(data_wdata0)
  );

  vc_RAM_1w1r_pf #(
    .DATA_SZ(32),        
    .ENTRIES(512),       
    .ADDR_SZ(9)          
  ) data_ram1 (
    .clk(clk),
    .raddr(data_addr),
    .rdata(data_rdata1),
    .wen_p(data_wen1),
    .waddr_p(data_addr),
    .wdata_p(data_wdata1)
  );

  // Tag comparison and status
  wire tag_match0 = (tag_rdata0[22:2] == tag) && tag_rdata0[1];  
  wire tag_match1 = (tag_rdata1[22:2] == tag) && tag_rdata1[1];
  wire is_dirty = way_select ? tag_rdata1[0] : tag_rdata0[0];    
  wire is_write = memreq_msg_type == `VC_MEM_REQ_MSG_TYPE_WRITE;
  wire cache_hit = (tag_match0 || tag_match1) && state == STATE_TAG_CHECK;

  // LRU update logic
  always @(posedge clk) begin
    if (reset) begin
      for (integer i = 0; i < 32; i = i + 1)
        lru_bits[i] <= 0;
    end else if (state == STATE_READ_DATA || state == STATE_WRITE_DATA) begin
      lru_bits[index] <= tag_match0;  // 1 means way1 is LRU
    end
  end

  // Response message construction
  vc_MemRespMsgToBits#(32) memresp_msg_to_bits (
    .type(memreq_msg_type),  
    .len(memreq_msg_len),
    .data(way_select ? data_rdata1 : data_rdata0),
    .bits(memresp_msg)
  );

  // Request message to memory construction  
  vc_MemReqMsgToBits#(32,32) cachereq_msg_to_bits (
    .type(state == STATE_WRITEBACK ? `VC_MEM_REQ_MSG_TYPE_WRITE : `VC_MEM_REQ_MSG_TYPE_READ),
    .addr(state == STATE_WRITEBACK ? {memreq_msg_addr[31:6], writeback_count[3:0], 2'b0} : {memreq_msg_addr[31:6], refill_count[3:0], 2'b0}),
    .len(2'b0),
    .data(way_select ? data_rdata1 : data_rdata0),
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
        if (tag_match0 || tag_match1) begin
          if (is_write)
            next_state = STATE_WRITE_DATA;
          else
            next_state = STATE_READ_DATA;
        end else begin
          if ((way_select && tag_rdata1[0]) || (!way_select && tag_rdata0[0]))
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
        if ((tag_rdata0[1] && tag_rdata0[0]) || (tag_rdata1[1] && tag_rdata1[0]))
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
      way_select <= 0;
    end else begin
      if (memreq_val)begin
        memreq_data_addr = {index, word_offset};
      end
      state <= next_state;

      case (state)
        STATE_TAG_CHECK: begin
          if (tag_match0)
            way_select <= 0;
          else if (tag_match1)
            way_select <= 1;
          else
            way_select <= lru_bits[index];
        end
      
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
    tag_wen0 = 0;
    tag_wen1 = 0;
    data_wen0 = 0;
    data_wen1 = 0;
    data_addr = memreq_data_addr;
    data_wdata0 = memreq_msg_data;
    data_wdata1 = memreq_msg_data;
    read_index = index;

    case (state)
      STATE_WRITE_DATA: begin
        if (!way_select) begin
          tag_wen0 = 1;
          data_wen0 = 1;
        end else begin
          tag_wen1 = 1;
          data_wen1 = 1;
        end
        data_addr = {index, word_offset};
      end

      STATE_WRITEBACK: begin
        data_addr = {index, writeback_count};
      end
      STATE_REFILL_UPDATE: begin
        if (!way_select) begin
          tag_wen0 = (refill_count == 0);
          data_wen0 = 1;
          data_wdata0 = cacheresp_msg_data;
        end else begin
          tag_wen1 = (refill_count == 0);
          data_wen1 = 1;
          data_wdata1 = cacheresp_msg_data;
        end
        data_addr = {index, refill_count};
      end

      STATE_FLUSH_START: begin
        read_index = flush_count;
      end
    endcase
  end

  // Control Signal Logic
  assign memreq_rdy = (state == STATE_IDLE && !flush);
  assign memresp_val = (state == STATE_READ_DATA);
  assign cachereq_val = (state == STATE_WRITEBACK || state == STATE_REFILL);
  assign cacheresp_rdy = memresp_rdy;
  
  // Way selection for flushing
  reg flush_way_select;
  always @(posedge clk) begin
    if (reset) begin
      flush_way_select <= 0;
    end else if (state == STATE_FLUSH_START) begin
      if (tag_rdata0[1] && tag_rdata0[0])  // way 0 valid and dirty
        flush_way_select <= 0;
      else if (tag_rdata1[1] && tag_rdata1[0])  // way 1 valid and dirty
        flush_way_select <= 1;
    end
  end

  // Flush done when all sets are processed and clean
  wire both_ways_clean = (!tag_rdata0[1] || !tag_rdata0[0]) && 
                        (!tag_rdata1[1] || !tag_rdata1[0]);
  assign flush_done = (!flush || (flush_count == 5'd31 && both_ways_clean));

endmodule

`endif  /* RISCV_CACHE_ALT_V */
