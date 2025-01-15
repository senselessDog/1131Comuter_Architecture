`ifndef RISCV_INT_DIV_ITERATIVE_V
`define RISCV_INT_DIV_ITERATIVE_V

`include "imuldiv-DivReqMsg.v"

module imuldiv_IntDivIterative
(
  input         clk,
  input         reset,

  input         divreq_msg_fn,
  input  [31:0] divreq_msg_a,
  input  [31:0] divreq_msg_b,
  input         divreq_val,
  output        divreq_rdy,

  output [63:0] divresp_msg_result,
  output        divresp_val,
  input         divresp_rdy
);

  wire        a_mux_sel;
  wire        a_en;
  wire        b_en;
  wire        sub_mux_sel;
  wire        cntr_mux_sel;
  wire        sign_en;
  wire        div_sign_mux_sel;
  wire        rem_sign_mux_sel;
  wire        sub_out_sign;
  wire [5:0]  counter;
  wire        div_sign;
  wire        rem_sign;

  imuldiv_IntDivIterativeDpath dpath
  (
    .clk                (clk),
    .reset              (reset),
    .divreq_msg_fn      (divreq_msg_fn),
    .divreq_msg_a       (divreq_msg_a),
    .divreq_msg_b       (divreq_msg_b),
    .divreq_val         (divreq_val),
    .divreq_rdy         (divreq_rdy),
    .divresp_msg_result (divresp_msg_result),
    .divresp_val        (divresp_val),
    .divresp_rdy        (divresp_rdy),
    .a_mux_sel          (a_mux_sel),
    .a_en               (a_en),
    .b_en               (b_en),
    .sub_mux_sel        (sub_mux_sel),
    .cntr_mux_sel       (cntr_mux_sel),
    .sign_en            (sign_en),
    .div_sign_mux_sel   (div_sign_mux_sel),
    .rem_sign_mux_sel   (rem_sign_mux_sel),
    .sub_out_sign       (sub_out_sign),
    .counter            (counter),
    .div_sign           (div_sign),
    .rem_sign           (rem_sign)
  );

  imuldiv_IntDivIterativeCtrl ctrl
  (
    .clk                (clk),
    .reset              (reset),
    .divreq_msg_fn      (divreq_msg_fn),
    .divreq_val         (divreq_val),
    .divresp_rdy        (divresp_rdy),
    .sub_out_sign       (sub_out_sign),
    .counter            (counter),
    .divreq_rdy         (divreq_rdy),
    .divresp_val        (divresp_val),
    .a_mux_sel          (a_mux_sel),
    .a_en               (a_en),
    .b_en               (b_en),
    .sub_mux_sel        (sub_mux_sel),
    .cntr_mux_sel       (cntr_mux_sel),
    .sign_en            (sign_en),
    .div_sign_mux_sel   (div_sign_mux_sel),
    .rem_sign_mux_sel   (rem_sign_mux_sel),
    .div_sign           (div_sign),
    .rem_sign           (rem_sign)
  );

endmodule
module imuldiv_IntDivIterativeDpath
(
  input         clk,
  input         reset,

  input         divreq_msg_fn,
  input  [31:0] divreq_msg_a,
  input  [31:0] divreq_msg_b,
  input         divreq_val,
  output        divreq_rdy,

  output [63:0] divresp_msg_result,
  output        divresp_val,
  input         divresp_rdy,

  // Control signals
  input         a_mux_sel,
  input         a_en,
  input         b_en,
  input         sub_mux_sel,
  input         cntr_mux_sel,
  input         sign_en,
  input         div_sign_mux_sel,
  input         rem_sign_mux_sel,
  output        sub_out_sign,
  output [5:0]  counter,
  //新增的
  output        div_sign,
  output        rem_sign
);

  // Registers
  reg  [64:0] a_reg;
  reg  [64:0] b_reg;
  reg  [5:0]  counter_reg;
  reg         div_sign_reg;
  reg         rem_sign_reg;

  // Wires
  wire [31:0] unsigned_a, unsigned_b;
  wire [64:0] a_shift_out, sub_out, sub_mx_out;
  wire [31:0] signed_res_div, signed_res_rem;

  // Unsign logic
  assign unsigned_a = (divreq_msg_a[31] && (divreq_msg_fn)) ? (~divreq_msg_a + 1'b1) : divreq_msg_a;
  assign unsigned_b = (divreq_msg_b[31] && (divreq_msg_fn)) ? (~divreq_msg_b + 1'b1) : divreq_msg_b;

  // A mux and register
  always @(posedge clk) begin
    if (reset)
      a_reg <= 65'b0;
    else if (a_en)
      a_reg <= a_mux_sel ? {33'b0, unsigned_a} : sub_mx_out;
  end

  // B register
  always @(posedge clk) begin
    if (reset)
      b_reg <= 65'b0;
    else if (b_en)
      b_reg <= {1'b0, unsigned_b, 32'b0};
  end

  // Subtractor
  assign sub_out = a_shift_out - b_reg;

  // Subtractor mux
  assign sub_mx_out = sub_mux_sel ? {sub_out[64:1], 1'b1} : a_shift_out;

  // A shift
  assign a_shift_out = {a_reg[63:0], 1'b0};

  // Counter
  always @(posedge clk) begin
    if (reset)
	//是試32
      counter_reg <= 6'd31;
    else
      counter_reg <= cntr_mux_sel ? counter_reg - 1'b1 : 6'd31;
  end
  assign counter = counter_reg;

  // Sign registers
  always @(posedge clk) begin
    if (reset) begin
      div_sign_reg <= 1'b0;
      rem_sign_reg <= 1'b0;
    end
    else if (sign_en) begin
      div_sign_reg <= divreq_msg_a[31] ^ divreq_msg_b[31];
      rem_sign_reg <= divreq_msg_a[31];
    end
  end
  assign div_sign = div_sign_reg;
  assign rem_sign = rem_sign_reg; 

  // Sign logic
  assign signed_res_div = div_sign_mux_sel ? (~a_reg[31:0] + 1'b1) : a_reg[31:0];
  assign signed_res_rem = rem_sign_mux_sel ? (~a_reg[63:32] + 1'b1) : a_reg[63:32];

  // Output
  // 更改的
  assign divresp_msg_result = divresp_val? {signed_res_rem, signed_res_div}: divresp_msg_result;
  assign sub_out_sign = sub_out[64];

endmodule

module imuldiv_IntDivIterativeCtrl
(
  input         clk,
  input         reset,
  //
  input         divreq_msg_fn,
  input         divreq_val,
  input         divresp_rdy,
  input         sub_out_sign,
  input  [5:0]  counter,
  input        div_sign,
  input        rem_sign,

  output        divreq_rdy,
  output        divresp_val,
  output        a_mux_sel,
  output        a_en,
  output        b_en,
  output        sub_mux_sel,
  output        cntr_mux_sel,
  output        sign_en,
  output        div_sign_mux_sel,
  output        rem_sign_mux_sel
);

  // States
  localparam IDLE = 2'd0;
  localparam CALC = 2'd1;
  localparam DONE = 2'd2;

  reg [1:0] state, next_state;

  // State transition logic
  always @(posedge clk) begin
    if (reset)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next state logic
  always @(*) begin
    case (state)
      IDLE: next_state = divreq_val ? CALC : IDLE;
      // 我把它設成低於零才會進到done
      CALC: next_state = (counter == 6'd0) ? DONE : CALC;
      DONE: next_state = divresp_rdy ? IDLE : DONE;
      default: next_state = IDLE;
    endcase
  end

  // Output logic
  assign divreq_rdy = (state == IDLE);
  assign divresp_val = (state == DONE);
  assign a_mux_sel = (state == IDLE);
  assign a_en = (state == IDLE) || (state == CALC);
  assign b_en = (state == IDLE);
  //此處修改，因為可能最後一輪才相等
  assign sub_mux_sel = (state == CALC)&& !sub_out_sign;
  assign cntr_mux_sel = (state==CALC);
  assign sign_en = (state == IDLE);
  //
  assign div_sign_mux_sel = (state == DONE) && div_sign && divreq_msg_fn;
  assign rem_sign_mux_sel = (state == DONE) && rem_sign && divreq_msg_fn;

endmodule

`endif
