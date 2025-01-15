`ifndef RISCV_INT_MUL_ITERATIVE_V
`define RISCV_INT_MUL_ITERATIVE_V
module imuldiv_IntMulIterative
(
  input                clk,
  input                reset,

  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,
  input         mulreq_val,
  output        mulreq_rdy,

  output [63:0] mulresp_msg_result,
  output        mulresp_val,
  input         mulresp_rdy
);

  wire ctrl_mux_sel_a;
  wire ctrl_mux_sel_b;
  wire ctrl_mux_sel_result;
  //TODO: 新增wire幫助DONE不只一回合的狀況
  wire ctrl_mux_sel_result_reg;
  wire ctrl_add_mux_sel;
  wire ctrl_b_lsb;
  wire ctrl_result_en;

  imuldiv_IntMulIterativeDpath dpath
  (
    .clk                (clk),
    .reset              (reset),
    .mulreq_msg_a       (mulreq_msg_a),
    .mulreq_msg_b       (mulreq_msg_b),
    .mulreq_val         (mulreq_val),
    .mulreq_rdy         (mulreq_rdy),
    .mulresp_msg_result (mulresp_msg_result),
    .mulresp_val        (mulresp_val),
    .mulresp_rdy        (mulresp_rdy),
    .ctrl_mux_sel_a     (ctrl_mux_sel_a),
    .ctrl_mux_sel_b     (ctrl_mux_sel_b),
    .ctrl_mux_sel_result(ctrl_mux_sel_result),
    .ctrl_mux_sel_result_reg(ctrl_mux_sel_result_reg),
    .ctrl_add_mux_sel   (ctrl_add_mux_sel),
    .ctrl_b_lsb         (ctrl_b_lsb),
    .ctrl_result_en     (ctrl_result_en)
  );

  imuldiv_IntMulIterativeCtrl ctrl
  (
    .clk                (clk),
    .reset              (reset),
    .mulreq_val         (mulreq_val),
    .mulreq_rdy         (mulreq_rdy),
    .mulresp_val        (mulresp_val),
    .mulresp_rdy        (mulresp_rdy),
    .ctrl_mux_sel_a     (ctrl_mux_sel_a),
    .ctrl_mux_sel_b     (ctrl_mux_sel_b),
    .ctrl_mux_sel_result(ctrl_mux_sel_result),
    .ctrl_mux_sel_result_reg(ctrl_mux_sel_result_reg),
    .ctrl_add_mux_sel   (ctrl_add_mux_sel),
    .ctrl_b_lsb         (ctrl_b_lsb),
    .ctrl_result_en     (ctrl_result_en)
  );

endmodule

