//========================================================================
// Unit Tests: Test Source/Sink
//========================================================================

`include "vc-TestRandDelaySource.v"
`include "vc-TestRandDelaySink.v"
`include "vc-TestTriplePortRandDelayMem.v"
`include "vc-Test.v"

//------------------------------------------------------------------------
// Test Harness
//------------------------------------------------------------------------

module TestHarness
#(
  parameter p_mem_sz  = 1024,    // size of physical memory in bytes
  parameter p_addr_sz = 8,       // size of mem message address in bits
  parameter p_data_sz = 32,      // size of mem message data in bits
  parameter p_src_max_delay = 0, // max random delay for source
  parameter p_mem_max_delay = 0, // max random delay for memory
  parameter p_sink_max_delay = 0 // max random delay for sink
)(
  input  clk,
  input  reset,
  output done
);

  // Local parameters

  localparam c_req_msg_sz  = `VC_MEM_REQ_MSG_SZ(p_addr_sz,p_data_sz);
  localparam c_resp_msg_sz = `VC_MEM_RESP_MSG_SZ(p_data_sz);

  // Test source for port 0

  wire                    memreq0_val;
  wire                    memreq0_rdy;
  wire [c_req_msg_sz-1:0] memreq0_msg;

  wire                    src0_done;

  vc_TestRandDelaySource#(c_req_msg_sz,1024,p_src_max_delay) src0
  (
    .clk         (clk),
    .reset       (reset),

    .val         (memreq0_val),
    .rdy         (memreq0_rdy),
    .msg         (memreq0_msg),

    .done        (src0_done)
  );

  // Test source for port 1

  wire                    memreq1_val;
  wire                    memreq1_rdy;
  wire [c_req_msg_sz-1:0] memreq1_msg;

  wire                    src1_done;

  vc_TestRandDelaySource#(c_req_msg_sz,1024,p_src_max_delay) src1
  (
    .clk         (clk),
    .reset       (reset),

    .val         (memreq1_val),
    .rdy         (memreq1_rdy),
    .msg         (memreq1_msg),

    .done        (src1_done)
  );

  // Test source for port 2

  wire                    memreq2_val;
  wire                    memreq2_rdy;
  wire [c_req_msg_sz-1:0] memreq2_msg;

  wire                    src2_done;

  vc_TestRandDelaySource#(c_req_msg_sz,1024,p_src_max_delay) src2
  (
    .clk         (clk),
    .reset       (reset),

    .val         (memreq2_val),
    .rdy         (memreq2_rdy),
    .msg         (memreq2_msg),

    .done        (src2_done)
  );

  // Test memory

  wire                     memresp0_val;
  wire                     memresp0_rdy;
  wire [c_resp_msg_sz-1:0] memresp0_msg;

  wire                     memresp1_val;
  wire                     memresp1_rdy;
  wire [c_resp_msg_sz-1:0] memresp1_msg;

  wire                     memresp2_val;
  wire                     memresp2_rdy;
  wire [c_resp_msg_sz-1:0] memresp2_msg;

  vc_TestTriplePortRandDelayMem#(p_mem_sz,p_addr_sz,p_data_sz,p_mem_max_delay) mem
  (
    .clk         (clk),
    .reset       (reset),

    .memreq0_val  (memreq0_val),
    .memreq0_rdy  (memreq0_rdy),
    .memreq0_msg  (memreq0_msg),

    .memresp0_val (memresp0_val),
    .memresp0_rdy (memresp0_rdy),
    .memresp0_msg (memresp0_msg),

    .memreq1_val  (memreq1_val),
    .memreq1_rdy  (memreq1_rdy),
    .memreq1_msg  (memreq1_msg),

    .memresp1_val (memresp1_val),
    .memresp1_rdy (memresp1_rdy),
    .memresp1_msg (memresp1_msg),

    .memreq2_val  (memreq2_val),
    .memreq2_rdy  (memreq2_rdy),
    .memreq2_msg  (memreq2_msg),

    .memresp2_val (memresp2_val),
    .memresp2_rdy (memresp2_rdy),
    .memresp2_msg (memresp2_msg)
  );

  // Test sink for port 0

  wire sink0_done;

  vc_TestRandDelaySink#(c_resp_msg_sz,1024,p_sink_max_delay) sink0
  (
    .clk   (clk),
    .reset (reset),

    .val   (memresp0_val),
    .rdy   (memresp0_rdy),
    .msg   (memresp0_msg),

    .done  (sink0_done)
  );

  // Test sink for port 1

  wire sink1_done;

  vc_TestRandDelaySink#(c_resp_msg_sz,1024,p_sink_max_delay) sink1
  (
    .clk   (clk),
    .reset (reset),

    .val   (memresp1_val),
    .rdy   (memresp1_rdy),
    .msg   (memresp1_msg),

    .done  (sink1_done)
  );

  // Test sink for port 2

  wire sink2_done;

  vc_TestRandDelaySink#(c_resp_msg_sz,1024,p_sink_max_delay) sink2
  (
    .clk   (clk),
    .reset (reset),

    .val   (memresp2_val),
    .rdy   (memresp2_rdy),
    .msg   (memresp2_msg),

    .done  (sink2_done)
  );

  // Done when both source and sink are done for both ports

  assign done = src0_done & sink0_done & src1_done & sink1_done & src2_done & sink2_done;

