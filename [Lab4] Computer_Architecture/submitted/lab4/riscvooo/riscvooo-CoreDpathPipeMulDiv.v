//========================================================================
// Functional Pipelined Mul/Div Unit
//========================================================================

`ifndef RISCV_PIPE_MULDIV_ITERATIVE_V
`define RISCV_PIPE_MULDIV_ITERATIVE_V

`include "imuldiv-MulDivReqMsg.v"

module riscv_CoreDpathPipeMulDiv
(
  input         clk,
  input         reset,
  input         stall_mult0,
  input         stall_mult1,

  input   [2:0] muldivreq_msg_fn,
  input  [31:0] muldivreq_msg_a,
  input  [31:0] muldivreq_msg_b,
  input         muldivreq_val,
  output        muldivreq_rdy,

  output [63:0] muldivresp_msg_result,
  output        muldivresp_val,
  input         muldivresp_rdy
);

  // Set request ready if not stalled

  assign muldivreq_rdy = (!stall) && (!stall_mult1) && (!stall_mult0);
  wire   muldivreq_go  = muldivreq_val && muldivreq_rdy;
  //----------------------------------------------------------------------
  // Input Registers
  //----------------------------------------------------------------------

  reg  [2:0] fn_reg;
  reg [31:0] a_reg;
  reg [31:0] b_reg;
  reg        val0_reg;

  always @ ( posedge clk ) begin
    if ( !reset ) begin
      if ( muldivreq_go ) begin
        fn_reg   <= muldivreq_msg_fn;
        a_reg    <= muldivreq_msg_a;
        b_reg    <= muldivreq_msg_b;
        val0_reg <= 1'b1;
      end
      else if ( !stall  && !stall_mult1 & !stall_mult0) begin
        val0_reg <= 1'b0;
      end
    end
    else begin
      val0_reg <= 1'b0;
    end
  end


  //----------------------------------------------------------------------
  // Functional Computation
  //----------------------------------------------------------------------

  // Sign of mul and div

  wire sign = ( a_reg[31] ^ b_reg[31] );

  // Unsigned operands

  wire [31:0] a_unsign   = ( a_reg[31] == 1'b1 ) ? ( ~a_reg + 1'b1 )
                         :                         a_reg;
  wire [31:0] b_unsign   = ( b_reg[31] == 1'b1 ) ? ( ~b_reg + 1'b1 )
                         :                         b_reg;

  // Unsigned computation

  wire [31:0] quotientu  = a_reg / b_reg;
  wire [31:0] remainderu = a_reg % b_reg;

  // Signed computation

  wire [63:0] product_raw   = a_unsign * b_unsign;
  wire [31:0] quotient_raw  = a_unsign / b_unsign;
  wire [31:0] remainder_raw = a_unsign % b_unsign;

  // Signed Product

  wire [63:0] product
    = ( sign ) ? ( ~product_raw + 1'b1 )
               : product_raw;

  // Signed Quotient

  wire [31:0] quotient
    = ( sign ) ? ( ~quotient_raw + 1'b1 )
               : quotient_raw;

  // Remainder is same sign as dividend

  wire [31:0] remainder
    = ( a_reg[31] ) ? ( ~remainder_raw + 1'b1 )
    :                 remainder_raw;

  // Result mux

  wire [63:0] result0
    = ( fn_reg == `IMULDIV_MULDIVREQ_MSG_FUNC_MUL  ) ? product
    : ( fn_reg == `IMULDIV_MULDIVREQ_MSG_FUNC_DIV  ) ? { remainder, quotient }
    : ( fn_reg == `IMULDIV_MULDIVREQ_MSG_FUNC_DIVU ) ? { remainderu, quotientu }
    : ( fn_reg == `IMULDIV_MULDIVREQ_MSG_FUNC_REM  ) ? { remainder, quotient }
    : ( fn_reg == `IMULDIV_MULDIVREQ_MSG_FUNC_REMU ) ? { remainderu, quotientu }
    :                                                  32'bx;

  //----------------------------------------------------------------------
  // Dummy Pipeline Stages
  //----------------------------------------------------------------------

  reg [63:0] result1_reg;
  reg [63:0] result2_reg;
  reg [63:0] result3_reg;
  reg        val1_reg;
  reg        val2_reg;
  reg        val3_reg;

  wire       val2_next = (stall_mult1) ? 1'b0 : val1_reg;
  wire       val1_next = (stall_mult0) ? 1'b0 : val0_reg;
  always @ ( posedge clk ) begin
    if ( !reset ) begin
      if ( !stall ) begin
        if (!stall_mult1) begin
          result1_reg <= result0;
          val1_reg <= val1_next;
        end
        result2_reg <= result1_reg;
        result3_reg <= result2_reg;
        //val1_reg    <= val0_reg;
        //val2_reg    <= val1_reg;
        val2_reg    <= val2_next;
        val3_reg    <= val2_reg;
      end
    end
    else begin
      result1_reg <= 0;
      result2_reg <= 0;
      result3_reg <= 0;
      val1_reg <= 0;
      val2_reg <= 0;
      val3_reg <= 0;
    end
  end

  // Set response data

  assign muldivresp_msg_result = result3_reg;

  // Set response valid

  assign muldivresp_val = val3_reg;

  // Stall signal

  wire stall = val3_reg && !muldivresp_rdy;

endmodule

`endif