module imuldiv_IntMulIterativeDpath
(
  input         clk,
  input         reset,

  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,
  input         mulreq_val,
  output        mulreq_rdy,

  output [63:0] mulresp_msg_result,
  output        mulresp_val,
  input         mulresp_rdy,

  input         ctrl_mux_sel_a,
  input         ctrl_mux_sel_b,
  input         ctrl_mux_sel_result,
  input         ctrl_mux_sel_result_reg,
  input         ctrl_add_mux_sel,
  output         ctrl_b_lsb,
  input         ctrl_result_en
);

  reg  [63:0] a_reg;
  reg  [31:0] b_reg;
  reg  [63:0] result_reg;
  reg         sign_reg; // 新增：用於存儲結果的符號
  wire [63:0] add_out;
  wire [63:0] a_shift_out;

   // 新增：符號擴展邏輯
  //wire [63:0] sign_extended_a = {{32{mulreq_msg_a[31]}}, mulreq_msg_a};
  wire [31:0] unsigned_a = mulreq_msg_a[31] ? (~mulreq_msg_a + 1'b1) : mulreq_msg_a;
  wire [31:0] unsigned_b = mulreq_msg_b[31] ? (~mulreq_msg_b + 1'b1) : mulreq_msg_b;
  // Muxes
  wire [63:0] a_mux_out = ctrl_mux_sel_a ? a_shift_out : {32'b0, unsigned_a};
  wire [31:0] b_mux_out = ctrl_mux_sel_b ? b_reg >> 1 : unsigned_b;
  wire [63:0] result_mux_out = ctrl_mux_sel_result ? add_mux_out : 64'b0;
  	//同個test中唯一會改變的
  wire [63:0] add_mux_out = ctrl_add_mux_sel ? a_reg+ result_reg : result_reg;


  // Shifter
  assign a_shift_out = {a_reg[62:0], 1'b0};
  
  // Registers
  always @(posedge clk) begin
    if (reset) begin
      a_reg <= 64'b0;
      b_reg <= 32'b0;
      result_reg <= 64'b0;
      sign_reg <= 1'b0;
    end
    a_reg <= a_mux_out;
    b_reg <= b_mux_out;
    //TODO: 新增wire幫助DONE不只一回合的狀況
    if (ctrl_result_en)
      result_reg <= result_mux_out;
	// 新增：在開始新的乘法時保存符號信息
    if (!ctrl_mux_sel_a)
      sign_reg <= mulreq_msg_a[31] ^ mulreq_msg_b[31];
  end
  //把最小的b未決定要不要加
  assign ctrl_b_lsb = b_reg[0];

  // 修改：根據符號調整最終結果
  assign mulresp_msg_result = sign_reg ? (~result_reg+1) : result_reg;

endmodule

module imuldiv_IntMulIterativeCtrl
(
  input         clk,
  input         reset,
  input         mulreq_val,
  output reg    mulreq_rdy,
  output reg    mulresp_val,
  input         mulresp_rdy,
  output reg    ctrl_mux_sel_a,
  output reg    ctrl_mux_sel_b,
  output reg    ctrl_mux_sel_result,
  output reg    ctrl_mux_sel_result_reg,
  output reg    ctrl_add_mux_sel,
  input         ctrl_b_lsb,
  output reg    ctrl_result_en
);

  localparam IDLE = 2'd0, CALC = 2'd1, DONE = 2'd2;
  reg [1:0] state, next_state;
  reg [5:0] counter;

  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      counter <= 6'd0;
    end
    else begin
      state <= next_state;
      if (state == CALC)
        counter <= counter + 1;
      else
        counter <= 6'd0;
    end
  end

  always @(*) begin
    next_state = state;
    mulreq_rdy = 1'b0;
    mulresp_val = 1'b0;
    ctrl_mux_sel_a = 1'b0;
    ctrl_mux_sel_b = 1'b0;
    ctrl_mux_sel_result = 1'b0;
    //TODO: 新增wire幫助DONE不只一回合的狀況
    ctrl_mux_sel_result_reg = 1'b0;
    ctrl_add_mux_sel = 1'b0;
    ctrl_result_en = 1'b0;

    case (state)
      IDLE: begin
        mulreq_rdy = 1'b1;
        ctrl_result_en = 1'b1;
        ctrl_mux_sel_result_reg=1'b0;
        if (mulreq_val) begin
	  next_state = CALC;
          ctrl_mux_sel_a = 1'b0;
          ctrl_mux_sel_b = 1'b0;
          ctrl_mux_sel_result = 1'b0;
        end
      end
      CALC: begin
        ctrl_mux_sel_a = 1'b1;
        ctrl_mux_sel_b = 1'b1;
        ctrl_mux_sel_result = 1'b1;
        ctrl_add_mux_sel = ctrl_b_lsb;
        ctrl_result_en = 1'b1;
        ctrl_mux_sel_result_reg= 1'b1;
        if (counter == 6'd31) begin
          next_state = DONE;
        end
      end
      DONE: begin
        mulresp_val = 1'b1;
        ctrl_result_en = 1'b0;
        if (mulresp_rdy) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule
`endif
