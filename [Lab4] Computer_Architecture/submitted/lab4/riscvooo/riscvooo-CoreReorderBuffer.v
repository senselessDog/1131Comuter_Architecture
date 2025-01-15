//=========================================================================
// 5-Stage RISCV Reorder Buffer
//=========================================================================

`ifndef RISCV_CORE_REORDERBUFFER_V
`define RISCV_CORE_REORDERBUFFER_V

module riscv_CoreReorderBuffer
(
  input         clk,
  input         reset,
  
  // Allocation Port (Decode Stage)
  input         rob_alloc_req_val,    // Request to allocate new entry 
  output        rob_alloc_req_rdy,    // ROB has space for new entry
  input  [ 4:0] rob_alloc_req_preg,   // Physical register to write
  output [ 3:0] rob_alloc_resp_slot,  // Allocated ROB slot

  // Fill Port (Writeback Stage)
  input         rob_fill_val,         // Valid writeback data 
  input  [ 3:0] rob_fill_slot,        // ROB slot to write

  // Commit Port (For Datapath)
  output        rob_commit_wen,       // Valid commit
  output [ 3:0] rob_commit_slot,      // Slot being committed
  output [ 4:0] rob_commit_rf_waddr   // Register to write during commit
);

  // ROB size and pointers
  parameter ROB_SIZE = 16;
  reg [3:0] head_ptr;  // Next to commit
  reg [3:0] tail_ptr;  // Next available entry

  // Internal state
  reg  [ROB_SIZE-1:0] valid;     // Valid bits for each entry
  reg  [ROB_SIZE-1:0] pending;   // Pending bits for each entry  
  reg  [ 4:0] preg [ROB_SIZE-1:0]; // Physical register numbers

  // Allocation logic
  wire full = (head_ptr == (tail_ptr + 1)) || 
             (head_ptr == 0 && tail_ptr == ROB_SIZE-1); // Check if ROB is full
             
  assign rob_alloc_req_rdy = !full;
  assign rob_alloc_resp_slot = tail_ptr;

  // Fill logic (clear pending bit when result arrives)
  always @(posedge clk) begin
    if(rob_fill_val) begin
      pending[rob_fill_slot] <= 1'b0;
    end
  end

  // Commit logic
  wire head_valid = valid[head_ptr];
  wire head_ready = !pending[head_ptr];
  
  assign rob_commit_wen = head_valid && head_ready;
  assign rob_commit_slot = head_ptr;
  assign rob_commit_rf_waddr = preg[head_ptr];

  // Update pointers and state
  always @(posedge clk) begin
    if(reset) begin
      head_ptr <= 4'b0;
      tail_ptr <= 4'b0;
      valid <= {ROB_SIZE{1'b0}};
      pending <= {ROB_SIZE{1'b0}};
    end
    else begin
      // Allocate new entry
      if(rob_alloc_req_val && rob_alloc_req_rdy) begin
        valid[tail_ptr] <= 1'b1;
        pending[tail_ptr] <= 1'b1;
        preg[tail_ptr] <= rob_alloc_req_preg;
        tail_ptr <= (tail_ptr == ROB_SIZE-1) ? 4'd0 : tail_ptr + 4'd1;
      end

      // Commit entry
      if(rob_commit_wen) begin
        valid[head_ptr] <= 1'b0;
        head_ptr <= (head_ptr == ROB_SIZE-1) ? 4'd0 : head_ptr + 4'd1;
      end
    end
  end

endmodule

`endif