endmodule

//------------------------------------------------------------------------
// Main Tester Module
//------------------------------------------------------------------------

module tester;

  `VC_TEST_SUITE_BEGIN( "vc-TestTriplePortRandDelayMem" )

  //----------------------------------------------------------------------
  // localparams
  //----------------------------------------------------------------------

  localparam c_req_rd  = `VC_MEM_REQ_MSG_TYPE_READ;
  localparam c_req_wr  = `VC_MEM_REQ_MSG_TYPE_WRITE;

  localparam c_resp_rd = `VC_MEM_RESP_MSG_TYPE_READ;
  localparam c_resp_wr = `VC_MEM_RESP_MSG_TYPE_WRITE;

  //----------------------------------------------------------------------
  // TestBasic_srcdelay0_memdelay0_sinkdelay0
  //----------------------------------------------------------------------

  wire t0_done;
  reg  t0_reset = 1;

  TestHarness
  #(
    .p_mem_sz         (1024),
    .p_addr_sz        (16),
    .p_data_sz        (32),
    .p_src_max_delay  (0),
    .p_mem_max_delay  (0),
    .p_sink_max_delay (0)
  )
  t0
  (
    .clk   (clk),
    .reset (t0_reset),
    .done  (t0_done)
  );

  // Port 0 Source-Sink helper tasks

  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t0_req0;
  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t0_req1;
  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t0_req2;
  reg [`VC_MEM_RESP_MSG_SZ(32)-1:0]   t0_resp;

  task t0_mk_req_resp
  (
    input [1023:0] index,

    input [`VC_MEM_REQ_MSG_TYPE_SZ(16,32)-1:0] req_type,
    input [`VC_MEM_REQ_MSG_ADDR_SZ(16,32)-1:0] req_addr,
    input [`VC_MEM_REQ_MSG_LEN_SZ(16,32)-1:0]  req_len,
    input [`VC_MEM_REQ_MSG_DATA_SZ(16,32)-1:0] req_data,

    input [`VC_MEM_RESP_MSG_TYPE_SZ(32)-1:0]   resp_type,
    input [`VC_MEM_RESP_MSG_LEN_SZ(32)-1:0]    resp_len,
    input [`VC_MEM_RESP_MSG_DATA_SZ(32)-1:0]   resp_data
  );
  begin
    t0_req0[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t0_req0[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr;
    t0_req0[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t0_req0[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t0_req1[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t0_req1[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr + 500;
    t0_req1[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t0_req1[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t0_req2[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t0_req2[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr + 1000;
    t0_req2[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t0_req2[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t0_resp[`VC_MEM_RESP_MSG_TYPE_FIELD(32)]  = resp_type;
    t0_resp[`VC_MEM_RESP_MSG_LEN_FIELD(32)]   = resp_len;
    t0_resp[`VC_MEM_RESP_MSG_DATA_FIELD(32)]  = resp_data;

    // Port 0 Source-Sink

    t0.src0.src.m[index]   = t0_req0;
    t0.sink0.sink.m[index] = t0_resp;

    // Port 1 Source-Sink
    //--------------------------------------------------------------------
    // Set the address to a large enough offset that there will not be
    // overlap between port 0 and port 1 requests.

    t0.src1.src.m[index]   = t0_req1;
    t0.sink1.sink.m[index] = t0_resp;

    // Port 2 Source-Sink
    //--------------------------------------------------------------------
    // Set the address to a large enough offset that there will not be
    // overlap between port 0 and port 2 requests.

    t0.src2.src.m[index]   = t0_req2;
    t0.sink2.sink.m[index] = t0_resp;
  end
  endtask

  // Actual test case

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end

  `VC_TEST_CASE_BEGIN( 1, "TestBasic_srcdelay0_memdelay0_sinkdelay0" )
  begin

    //                  ----------- memory request -----------  ------ memory response -------
    //              idx type      addr      len   data          type       len   data

    t0_mk_req_resp( 0,  c_req_wr, 16'h0000, 2'd0, 32'h0a0b0c0d, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0000
    t0_mk_req_resp( 1,  c_req_wr, 16'h0004, 2'd0, 32'h0e0f0102, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0004

    t0_mk_req_resp( 2,  c_req_rd, 16'h0000, 2'd0, 32'hxxxxxxxx, c_resp_rd, 2'd0, 32'h0a0b0c0d ); // read  word  0x0000
    t0_mk_req_resp( 3,  c_req_rd, 16'h0004, 2'd0, 32'hxxxxxxxx, c_resp_rd, 2'd0, 32'h0e0f0102 ); // read  word  0x0004

    t0_mk_req_resp( 4,  c_req_wr, 16'h0008, 2'd0, 32'h0a0b0c0d, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0008
    t0_mk_req_resp( 5,  c_req_wr, 16'h0008, 2'd1, 32'hdeadbeef, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write byte  0x0008
    t0_mk_req_resp( 6,  c_req_rd, 16'h0008, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxxef ); // read  byte  0x0008
    t0_mk_req_resp( 7,  c_req_rd, 16'h0009, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0c ); // read  byte  0x0009
    t0_mk_req_resp( 8,  c_req_rd, 16'h000a, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0b ); // read  byte  0x000a
    t0_mk_req_resp( 9,  c_req_rd, 16'h000b, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0a ); // read  byte  0x000b

    t0_mk_req_resp(10,  c_req_wr, 16'h000c, 2'd0, 32'h01020304, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x000c
    t0_mk_req_resp(11,  c_req_wr, 16'h000c, 2'd2, 32'hdeadbeef, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write hword 0x000c
    t0_mk_req_resp(12,  c_req_rd, 16'h000c, 2'd2, 32'hxxxxxxxx, c_resp_rd, 2'd2, 32'hxxxxbeef ); // read  hword 0x000c
    t0_mk_req_resp(13,  c_req_rd, 16'h000e, 2'd2, 32'hxxxxxxxx, c_resp_rd, 2'd2, 32'hxxxx0102 ); // read  hword 0x000e

    #1;   t0_reset = 1'b1;
    #20;  t0_reset = 1'b0;
    #500; `VC_TEST_CHECK( "Is sink finished?", t0_done )

  end
  `VC_TEST_CASE_END

  //----------------------------------------------------------------------
  // TestBasic_srcdelay3_memdelay2_sinkdelay10
  //----------------------------------------------------------------------

  wire t1_done;
  reg  t1_reset = 1;

  TestHarness
  #(
    .p_mem_sz         (1024),
    .p_addr_sz        (16),
    .p_data_sz        (32),
    .p_src_max_delay  (3),
    .p_mem_max_delay  (2),
    .p_sink_max_delay (10)
  )
  t1
  (
    .clk   (clk),
    .reset (t1_reset),
    .done  (t1_done)
  );

  // Helper tasks

  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t1_req0;
  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t1_req1;
  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t1_req2;
  reg [`VC_MEM_RESP_MSG_SZ(32)-1:0]   t1_resp;

  task t1_mk_req_resp
  (
    input [1023:0] index,

    input [`VC_MEM_REQ_MSG_TYPE_SZ(16,32)-1:0] req_type,
    input [`VC_MEM_REQ_MSG_ADDR_SZ(16,32)-1:0] req_addr,
    input [`VC_MEM_REQ_MSG_LEN_SZ(16,32)-1:0]  req_len,
    input [`VC_MEM_REQ_MSG_DATA_SZ(16,32)-1:0] req_data,

    input [`VC_MEM_RESP_MSG_TYPE_SZ(32)-1:0]   resp_type,
    input [`VC_MEM_RESP_MSG_LEN_SZ(32)-1:0]    resp_len,
    input [`VC_MEM_RESP_MSG_DATA_SZ(32)-1:0]   resp_data
  );
  begin
    t1_req0[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t1_req0[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr;
    t1_req0[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t1_req0[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t1_req1[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t1_req1[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr + 500;
    t1_req1[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t1_req1[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t1_req2[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t1_req2[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr + 1000;
    t1_req2[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t1_req2[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t1_resp[`VC_MEM_RESP_MSG_TYPE_FIELD(32)]  = resp_type;
    t1_resp[`VC_MEM_RESP_MSG_LEN_FIELD(32)]   = resp_len;
    t1_resp[`VC_MEM_RESP_MSG_DATA_FIELD(32)]  = resp_data;

    // Port 0 Source-Sink

    t1.src0.src.m[index]   = t1_req0;
    t1.sink0.sink.m[index] = t1_resp;

    // Port 1 Source-Sink
    //--------------------------------------------------------------------
    // Set the address to a large enough offset that there will not be
    // overlap between port 0 and port 1 requests.

    t1.src1.src.m[index]   = t1_req1;
    t1.sink1.sink.m[index] = t1_resp;

    // Port 2 Source-Sink
    //--------------------------------------------------------------------
    // Set the address to a large enough offset that there will not be
    // overlap between port 0 and port 2 requests.

    t2.src2.src.m[index]   = t2_req2;
    t2.sink2.sink.m[index] = t2_resp;
  end
  endtask

  // Actual test case

  `VC_TEST_CASE_BEGIN( 2, "TestBasic_srcdelay3_memdelay2_sinkdelay10" )
  begin

    //                  ----------- memory request -----------  ------ memory request -------
    //              idx type      addr      len   data          type       len   data

    t1_mk_req_resp( 0,  c_req_wr, 16'h0000, 2'd0, 32'h0a0b0c0d, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0000
    t1_mk_req_resp( 1,  c_req_wr, 16'h0004, 2'd0, 32'h0e0f0102, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0004

    t1_mk_req_resp( 2,  c_req_rd, 16'h0000, 2'd0, 32'hxxxxxxxx, c_resp_rd, 2'd0, 32'h0a0b0c0d ); // read  word  0x0000
    t1_mk_req_resp( 3,  c_req_rd, 16'h0004, 2'd0, 32'hxxxxxxxx, c_resp_rd, 2'd0, 32'h0e0f0102 ); // read  word  0x0004

    t1_mk_req_resp( 4,  c_req_wr, 16'h0008, 2'd0, 32'h0a0b0c0d, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0008
    t1_mk_req_resp( 5,  c_req_wr, 16'h0008, 2'd1, 32'hdeadbeef, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write byte  0x0008
    t1_mk_req_resp( 6,  c_req_rd, 16'h0008, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxxef ); // read  byte  0x0008
    t1_mk_req_resp( 7,  c_req_rd, 16'h0009, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0c ); // read  byte  0x0009
    t1_mk_req_resp( 8,  c_req_rd, 16'h000a, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0b ); // read  byte  0x000a
    t1_mk_req_resp( 9,  c_req_rd, 16'h000b, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0a ); // read  byte  0x000b

    t1_mk_req_resp(10,  c_req_wr, 16'h000c, 2'd0, 32'h01020304, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x000c
    t1_mk_req_resp(11,  c_req_wr, 16'h000c, 2'd2, 32'hdeadbeef, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write hword 0x000c
    t1_mk_req_resp(12,  c_req_rd, 16'h000c, 2'd2, 32'hxxxxxxxx, c_resp_rd, 2'd2, 32'hxxxxbeef ); // read  hword 0x000c
    t1_mk_req_resp(13,  c_req_rd, 16'h000e, 2'd2, 32'hxxxxxxxx, c_resp_rd, 2'd2, 32'hxxxx0102 ); // read  hword 0x000e

    #1;   t1_reset = 1'b1;
    #20;  t1_reset = 1'b0;
    #5000; `VC_TEST_CHECK( "Is sink finished?", t1_done )

  end
  `VC_TEST_CASE_END

  //----------------------------------------------------------------------
  // TestBasic_srcdelay8_memdelay4_sinkdelay2
  //----------------------------------------------------------------------

  wire t2_done;
  reg  t2_reset = 1;

  TestHarness
  #(
    .p_mem_sz         (1024),
    .p_addr_sz        (16),
    .p_data_sz        (32),
    .p_src_max_delay  (8),
    .p_mem_max_delay  (4),
    .p_sink_max_delay (2)
  )
  t2
  (
    .clk   (clk),
    .reset (t2_reset),
    .done  (t2_done)
  );

  // Helper tasks

  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t2_req0;
  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t2_req1;
  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t2_req2;
  reg [`VC_MEM_RESP_MSG_SZ(32)-1:0]   t2_resp;

  task t2_mk_req_resp
  (
    input [1023:0] index,

    input [`VC_MEM_REQ_MSG_TYPE_SZ(16,32)-1:0] req_type,
    input [`VC_MEM_REQ_MSG_ADDR_SZ(16,32)-1:0] req_addr,
    input [`VC_MEM_REQ_MSG_LEN_SZ(16,32)-1:0]  req_len,
    input [`VC_MEM_REQ_MSG_DATA_SZ(16,32)-1:0] req_data,

    input [`VC_MEM_RESP_MSG_TYPE_SZ(32)-1:0]   resp_type,
    input [`VC_MEM_RESP_MSG_LEN_SZ(32)-1:0]    resp_len,
    input [`VC_MEM_RESP_MSG_DATA_SZ(32)-1:0]   resp_data
  );
  begin
    t2_req0[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t2_req0[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr;
    t2_req0[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t2_req0[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t2_req1[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t2_req1[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr + 500;
    t2_req1[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t2_req1[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t2_req2[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t2_req2[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr + 1000;
    t2_req2[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t2_req2[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t2_resp[`VC_MEM_RESP_MSG_TYPE_FIELD(32)]  = resp_type;
    t2_resp[`VC_MEM_RESP_MSG_LEN_FIELD(32)]   = resp_len;
    t2_resp[`VC_MEM_RESP_MSG_DATA_FIELD(32)]  = resp_data;

    // Port 0 Source-Sink

    t2.src0.src.m[index]   = t2_req0;
    t2.sink0.sink.m[index] = t2_resp;

    // Port 1 Source-Sink
    //--------------------------------------------------------------------
    // Set the address to a large enough offset that there will not be
    // overlap between port 0 and port 1 requests.

    t2.src1.src.m[index]   = t2_req1;
    t2.sink1.sink.m[index] = t2_resp;

    // Port 2 Source-Sink
    //--------------------------------------------------------------------
    // Set the address to a large enough offset that there will not be
    // overlap between port 0 and port 2 requests.

    t2.src2.src.m[index]   = t2_req2;
    t2.sink2.sink.m[index] = t2_resp;
  end
  endtask

  // Actual test case

  `VC_TEST_CASE_BEGIN( 3, "TestBasic_srcdelay8_memdelay4_sinkdelay2" )
  begin

    //                  ----------- memory request -----------  ------ memory request -------
    //              idx type      addr      len   data          type       len   data

    t2_mk_req_resp( 0,  c_req_wr, 16'h0000, 2'd0, 32'h0a0b0c0d, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0000
    t2_mk_req_resp( 1,  c_req_wr, 16'h0004, 2'd0, 32'h0e0f0102, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0004

    t2_mk_req_resp( 2,  c_req_rd, 16'h0000, 2'd0, 32'hxxxxxxxx, c_resp_rd, 2'd0, 32'h0a0b0c0d ); // read  word  0x0000
    t2_mk_req_resp( 3,  c_req_rd, 16'h0004, 2'd0, 32'hxxxxxxxx, c_resp_rd, 2'd0, 32'h0e0f0102 ); // read  word  0x0004

    t2_mk_req_resp( 4,  c_req_wr, 16'h0008, 2'd0, 32'h0a0b0c0d, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0008
    t2_mk_req_resp( 5,  c_req_wr, 16'h0008, 2'd1, 32'hdeadbeef, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write byte  0x0008
    t2_mk_req_resp( 6,  c_req_rd, 16'h0008, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxxef ); // read  byte  0x0008
    t2_mk_req_resp( 7,  c_req_rd, 16'h0009, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0c ); // read  byte  0x0009
    t2_mk_req_resp( 8,  c_req_rd, 16'h000a, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0b ); // read  byte  0x000a
    t2_mk_req_resp( 9,  c_req_rd, 16'h000b, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0a ); // read  byte  0x000b

    t2_mk_req_resp(10,  c_req_wr, 16'h000c, 2'd0, 32'h01020304, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x000c
    t2_mk_req_resp(11,  c_req_wr, 16'h000c, 2'd2, 32'hdeadbeef, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write hword 0x000c
    t2_mk_req_resp(12,  c_req_rd, 16'h000c, 2'd2, 32'hxxxxxxxx, c_resp_rd, 2'd2, 32'hxxxxbeef ); // read  hword 0x000c
    t2_mk_req_resp(13,  c_req_rd, 16'h000e, 2'd2, 32'hxxxxxxxx, c_resp_rd, 2'd2, 32'hxxxx0102 ); // read  hword 0x000e

    #1;   t2_reset = 1'b1;
    #20;  t2_reset = 1'b0;
    #5000; `VC_TEST_CHECK( "Is sink finished?", t2_done )

  end
  `VC_TEST_CASE_END

  //----------------------------------------------------------------------
  // TestBasic_srcdelay1_memdelay8_sinkdelay1
  //----------------------------------------------------------------------

  wire t3_done;
  reg  t3_reset = 1;

  TestHarness
  #(
    .p_mem_sz         (1024),
    .p_addr_sz        (16),
    .p_data_sz        (32),
    .p_src_max_delay  (1),
    .p_mem_max_delay  (8),
    .p_sink_max_delay (1)
  )
  t3
  (
    .clk   (clk),
    .reset (t3_reset),
    .done  (t3_done)
  );

  // Helper tasks

  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t3_req0;
  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t3_req1;
  reg [`VC_MEM_REQ_MSG_SZ(16,32)-1:0] t3_req2;
  reg [`VC_MEM_RESP_MSG_SZ(32)-1:0]   t3_resp;

  task t3_mk_req_resp
  (
    input [1023:0] index,

    input [`VC_MEM_REQ_MSG_TYPE_SZ(16,32)-1:0] req_type,
    input [`VC_MEM_REQ_MSG_ADDR_SZ(16,32)-1:0] req_addr,
    input [`VC_MEM_REQ_MSG_LEN_SZ(16,32)-1:0]  req_len,
    input [`VC_MEM_REQ_MSG_DATA_SZ(16,32)-1:0] req_data,

    input [`VC_MEM_RESP_MSG_TYPE_SZ(32)-1:0]   resp_type,
    input [`VC_MEM_RESP_MSG_LEN_SZ(32)-1:0]    resp_len,
    input [`VC_MEM_RESP_MSG_DATA_SZ(32)-1:0]   resp_data
  );
  begin
    t3_req0[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t3_req0[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr;
    t3_req0[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t3_req0[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t3_req1[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t3_req1[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr + 500;
    t3_req1[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t3_req1[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t3_req2[`VC_MEM_REQ_MSG_TYPE_FIELD(16,32)] = req_type;
    t3_req2[`VC_MEM_REQ_MSG_ADDR_FIELD(16,32)] = req_addr + 1000;
    t3_req2[`VC_MEM_REQ_MSG_LEN_FIELD(16,32)]  = req_len;
    t3_req2[`VC_MEM_REQ_MSG_DATA_FIELD(16,32)] = req_data;

    t3_resp[`VC_MEM_RESP_MSG_TYPE_FIELD(32)]  = resp_type;
    t3_resp[`VC_MEM_RESP_MSG_LEN_FIELD(32)]   = resp_len;
    t3_resp[`VC_MEM_RESP_MSG_DATA_FIELD(32)]  = resp_data;

    // Port 0 Source-Sink

    t3.src0.src.m[index]   = t3_req0;
    t3.sink0.sink.m[index] = t3_resp;

    // Port 1 Source-Sink
    //--------------------------------------------------------------------
    // Set the address to a large enough offset that there will not be
    // overlap between port 0 and port 1 requests.

    t3.src1.src.m[index]   = t3_req1;
    t3.sink1.sink.m[index] = t3_resp;

    // Port 2 Source-Sink
    //--------------------------------------------------------------------
    // Set the address to a large enough offset that there will not be
    // overlap between port 0 and port 2 requests.

    t3.src2.src.m[index]   = t3_req2;
    t3.sink2.sink.m[index] = t3_resp;
  end
  endtask

  // Actual test case

  `VC_TEST_CASE_BEGIN( 4, "TestBasic_srcdelay1_memdelay8_sinkdelay1" )
  begin

    //                  ----------- memory request -----------  ------ memory request -------
    //              idx type      addr      len   data          type       len   data

    t3_mk_req_resp( 0,  c_req_wr, 16'h0000, 2'd0, 32'h0a0b0c0d, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0000
    t3_mk_req_resp( 1,  c_req_wr, 16'h0004, 2'd0, 32'h0e0f0102, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0004

    t3_mk_req_resp( 2,  c_req_rd, 16'h0000, 2'd0, 32'hxxxxxxxx, c_resp_rd, 2'd0, 32'h0a0b0c0d ); // read  word  0x0000
    t3_mk_req_resp( 3,  c_req_rd, 16'h0004, 2'd0, 32'hxxxxxxxx, c_resp_rd, 2'd0, 32'h0e0f0102 ); // read  word  0x0004

    t3_mk_req_resp( 4,  c_req_wr, 16'h0008, 2'd0, 32'h0a0b0c0d, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x0008
    t3_mk_req_resp( 5,  c_req_wr, 16'h0008, 2'd1, 32'hdeadbeef, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write byte  0x0008
    t3_mk_req_resp( 6,  c_req_rd, 16'h0008, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxxef ); // read  byte  0x0008
    t3_mk_req_resp( 7,  c_req_rd, 16'h0009, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0c ); // read  byte  0x0009
    t3_mk_req_resp( 8,  c_req_rd, 16'h000a, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0b ); // read  byte  0x000a
    t3_mk_req_resp( 9,  c_req_rd, 16'h000b, 2'd1, 32'hxxxxxxxx, c_resp_rd, 2'd1, 32'hxxxxxx0a ); // read  byte  0x000b

    t3_mk_req_resp(10,  c_req_wr, 16'h000c, 2'd0, 32'h01020304, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write word  0x000c
    t3_mk_req_resp(11,  c_req_wr, 16'h000c, 2'd2, 32'hdeadbeef, c_resp_wr, 2'dx, 32'hxxxxxxxx ); // write hword 0x000c
    t3_mk_req_resp(12,  c_req_rd, 16'h000c, 2'd2, 32'hxxxxxxxx, c_resp_rd, 2'd2, 32'hxxxxbeef ); // read  hword 0x000c
    t3_mk_req_resp(13,  c_req_rd, 16'h000e, 2'd2, 32'hxxxxxxxx, c_resp_rd, 2'd2, 32'hxxxx0102 ); // read  hword 0x000e

    #1;   t3_reset = 1'b1;
    #20;  t3_reset = 1'b0;
    #5000; `VC_TEST_CHECK( "Is sink finished?", t3_done )

  end
  `VC_TEST_CASE_END

  `VC_TEST_SUITE_END( 4 )
endmodule

