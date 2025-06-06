//=========================================================================
// 7-Stage RISCV Control Unit
//=========================================================================

`ifndef RISCV_CORE_CTRL_V
`define RISCV_CORE_CTRL_V

`include "riscvssc-InstMsg.v"

module riscv_CoreCtrl
(
  input clk,
  input reset,

  // Instruction Memory Port
  output        imemreq0_val,
  input         imemreq0_rdy,
  input  [31:0] imemresp0_msg_data,
  input         imemresp0_val,

  // Instruction Memory Port
  output        imemreq1_val,
  input         imemreq1_rdy,
  input  [31:0] imemresp1_msg_data,
  input         imemresp1_val,

  // Data Memory Port

  output        dmemreq_msg_rw,
  output  [1:0] dmemreq_msg_len,
  output        dmemreq_val,
  input         dmemreq_rdy,
  input         dmemresp_val,

  // Controls Signals (ctrl->dpath)

  output  [1:0] pc_mux_sel_Phl,
  output        steering_mux_sel_Dhl,
  output  [3:0] opA0_byp_mux_sel_Dhl,
  output  [1:0] opA0_mux_sel_Dhl,
  output  [3:0] opA1_byp_mux_sel_Dhl,
  output  [2:0] opA1_mux_sel_Dhl,
  output  [3:0] opB0_byp_mux_sel_Dhl,
  output  [1:0] opB0_mux_sel_Dhl,
  output  [3:0] opB1_byp_mux_sel_Dhl,
  output  [2:0] opB1_mux_sel_Dhl,
  output [31:0] instA_Dhl,
  output [31:0] instB_Dhl,
  output  [3:0] aluA_fn_X0hl,
  output  [3:0] aluB_fn_X0hl,
  output  [2:0] muldivreq_msg_fn_Dhl,
  output        muldivreq_val,
  input         muldivreq_rdy,
  input         muldivresp_val,
  output        muldivresp_rdy,
  output        muldiv_stall_mult1,
  output  [2:0] dmemresp_mux_sel_X1hl,
  output        dmemresp_queue_en_X1hl,
  output        dmemresp_queue_val_X1hl,
  output        muldiv_mux_sel_X3hl,
  output        execute_mux_sel_X3hl,
  output        memex_mux_sel_X1hl,
  output        rfA_wen_out_Whl,
  output  [4:0] rfA_waddr_Whl,
  output        rfB_wen_out_Whl,
  output  [4:0] rfB_waddr_Whl,
  output        stall_Fhl,
  output        stall_Dhl,
  output        stall_X0hl,
  output        stall_X1hl,
  output        stall_X2hl,
  output        stall_X3hl,
  output        stall_Whl, 
  //ADD: stall_1_sel for datapath
  output        stall_1_sel,
  //ADD: stall_0_Dhl to let PC stall when load-use or muldiv hazard
  output        stall_0_Dhl,

  // Control Signals (dpath->ctrl)

  input         branch_cond_eq_X0hl,
  input         branch_cond_ne_X0hl,
  input         branch_cond_lt_X0hl,
  input         branch_cond_ltu_X0hl,
  input         branch_cond_ge_X0hl,
  input         branch_cond_geu_X0hl,
  input  [31:0] proc2csr_data_Whl,

  // CSR Status

  output [31:0] csr_status
);

  //----------------------------------------------------------------------
  // PC Stage: Instruction Memory Request
  //----------------------------------------------------------------------

  // PC Mux Select

  assign pc_mux_sel_Phl
    = brj_taken_X0hl    ? pm_b
    : brj_taken_Dhl    ? pc_mux_sel_Dhl
    :                    pm_p;

  // Only send a valid imem request if not stalled

  wire   imemreq_val_Phl = reset || !stall_Phl;
  assign imemreq0_val     = imemreq_val_Phl;
  assign imemreq1_val     = imemreq_val_Phl;

  // Dummy Squash Signal

  wire squash_Phl = 1'b0;

  // Stall in PC if F is stalled

  wire stall_Phl = stall_Fhl;

  // Next bubble bit
  //MODIFY:把stall_Phl給刪掉

  wire bubble_next_Phl = ( squash_Phl);

  //----------------------------------------------------------------------
  // F <- P
  //----------------------------------------------------------------------

  reg imemreq_val_Fhl;

  reg bubble_Fhl;

  always @ ( posedge clk ) begin
    // Only pipeline the bubble bit if the next stage is not stalled
    if ( reset ) begin
      imemreq_val_Fhl <= 1'b0;

      bubble_Fhl <= 1'b0;
    end
    else if( !stall_Fhl ) begin 
      imemreq_val_Fhl <= imemreq_val_Phl;

      bubble_Fhl <= bubble_next_Phl;
    end
    else begin 
      imemreq_val_Fhl <= imemreq_val_Phl;
    end
  end


  //----------------------------------------------------------------------
  // Fetch Stage: Instruction Memory Response
  //----------------------------------------------------------------------

  // Is the current stage valid?

  wire inst_val_Fhl = ( !bubble_Fhl && !squash_Fhl );

  // Squash instruction in F stage if branch taken for a valid
  // instruction or if there was an exception in X stage

  wire squash_Fhl
    = ( inst_val_Dhl && brj_taken_Dhl )
   || ( inst_val_X0hl && brj_taken_X0hl );

  // Stall in F if D is stalled
  //MODIFY: 更新stall_Fhl
  assign stall_Fhl = (stall_Dhl || case4_hazard_stall);

  // Next bubble bit
  //MODIFY:把stall_Fhl給刪掉
  wire bubble_sel_Fhl  = ( squash_Fhl);
  wire bubble_next_Fhl = ( !bubble_sel_Fhl ) ? bubble_Fhl
                       : ( bubble_sel_Fhl )  ? 1'b1
                       :                       1'bx;

  //----------------------------------------------------------------------
  // Queue for instruction memory response
  //----------------------------------------------------------------------

  wire imemresp0_queue_en_Fhl = ( stall_Dhl && imemresp0_val ) || (imemresp0_val && case4_hazard_stall);
  wire imemresp0_queue_val_next_Fhl
    = (case4_hazard_stall) || (stall_Dhl && ( imemresp0_val || imemresp0_queue_val_Fhl ));

  wire imemresp1_queue_en_Fhl = ( stall_Dhl && imemresp1_val ) || (imemresp0_val && case4_hazard_stall);
  wire imemresp1_queue_val_next_Fhl
    = (case4_hazard_stall) || (stall_Dhl && ( imemresp1_val || imemresp1_queue_val_Fhl ));

  reg [31:0] imemresp0_queue_reg_Fhl;
  reg        imemresp0_queue_val_Fhl;

  reg [31:0] imemresp1_queue_reg_Fhl;
  reg        imemresp1_queue_val_Fhl;

  always @ ( posedge clk ) begin
    if ( imemresp0_queue_en_Fhl ) begin
      imemresp0_queue_reg_Fhl <= imemresp0_msg_data;
    end
    if ( imemresp1_queue_en_Fhl ) begin
      imemresp1_queue_reg_Fhl <= imemresp1_msg_data;
    end
    imemresp0_queue_val_Fhl <= imemresp0_queue_val_next_Fhl;
    imemresp1_queue_val_Fhl <= imemresp1_queue_val_next_Fhl;
  end

  //----------------------------------------------------------------------
  // Instruction memory queue mux
  //----------------------------------------------------------------------

  wire [31:0] imemresp0_queue_mux_out_Fhl
    = ( !imemresp0_queue_val_Fhl ) ? imemresp0_msg_data
    : ( imemresp0_queue_val_Fhl )  ? imemresp0_queue_reg_Fhl
    :                               32'bx;

  wire [31:0] imemresp1_queue_mux_out_Fhl
    = ( !imemresp1_queue_val_Fhl ) ? imemresp1_msg_data
    : ( imemresp1_queue_val_Fhl )  ? imemresp1_queue_reg_Fhl
    :                               32'bx;

  //----------------------------------------------------------------------
  // D <- F
  //----------------------------------------------------------------------

  reg [31:0] ir0_Dhl;
  reg [31:0] ir1_Dhl;
  reg        bubble_Dhl;
  //MODIFY: 加入steering logic
  reg        steering_mux_sel_Dhl;
  reg [31:0] irA_Dhl;
  reg [31:0] irB_Dhl;
  //MODIFY: 加入case4的flag
  reg        first_F_isBubble_flag;
  reg        case4_hazard_stall;
  //ADD:加入因stall_1 的 flag 與改變pc的flag
  reg stall_1_reg;
  reg stall_1_pc_change_reg;
  //is_alu 判斷 //先不使用
  // reg is_alu_0_Dhl;
  // reg is_alu_1_Dhl;
  //ADD: 用來判斷順序是否正確
  reg        revert_instruction;

  wire squash_first_D_inst =
    (inst_val_Dhl && !stall_0_Dhl && stall_1_Dhl); //拿來判斷是否A有出去，但B沒有出去
  //MODIFY: 加入steering
  always @ ( posedge clk ) begin
    revert_instruction <=1'b0;
    if ( reset ) begin
      bubble_Dhl <= 1'b1;
      steering_mux_sel_Dhl <= 1'b0;
      first_F_isBubble_flag  <= 1'b0;
      case4_hazard_stall <= 1'b0;
      //ADD:initial stall_1_reg
      stall_1_reg <= 1'b0;
      revert_instruction <=1'b0;
      // is_alu_0_Dhl <= 1'b1;
      // is_alu_1_Dhl <= 1'b1;
    end
    else if( !stall_Dhl ) begin
      bubble_Dhl <= bubble_next_Fhl;
      stall_1_pc_change_reg <= 1'b0;
      //MODIFY: 更新 ir0 & ir1的傳輸，我不知道stall_0_Dhl && !stall_1_Dhl需不需要
      if (!stall_0_Dhl && !stall_1_Dhl) begin  //Case 1 2 3
        ir0_Dhl    <= imemresp0_queue_mux_out_Fhl;
        ir1_Dhl    <= imemresp1_queue_mux_out_Fhl;
        //ADD: only for part1:
        // is_alu_0_Dhl <=1'b0;
        // is_alu_1_Dhl <=1'b0;
        //ADD: only for part 1
        //case4_hazard_stall <= 1'b1;
        first_F_isBubble_flag <=1'b0;
        // if (inst_val_Dhl) begin
        //   first_F_isBubble_flag <=1'b0;
        // end
        //ADD: Only for part 1
        // if (!bubble_Dhl) begin
        //   case4_hazard_stall <= 1'b1;
        // end
        // else begin
        //   case4_hazard_stall <= 1'b0;
        // end

      end
      else if (squash_first_D_inst) begin
        if (!first_F_isBubble_flag)begin
          ir0_Dhl    <= ir1_Dhl;
          ir1_Dhl    <= imemresp0_queue_mux_out_Fhl;
          first_F_isBubble_flag  <= 1'b1;
          //case4_hazard_stall <= 1'b0;
          stall_1_pc_change_reg <= 1'b1;
        end
        else if (first_F_isBubble_flag)begin
          ir0_Dhl    <= ir1_Dhl;
          ir1_Dhl    <= imemresp1_queue_mux_out_Fhl;
          first_F_isBubble_flag  <= 1'b0;
          //case4_hazard_stall <= 1'b1;
          stall_1_pc_change_reg <= 1'b0;
        end
      end
    end
  end

  //----------------------------------------------------------------------
  // Decode Stage: Constants
  //----------------------------------------------------------------------

  // Generic Parameters

  localparam n = 1'd0;
  localparam y = 1'd1;

  // Register specifiers

  localparam rx = 5'bx;
  localparam r0 = 5'd0;

  // Branch Type

  localparam br_x    = 3'bx;
  localparam br_none = 3'd0;
  localparam br_beq  = 3'd1;
  localparam br_bne  = 3'd2;
  localparam br_blt  = 3'd3;
  localparam br_bltu = 3'd4;
  localparam br_bge  = 3'd5;
  localparam br_bgeu = 3'd6;

  // PC Mux Select

  localparam pm_x   = 2'bx;  // Don't care
  localparam pm_p   = 2'd0;  // Use pc+4
  localparam pm_b   = 2'd1;  // Use branch address
  localparam pm_j   = 2'd2;  // Use jump address
  localparam pm_r   = 2'd3;  // Use jump register

  // Operand 0 Bypass Mux Select

  localparam am_r0    = 4'd0; // Use rdata0
  localparam am_AX0_byp = 4'd1; // Bypass from X0
  localparam am_AX1_byp = 4'd2; // Bypass from X1
  localparam am_AX2_byp = 4'd3; // Bypass from X2
  localparam am_AX3_byp = 4'd4; // Bypass from X3
  localparam am_AW_byp = 4'd5; // Bypass from W
  localparam am_BX0_byp = 4'd6; // Bypass from X0
  localparam am_BX1_byp = 4'd7; // Bypass from X1
  localparam am_BX2_byp = 4'd8; // Bypass from X2
  localparam am_BX3_byp = 4'd9; // Bypass from X3
  localparam am_BW_byp = 4'd10; // Bypass from W

  // Operand 0 Mux Select

  localparam am_x     = 2'bx;
  localparam am_rdat  = 2'd0; // Use output of bypass mux for rs1
  localparam am_pc    = 2'd1; // Use current PC
  localparam am_pc4   = 2'd2; // Use PC + 4
  localparam am_0     = 2'd3; // Use constant 0

  // Operand 1 Bypass Mux Select

  localparam bm_r1    = 4'd0; // Use rdata1
  localparam bm_AX0_byp = 4'd1; // Bypass from X0
  localparam bm_AX1_byp = 4'd2; // Bypass from X1
  localparam bm_AX2_byp = 4'd3; // Bypass from X2
  localparam bm_AX3_byp = 4'd4; // Bypass from X3
  localparam bm_AW_byp = 4'd5; // Bypass from W
  localparam bm_BX0_byp = 4'd6; // Bypass from X0
  localparam bm_BX1_byp = 4'd7; // Bypass from X1
  localparam bm_BX2_byp = 4'd8; // Bypass from X2
  localparam bm_BX3_byp = 4'd9; // Bypass from X3
  localparam bm_BW_byp = 4'd10; // Bypass from W

  // Operand 1 Mux Select

  localparam bm_x      = 3'bx; // Don't care
  localparam bm_rdat   = 3'd0; // Use output of bypass mux for rs2
  localparam bm_shamt  = 3'd1; // Use shift amount
  localparam bm_imm_u  = 3'd2; // Use U-type immediate
  localparam bm_imm_sb = 3'd3; // Use SB-type immediate
  localparam bm_imm_i  = 3'd4; // Use I-type immediate
  localparam bm_imm_s  = 3'd5; // Use S-type immediate
  localparam bm_0      = 3'd6; // Use constant 0

  // ALU Function

  localparam alu_x    = 4'bx;
  localparam alu_add  = 4'd0;
  localparam alu_sub  = 4'd1;
  localparam alu_sll  = 4'd2;
  localparam alu_or   = 4'd3;
  localparam alu_lt   = 4'd4;
  localparam alu_ltu  = 4'd5;
  localparam alu_and  = 4'd6;
  localparam alu_xor  = 4'd7;
  localparam alu_nor  = 4'd8;
  localparam alu_srl  = 4'd9;
  localparam alu_sra  = 4'd10;

  // Muldiv Function

  localparam md_x    = 3'bx;
  localparam md_mul  = 3'd0;
  localparam md_div  = 3'd1;
  localparam md_divu = 3'd2;
  localparam md_rem  = 3'd3;
  localparam md_remu = 3'd4;

  // MulDiv Mux Select

  localparam mdm_x = 1'bx; // Don't Care
  localparam mdm_l = 1'd0; // Take lower half of 64-bit result, mul/div/divu
  localparam mdm_u = 1'd1; // Take upper half of 64-bit result, rem/remu

  // Execute Mux Select

  localparam em_x   = 1'bx; // Don't Care
  localparam em_alu = 1'd0; // Use ALU output
  localparam em_md  = 1'd1; // Use muldiv output

  // Memory Request Type

  localparam nr = 2'b0; // No request
  localparam ld = 2'd1; // Load
  localparam st = 2'd2; // Store

  // Subword Memop Length

  localparam ml_x  = 2'bx;
  localparam ml_w  = 2'd0;
  localparam ml_b  = 2'd1;
  localparam ml_h  = 2'd2;

  // Memory Response Mux Select

  localparam dmm_x  = 3'bx;
  localparam dmm_w  = 3'd0;
  localparam dmm_b  = 3'd1;
  localparam dmm_bu = 3'd2;
  localparam dmm_h  = 3'd3;
  localparam dmm_hu = 3'd4;

  // Writeback Mux 1

  localparam wm_x   = 1'bx; // Don't care
  localparam wm_alu = 1'd0; // Use ALU output
  localparam wm_mem = 1'd1; // Use data memory response

  //----------------------------------------------------------------------
  // Decode Stage: Logic
  //----------------------------------------------------------------------

  // Is the current stage valid?

  wire inst_val_Dhl = ( !bubble_Dhl && !squash_Dhl );

  // Parse instruction fields
  //MODIFY: 加入opcode

  wire   [4:0] inst0_rs1_Dhl;
  wire   [4:0] inst0_rs2_Dhl;
  wire   [4:0] inst0_rd_Dhl;
  wire   [6:0] inst0_opcode;

  riscv_InstMsgFromBits inst0_msg_from_bits
  (
    .msg      (ir0_Dhl),
    .opcode   (inst0_opcode),
    .rs1      (inst0_rs1_Dhl),
    .rs2      (inst0_rs2_Dhl),
    .rd       (inst0_rd_Dhl),
    .funct3   (),
    .funct7   (),
    .shamt    (),
    .imm_i    (),
    .imm_s    (),
    .imm_sb   (),
    .imm_u    (),
    .imm_uj   ()
  );

  wire   [4:0] inst1_rs1_Dhl;
  wire   [4:0] inst1_rs2_Dhl;
  wire   [4:0] inst1_rd_Dhl;
  wire   [6:0] inst1_opcode;

  riscv_InstMsgFromBits inst1_msg_from_bits
  (
    .msg      (ir1_Dhl),
    .opcode   (inst1_opcode),
    .rs1      (inst1_rs1_Dhl),
    .rs2      (inst1_rs2_Dhl),
    .rd       (inst1_rd_Dhl),
    .funct3   (),
    .funct7   (),
    .shamt    (),
    .imm_i    (),
    .imm_s    (),
    .imm_sb   (),
    .imm_u    (),
    .imm_uj   ()
  );

  // Shorten register specifier name for table

  wire [4:0] rs10 = inst0_rs1_Dhl;
  wire [4:0] rs20 = inst0_rs2_Dhl;
  wire [4:0] rd0 = inst0_rd_Dhl;

  wire [4:0] rs11 = inst1_rs1_Dhl;
  wire [4:0] rs21 = inst1_rs2_Dhl;
  wire [4:0] rd1 = inst1_rd_Dhl;

  // Instruction Decode

  localparam cs_sz = 39;
  reg [cs_sz-1:0] cs0;
  reg [cs_sz-1:0] cs1;

  always @ (*) begin

    cs0 = {cs_sz{1'bx}}; // Default to invalid instruction

    casez ( ir0_Dhl )

      //                                j     br       pc      op0      rs1 op1       rs2 alu       md       md md     ex      mem  mem   memresp wb      rf      csr
      //                            val taken type     muxsel  muxsel   en  muxsel    en  fn        fn       en muxsel muxsel  rq   len   muxsel  muxsel  wen wa  wen
      `RISCV_INST_MSG_LUI     :cs0={ y,  n,    br_none, pm_p,   am_0,    n,  bm_imm_u, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_AUIPC   :cs0={ y,  n,    br_none, pm_p,   am_pc,   n,  bm_imm_u, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_ADDI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_ORI     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_or,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLTI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_lt,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLTIU   :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_ltu,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_XORI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_xor,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_ANDI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_and,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLLI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_sll,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SRLI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_srl,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SRAI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_sra,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_ADD     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SUB     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLL     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sll,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLT     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_lt,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLTU    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_ltu,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_XOR     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SRL     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_srl,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SRA     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sra,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_OR      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_or,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_AND     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_and,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_LW      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_w, dmm_w,  wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_LB      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_b, dmm_b,  wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_LH      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_h, dmm_h,  wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_LBU     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_b, dmm_bu, wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_LHU     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_h, dmm_hu, wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_SW      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_w, dmm_w,  wm_mem, n,  rx, n   };
      `RISCV_INST_MSG_SB      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_b, dmm_b,  wm_mem, n,  rx, n   };
      `RISCV_INST_MSG_SH      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_h, dmm_h,  wm_mem, n,  rx, n   };

      `RISCV_INST_MSG_JAL     :cs0={ y,  y,    br_none, pm_j,   am_pc4,  n,  bm_0,     n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_JALR    :cs0={ y,  y,    br_none, pm_r,   am_pc4,  y,  bm_0,     n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_BNE     :cs0={ y,  n,    br_bne,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BEQ     :cs0={ y,  n,    br_beq,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BLT     :cs0={ y,  n,    br_blt,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BGE     :cs0={ y,  n,    br_bge,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BLTU    :cs0={ y,  n,    br_bltu, pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BGEU    :cs0={ y,  n,    br_bgeu, pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
 
      `RISCV_INST_MSG_MUL     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_mul,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      //Quest: 加入`RISCV INST_MSG_MUL
      //`RISCV_INST_MSG_MULU     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_mul,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      //`RISCV_INST_MSG_MUL     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_mul,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_DIV     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_div,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_REM     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_rem,  y, mdm_u, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_DIVU    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_divu, y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_REMU    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_remu, y, mdm_u, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_CSRW    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_0,     y,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, n,  rx, y   };

    endcase

  end

  always @ (*) begin

    cs1 = {cs_sz{1'bx}}; // Default to invalid instruction

    casez ( ir1_Dhl )

      //                                j     br       pc      op0      rs1 op1       rs2 alu       md       md md     ex      mem  mem   memresp wb      rf      csr
      //                            val taken type     muxsel  muxsel   en  muxsel    en  fn        fn       en muxsel muxsel  rq   len   muxsel  muxsel  wen wa  wen
      `RISCV_INST_MSG_LUI     :cs1={ y,  n,    br_none, pm_p,   am_0,    n,  bm_imm_u, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_AUIPC   :cs1={ y,  n,    br_none, pm_p,   am_pc,   n,  bm_imm_u, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_ADDI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_ORI     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_or,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLTI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_lt,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLTIU   :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_ltu,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_XORI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_xor,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_ANDI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_and,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLLI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_sll,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SRLI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_srl,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SRAI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_sra,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_ADD     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SUB     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLL     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sll,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLT     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_lt,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLTU    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_ltu,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_XOR     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SRL     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_srl,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SRA     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sra,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_OR      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_or,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_AND     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_and,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_LW      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_w, dmm_w,  wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_LB      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_b, dmm_b,  wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_LH      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_h, dmm_h,  wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_LBU     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_b, dmm_bu, wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_LHU     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_h, dmm_hu, wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_SW      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_w, dmm_w,  wm_mem, n,  rx, n   };
      `RISCV_INST_MSG_SB      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_b, dmm_b,  wm_mem, n,  rx, n   };
      `RISCV_INST_MSG_SH      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_h, dmm_h,  wm_mem, n,  rx, n   };

      `RISCV_INST_MSG_JAL     :cs1={ y,  y,    br_none, pm_j,   am_pc4,  n,  bm_0,     n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_JALR    :cs1={ y,  y,    br_none, pm_r,   am_pc4,  y,  bm_0,     n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_BNE     :cs1={ y,  n,    br_bne,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BEQ     :cs1={ y,  n,    br_beq,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BLT     :cs1={ y,  n,    br_blt,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BGE     :cs1={ y,  n,    br_bge,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BLTU    :cs1={ y,  n,    br_bltu, pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BGEU    :cs1={ y,  n,    br_bgeu, pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };

      `RISCV_INST_MSG_MUL     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_mul,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_DIV     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_div,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_REM     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_rem,  y, mdm_u, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_DIVU    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_divu, y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_REMU    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_remu, y, mdm_u, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_CSRW    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_0,     y,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, n,  rx, y   };

    endcase

  end

  // Steering Logic

  // TODO: generate your steering signal here!
  //ADD: 先判斷是否為alu 
    // for part1  
    // wire is_alu_0_Dhl = (inst_val_Dhl)? 1'b0:
    //                                     1'b1;
    // wire is_alu_1_Dhl =  (inst_val_Dhl)?1'b0:
    //                                     1'b1;
    //FIXME: part2記得改回來
    wire is_alu_0_Dhl=(!inst_val_Dhl) || (inst0_opcode == 7'b0010011) ||  // ALU immediate
                    (inst0_opcode == 7'b0110011 && !cs0[`RISCV_INST_MSG_MULDIV_EN]); // ALU reg-reg (不包含 mul/div)
    wire is_alu_1_Dhl =(!inst_val_Dhl) || (inst1_opcode == 7'b0010011) ||  // ALU immediate
                    (inst1_opcode == 7'b0110011 && !cs1[`RISCV_INST_MSG_MULDIV_EN]); // ALU reg-reg (不包含 mul/div)
  //ADD: 在同個stage的WAW,WAR,RAW

  wire WAW_hazard_Dhl = (inst_val_Dhl && (rd0 == rd1)) ? 1'b1
                        :                                1'b0;
  wire RAW_hazard_Dhl = (inst_val_Dhl && ((rd0 == rs11) || (rd0 == rs21)
                                       || (rd1 == rs10) || (rd1 == rs20))) ?  1'b1
                        :                                                     1'b0; 
  // wire WAW_hazard_Dhl = (inst_val_Dhl && ((rd0 == rs11) || (rd0 == rs21)
  //                                      || (rd1 == rs10) || (rd1 == rs20)) ?   1'b1;
                        // :                                                     1'b0; 
  always @ (*)
  begin
    //MODIFY: 為了避免錯誤
    stall_1_reg <= 1'b0;
    case4_hazard_stall <= 1'b0;
    
    

    if (is_alu_0_Dhl && is_alu_1_Dhl) // Case 1: ALU - ALU
    begin
      // first_F_isBubble_flag <=1'b0;
      steering_mux_sel_Dhl <= 1'b0;
      irA_Dhl <= ir0_Dhl;     // inst0 去 A
      irB_Dhl <= ir1_Dhl;     // inst1 去 B
      stall_1_reg <= 1'b0; 
    end
    else if (is_alu_0_Dhl && !is_alu_1_Dhl && (!WAW_hazard_Dhl && !RAW_hazard_Dhl)) // Case 2: ALU - Non-ALU
    begin
      // first_F_isBubble_flag <=1'b0;
      revert_instruction <=1'b1;
      steering_mux_sel_Dhl <= 1'b1;
      irA_Dhl <= ir1_Dhl;     // inst1 去 A
      irB_Dhl <= ir0_Dhl;
      stall_1_reg <= 1'b0;      // inst0 去 B
    end
    else if (!is_alu_0_Dhl && is_alu_1_Dhl) // Case 3: Non-ALU - ALU
    begin
      // first_F_isBubble_flag <=1'b0;
      steering_mux_sel_Dhl <= 1'b0;
      irA_Dhl <= ir0_Dhl;     // inst0 去 A
      irB_Dhl <= ir1_Dhl;     // inst1 去 B
      stall_1_reg <= 1'b0; 
    end
    else if ((!is_alu_0_Dhl && !is_alu_1_Dhl) || WAW_hazard_Dhl || RAW_hazard_Dhl)
    begin
      steering_mux_sel_Dhl <= 1'b0;
      irA_Dhl <= ir0_Dhl;     // inst0 去 A
      irB_Dhl <= 32'h00000013;  // addi x0, x0, 0 (等同於 NOP 但不直接使用 NOP)
      stall_1_reg <= 1'b1;    // 讓 inst1 stall
      if (!first_F_isBubble_flag) begin
        case4_hazard_stall <= 1'b1;
      end
      else begin
        case4_hazard_stall <= 1'b0;
      end
    end
    if (brj_taken_Dhl || brj_taken_X0hl)begin
      case4_hazard_stall <=1'b0;
    end
    
    //ADD: only for part1:
    //irB_Dhl <= 32'h00000013;
    // if ( steering_mux_sel_Dhl == 1'b0 )
    // begin
    //   // TODO: add your steering logic here!
    //   irA_Dhl <= ir0_Dhl;
    //   irB_Dhl <= ir1_Dhl;
    // end
    // else if ( steering_mux_sel_Dhl == 1'b1 )
    // begin
    //   // TODO: add your steering logic here!
    //   irA_Dhl <= ir1_Dhl;
    //   irB_Dhl <= ir0_Dhl;
    // end
  end
  //ADD: 新增stall_1_sel， for datapath
  wire stall_1_sel =stall_1_pc_change_reg;

  //ADD: 更新至instA &instB
  assign instA_Dhl = irA_Dhl;
  //ADD:Only for part1
  assign instB_Dhl = irB_Dhl;

  // Jump and Branch Controls
  //Quest: 有可能有問題
  //MODIFY: 
  
  wire       brj_taken_Dhl 
  =(steering_mux_sel_Dhl) ? ( inst_val_Dhl && cs1[`RISCV_INST_MSG_J_EN] )
  :                         ( inst_val_Dhl && cs0[`RISCV_INST_MSG_J_EN] );
  
  wire [2:0] br_sel_Dhl 
  =(steering_mux_sel_Dhl) ? ( cs1[`RISCV_INST_MSG_BR_SEL] )
  :                         ( cs0[`RISCV_INST_MSG_BR_SEL] );

  // PC Mux Select
  wire       [1:0] pc_mux_sel_Dhl
  =(steering_mux_sel_Dhl) ? ( cs1[`RISCV_INST_MSG_PC_SEL] )
  :                         ( cs0[`RISCV_INST_MSG_PC_SEL] );


  // Operand Bypassing Logic

  wire [4:0] rs10_addr_Dhl  = inst0_rs1_Dhl;
  wire [4:0] rs20_addr_Dhl  = inst0_rs2_Dhl;

  wire [4:0] rs11_addr_Dhl  = inst1_rs1_Dhl;
  wire [4:0] rs21_addr_Dhl  = inst1_rs2_Dhl;

  wire       rs10_en_Dhl    = cs0[`RISCV_INST_MSG_RS1_EN];
  wire       rs20_en_Dhl    = cs0[`RISCV_INST_MSG_RS2_EN];

  wire       rs11_en_Dhl    = cs1[`RISCV_INST_MSG_RS1_EN];
  wire       rs21_en_Dhl    = cs1[`RISCV_INST_MSG_RS2_EN];

  // For Part 2 and Optionaly Part 1, replace the following control logic with a scoreboard

  wire       rs10_AX0_byp_Dhl = rs10_en_Dhl
                         && rfA_wen_X0hl
                         && (rs10_addr_Dhl == rfA_waddr_X0hl)
                         && !(rfA_waddr_X0hl == 5'd0)
                         && inst_val_X0hl;

  wire       rs10_AX1_byp_Dhl = rs10_en_Dhl
                         && rfA_wen_X1hl
                         && (rs10_addr_Dhl == rfA_waddr_X1hl)
                         && !(rfA_waddr_X1hl == 5'd0)
                         && inst_val_X1hl;

  wire       rs10_AX2_byp_Dhl = rs10_en_Dhl
                         && rfA_wen_X2hl
                         && (rs10_addr_Dhl == rfA_waddr_X2hl)
                         && !(rfA_waddr_X2hl == 5'd0)
                         && inst_val_X2hl;

  wire       rs10_AX3_byp_Dhl = rs10_en_Dhl
                         && rfA_wen_X3hl
                         && (rs10_addr_Dhl == rfA_waddr_X3hl)
                         && !(rfA_waddr_X3hl == 5'd0)
                         && inst_val_X3hl;

  wire       rs10_AW_byp_Dhl = rs10_en_Dhl
                         && rfA_wen_Whl
                         && (rs10_addr_Dhl == rfA_waddr_Whl)
                         && !(rfA_waddr_Whl == 5'd0)
                         && inst_val_Whl;
  //temp
  wire       rs10_BX0_byp_Dhl = rs10_en_Dhl
                         && rfB_wen_X0hl
                         && (rs10_addr_Dhl == rfB_waddr_X0hl)
                         && !(rfB_waddr_X0hl == 5'd0)
                         && inst_val_X0hl;
  wire       rs10_BX1_byp_Dhl = rs10_en_Dhl
                         && rfB_wen_X1hl
                         && (rs10_addr_Dhl == rfB_waddr_X1hl)
                         && !(rfB_waddr_X1hl == 5'd0)
                         && inst_val_X1hl;
  wire       rs10_BX2_byp_Dhl = rs10_en_Dhl
                         && rfB_wen_X2hl
                         && (rs10_addr_Dhl == rfB_waddr_X2hl)
                         && !(rfB_waddr_X2hl == 5'd0)
                         && inst_val_X2hl;
  wire       rs10_BX3_byp_Dhl = rs10_en_Dhl
                         && rfB_wen_X3hl
                         && (rs10_addr_Dhl == rfB_waddr_X3hl)
                         && !(rfB_waddr_X3hl == 5'd0)
                         && inst_val_X3hl;
  wire       rs10_BW_byp_Dhl = rs10_en_Dhl
                         && rfB_wen_Whl
                         && (rs10_addr_Dhl == rfB_waddr_Whl)
                         && !(rfB_waddr_Whl == 5'd0)
                         && inst_val_Whl;
  //rs20
  
  wire       rs20_AX0_byp_Dhl = rs20_en_Dhl
                         && rfA_wen_X0hl
                         && (rs20_addr_Dhl == rfA_waddr_X0hl)
                         && !(rfA_waddr_X0hl == 5'd0)
                         && inst_val_X0hl;

  wire       rs20_AX1_byp_Dhl = rs20_en_Dhl
                         && rfA_wen_X1hl
                         && (rs20_addr_Dhl == rfA_waddr_X1hl)
                         && !(rfA_waddr_X1hl == 5'd0)
                         && inst_val_X1hl;

  wire       rs20_AX2_byp_Dhl = rs20_en_Dhl
                         && rfA_wen_X2hl
                         && (rs20_addr_Dhl == rfA_waddr_X2hl)
                         && !(rfA_waddr_X2hl == 5'd0)
                         && inst_val_X2hl;

  wire       rs20_AX3_byp_Dhl = rs20_en_Dhl
                         && rfA_wen_X3hl
                         && (rs20_addr_Dhl == rfA_waddr_X3hl)
                         && !(rfA_waddr_X3hl == 5'd0)
                         && inst_val_X3hl;

  wire       rs20_AW_byp_Dhl = rs20_en_Dhl
                         && rfA_wen_Whl
                         && (rs20_addr_Dhl == rfA_waddr_Whl)
                         && !(rfA_waddr_Whl == 5'd0)
                         && inst_val_Whl;
  
wire       rs20_BX0_byp_Dhl = rs20_en_Dhl
                         && rfB_wen_X0hl
                         && (rs20_addr_Dhl == rfB_waddr_X0hl)
                         && !(rfB_waddr_X0hl == 5'd0)
                         && inst_val_X0hl;

  wire       rs20_BX1_byp_Dhl = rs20_en_Dhl
                         && rfB_wen_X1hl
                         && (rs20_addr_Dhl == rfB_waddr_X1hl)
                         && !(rfB_waddr_X1hl == 5'd0)
                         && inst_val_X1hl;

  wire       rs20_BX2_byp_Dhl = rs20_en_Dhl
                         && rfB_wen_X2hl
                         && (rs20_addr_Dhl == rfB_waddr_X2hl)
                         && !(rfB_waddr_X2hl == 5'd0)
                         && inst_val_X2hl;

  wire       rs20_BX3_byp_Dhl = rs20_en_Dhl
                         && rfB_wen_X3hl
                         && (rs20_addr_Dhl == rfB_waddr_X3hl)
                         && !(rfB_waddr_X3hl == 5'd0)
                         && inst_val_X3hl;

  wire       rs20_BW_byp_Dhl = rs20_en_Dhl
                         && rfB_wen_Whl
                         && (rs20_addr_Dhl == rfB_waddr_Whl)
                         && !(rfB_waddr_Whl == 5'd0)
                         && inst_val_Whl;
  //rs11
  wire       rs11_AX0_byp_Dhl = rs11_en_Dhl
                         && rfA_wen_X0hl
                         && (rs11_addr_Dhl == rfA_waddr_X0hl)
                         && !(rfA_waddr_X0hl == 5'd0)
                         && inst_val_X0hl;

  wire       rs11_AX1_byp_Dhl = rs11_en_Dhl
                         && rfA_wen_X1hl
                         && (rs11_addr_Dhl == rfA_waddr_X1hl)
                         && !(rfA_waddr_X1hl == 5'd0)
                         && inst_val_X1hl;

  wire       rs11_AX2_byp_Dhl = rs11_en_Dhl
                         && rfA_wen_X2hl
                         && (rs11_addr_Dhl == rfA_waddr_X2hl)
                         && !(rfA_waddr_X2hl == 5'd0)
                         && inst_val_X2hl;

  wire       rs11_AX3_byp_Dhl = rs11_en_Dhl
                         && rfA_wen_X3hl
                         && (rs11_addr_Dhl == rfA_waddr_X3hl)
                         && !(rfA_waddr_X3hl == 5'd0)
                         && inst_val_X3hl;
  
  wire       rs11_AW_byp_Dhl = rs11_en_Dhl
                         && rfA_wen_Whl
                         && (rs11_addr_Dhl == rfA_waddr_Whl)
                         && !(rfA_waddr_Whl == 5'd0)
                         && inst_val_Whl;
  // rs11 的 B pipeline bypass
  wire       rs11_BX0_byp_Dhl = rs11_en_Dhl
                          && rfB_wen_X0hl
                          && (rs11_addr_Dhl == rfB_waddr_X0hl)
                          && !(rfB_waddr_X0hl == 5'd0)
                          && inst_val_X0hl;

  wire       rs11_BX1_byp_Dhl = rs11_en_Dhl
                          && rfB_wen_X1hl
                          && (rs11_addr_Dhl == rfB_waddr_X1hl)
                          && !(rfB_waddr_X1hl == 5'd0)
                          && inst_val_X1hl;

  wire       rs11_BX2_byp_Dhl = rs11_en_Dhl
                          && rfB_wen_X2hl
                          && (rs11_addr_Dhl == rfB_waddr_X2hl)
                          && !(rfB_waddr_X2hl == 5'd0)
                          && inst_val_X2hl;

  wire       rs11_BX3_byp_Dhl = rs11_en_Dhl
                          && rfB_wen_X3hl
                          && (rs11_addr_Dhl == rfB_waddr_X3hl)
                          && !(rfB_waddr_X3hl == 5'd0)
                          && inst_val_X3hl;

  wire       rs11_BW_byp_Dhl = rs11_en_Dhl
                          && rfB_wen_Whl
                          && (rs11_addr_Dhl == rfB_waddr_Whl)
                          && !(rfB_waddr_Whl == 5'd0)
                          && inst_val_Whl;
  //rs21
  wire       rs21_AX0_byp_Dhl = rs21_en_Dhl
                         && rfA_wen_X0hl
                         && (rs21_addr_Dhl == rfA_waddr_X0hl)
                         && !(rfA_waddr_X0hl == 5'd0)
                         && inst_val_X0hl;

  wire       rs21_AX1_byp_Dhl = rs21_en_Dhl
                         && rfA_wen_X1hl
                         && (rs21_addr_Dhl == rfA_waddr_X1hl)
                         && !(rfA_waddr_X1hl == 5'd0)
                         && inst_val_X1hl;

  wire       rs21_AX2_byp_Dhl = rs21_en_Dhl
                         && rfA_wen_X2hl
                         && (rs21_addr_Dhl == rfA_waddr_X2hl)
                         && !(rfA_waddr_X2hl == 5'd0)
                         && inst_val_X2hl;

  wire       rs21_AX3_byp_Dhl = rs21_en_Dhl
                         && rfA_wen_X3hl
                         && (rs21_addr_Dhl == rfA_waddr_X3hl)
                         && !(rfA_waddr_X3hl == 5'd0)
                         && inst_val_X3hl;

  wire       rs21_AW_byp_Dhl = rs21_en_Dhl
                         && rfA_wen_Whl
                         && (rs21_addr_Dhl == rfA_waddr_Whl)
                         && !(rfA_waddr_Whl == 5'd0)
                         && inst_val_Whl;
  // rs21 的 B pipeline bypass
  wire       rs21_BX0_byp_Dhl = rs21_en_Dhl
                          && rfB_wen_X0hl
                          && (rs21_addr_Dhl == rfB_waddr_X0hl)
                          && !(rfB_waddr_X0hl == 5'd0)
                          && inst_val_X0hl;

  wire       rs21_BX1_byp_Dhl = rs21_en_Dhl
                          && rfB_wen_X1hl
                          && (rs21_addr_Dhl == rfB_waddr_X1hl)
                          && !(rfB_waddr_X1hl == 5'd0)
                          && inst_val_X1hl;

  wire       rs21_BX2_byp_Dhl = rs21_en_Dhl
                          && rfB_wen_X2hl
                          && (rs21_addr_Dhl == rfB_waddr_X2hl)
                          && !(rfB_waddr_X2hl == 5'd0)
                          && inst_val_X2hl;

  wire       rs21_BX3_byp_Dhl = rs21_en_Dhl
                          && rfB_wen_X3hl
                          && (rs21_addr_Dhl == rfB_waddr_X3hl)
                          && !(rfB_waddr_X3hl == 5'd0)
                          && inst_val_X3hl;

  wire       rs21_BW_byp_Dhl = rs21_en_Dhl
                          && rfB_wen_Whl
                          && (rs21_addr_Dhl == rfB_waddr_Whl)
                          && !(rfB_waddr_Whl == 5'd0)
                          && inst_val_Whl;


  // Operand Bypass Mux Select
  wire [3:0]op00_byp_mux_sel_Dhl;
  wire [3:0]op01_byp_mux_sel_Dhl;
  wire [3:0]op10_byp_mux_sel_Dhl;
  wire [3:0]op11_byp_mux_sel_Dhl;
  //MODIFY: 更新bypass順序
  assign op00_byp_mux_sel_Dhl
    = (rs10_AX0_byp_Dhl) ? am_AX0_byp
    : (rs10_BX0_byp_Dhl) ? am_BX0_byp
    : (rs10_AX1_byp_Dhl) ? am_AX1_byp
    : (rs10_BX1_byp_Dhl) ? am_BX1_byp
    : (rs10_AX2_byp_Dhl) ? am_AX2_byp
    : (rs10_BX2_byp_Dhl) ? am_BX2_byp
    : (rs10_AX3_byp_Dhl) ? am_AX3_byp
    : (rs10_BX3_byp_Dhl) ? am_BX3_byp
    : (rs10_AW_byp_Dhl)  ? am_AW_byp
    : (rs10_BW_byp_Dhl) ?  am_BW_byp
    :                    am_r0;

  assign op01_byp_mux_sel_Dhl
    = (rs20_AX0_byp_Dhl) ? bm_AX0_byp
    : (rs20_BX0_byp_Dhl) ? bm_BX0_byp    
    : (rs20_AX1_byp_Dhl) ? bm_AX1_byp
    : (rs20_BX1_byp_Dhl) ? bm_BX1_byp
    : (rs20_AX2_byp_Dhl) ? bm_AX2_byp
    : (rs20_BX2_byp_Dhl) ? bm_BX2_byp
    : (rs20_AX3_byp_Dhl) ? bm_AX3_byp
    : (rs20_BX3_byp_Dhl) ? bm_BX3_byp
    : (rs20_AW_byp_Dhl)  ? bm_AW_byp
    : (rs20_BW_byp_Dhl) ?  bm_BW_byp
    :                     bm_r1;

  assign op10_byp_mux_sel_Dhl
    = (rs11_AX0_byp_Dhl) ? am_AX0_byp
    : (rs11_BX0_byp_Dhl) ? am_BX0_byp
    : (rs11_AX1_byp_Dhl) ? am_AX1_byp
    : (rs11_BX1_byp_Dhl) ? am_BX1_byp
    : (rs11_AX2_byp_Dhl) ? am_AX2_byp
    : (rs11_BX2_byp_Dhl) ? am_BX2_byp
    : (rs11_AX3_byp_Dhl) ? am_AX3_byp
    : (rs11_BX3_byp_Dhl) ? am_BX3_byp
    : (rs11_AW_byp_Dhl) ?  am_AW_byp
    : (rs11_BW_byp_Dhl) ?  am_BW_byp
    :                    am_r0;

  assign op11_byp_mux_sel_Dhl
    = (rs21_AX0_byp_Dhl) ? bm_AX0_byp
    : (rs21_BX0_byp_Dhl) ? bm_BX0_byp
    : (rs21_AX1_byp_Dhl) ? bm_AX1_byp
     : (rs21_BX1_byp_Dhl) ? bm_BX1_byp
    : (rs21_AX2_byp_Dhl) ? bm_AX2_byp
    : (rs21_BX2_byp_Dhl) ? bm_BX2_byp
    : (rs21_AX3_byp_Dhl) ? bm_AX3_byp
    : (rs21_BX3_byp_Dhl) ? bm_BX3_byp
    : (rs21_AW_byp_Dhl) ? bm_AW_byp
    : (rs21_BW_byp_Dhl) ?  bm_BW_byp
    :                    bm_r1;

  //ADD: Build bypass selector 
  //利用steering_mux_sel_Dhl，來確認是否交換位置，從0,1 變成 A,B
    assign opA0_byp_mux_sel_Dhl 
    = (steering_mux_sel_Dhl) ? op10_byp_mux_sel_Dhl
    :                         op00_byp_mux_sel_Dhl;

    assign opA1_byp_mux_sel_Dhl
    = (steering_mux_sel_Dhl) ? op11_byp_mux_sel_Dhl
    :                         op01_byp_mux_sel_Dhl;

    assign opB0_byp_mux_sel_Dhl 
    = (steering_mux_sel_Dhl) ? op00_byp_mux_sel_Dhl
    :                         op10_byp_mux_sel_Dhl;

    assign opB1_byp_mux_sel_Dhl 
    = (steering_mux_sel_Dhl) ? op01_byp_mux_sel_Dhl
    :                         op11_byp_mux_sel_Dhl; 

  // Operand Mux Select

  wire [1:0] op00_mux_sel_Dhl = cs0[`RISCV_INST_MSG_OP0_SEL];
  wire [2:0] op01_mux_sel_Dhl = cs0[`RISCV_INST_MSG_OP1_SEL];

  wire [1:0] op10_mux_sel_Dhl = cs1[`RISCV_INST_MSG_OP0_SEL];
  wire [2:0] op11_mux_sel_Dhl = cs1[`RISCV_INST_MSG_OP1_SEL];

  //ADD: build mux out selector in Decode 
  //利用steering_mux_sel_Dhl，來確認是否交換位置，從0,1 變成 A,B
  assign opA0_mux_sel_Dhl 
    = (steering_mux_sel_Dhl) ? op10_mux_sel_Dhl
    :                          op00_mux_sel_Dhl;

    assign opA1_mux_sel_Dhl
    = (steering_mux_sel_Dhl) ? op11_mux_sel_Dhl
    :                          op01_mux_sel_Dhl;

    assign opB0_mux_sel_Dhl 
    = (steering_mux_sel_Dhl) ? op00_mux_sel_Dhl
    :                          op10_mux_sel_Dhl;

    assign opB1_mux_sel_Dhl 
    = (steering_mux_sel_Dhl) ? op01_mux_sel_Dhl
    :                          op11_mux_sel_Dhl;

  // ALU Function
  //ADD: build aluA fn
  wire [3:0] alu0_fn_Dhl = cs0[`RISCV_INST_MSG_ALU_FN];
  wire [3:0] alu1_fn_Dhl = cs1[`RISCV_INST_MSG_ALU_FN];

  wire [3:0] aluA_fn_Dhl
    = (steering_mux_sel_Dhl) ? alu1_fn_Dhl
    :                          alu0_fn_Dhl;
  wire [3:0] aluB_fn_Dhl
    = (steering_mux_sel_Dhl) ? alu0_fn_Dhl
    :                          alu1_fn_Dhl;

  // Muldiv Function
  //ADD: steering on many thing
  wire [2:0] muldivreq_msg_fn_Dhl 
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_MULDIV_FN]
                             : cs0[`RISCV_INST_MSG_MULDIV_FN];
  // Muldiv Controls

  wire muldivreq_val_Dhl
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_MULDIV_EN]
                             : cs0[`RISCV_INST_MSG_MULDIV_EN];

  // Muldiv Mux Select

  wire muldiv_mux_sel_Dhl
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_MULDIV_SEL]
                             : cs0[`RISCV_INST_MSG_MULDIV_SEL];

  // Execute Mux Select

  wire execute_mux_sel_Dhl
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_MULDIV_EN]
                             : cs0[`RISCV_INST_MSG_MULDIV_EN];

  wire is_load_Dhl
    = (steering_mux_sel_Dhl) ? (cs1[`RISCV_INST_MSG_MEM_REQ] == ld)
                             : (cs0[`RISCV_INST_MSG_MEM_REQ] == ld);

  wire dmemreq_msg_rw_Dhl
    = (steering_mux_sel_Dhl) ? (cs1[`RISCV_INST_MSG_MEM_REQ] == st)
                             : (cs0[`RISCV_INST_MSG_MEM_REQ] == st);

  wire [1:0] dmemreq_msg_len_Dhl
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_MEM_LEN]
                             : cs0[`RISCV_INST_MSG_MEM_LEN];

  wire dmemreq_val_Dhl
    = (steering_mux_sel_Dhl) ? (cs1[`RISCV_INST_MSG_MEM_REQ] != nr)
                             : (cs0[`RISCV_INST_MSG_MEM_REQ] != nr);

// Memory response mux select
  wire [2:0] dmemresp_mux_sel_Dhl
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_MEM_SEL]
                             : cs0[`RISCV_INST_MSG_MEM_SEL];

// Writeback Mux Select
  wire memex_mux_sel_Dhl
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_WB_SEL]
                             : cs0[`RISCV_INST_MSG_WB_SEL];

  // Register Writeback Controls
  //MODIFY:把rf0_wen_Dhl 改成rfA_wen_Dhl，以後類推
  //MODIFY:把rf0_waddr_Dhl 改成rfA_waddr_Dhl，以後類推
  //MODIFY:把rf1_wen_Dhl 改成rfB_wen_Dhl，以後類推
  wire rfA_wen_Dhl
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_RF_WEN]
                             : cs0[`RISCV_INST_MSG_RF_WEN];
  wire [4:0] rfA_waddr_Dhl
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_RF_WADDR]
                             : cs0[`RISCV_INST_MSG_RF_WADDR];
  //ADD: 新增rfB_wen_Dhl 新的判斷，避免誤改
  wire rfB_wen_Dhl
    = (!is_alu_0_Dhl && !is_alu_1_Dhl) ? 1'b0
      :(steering_mux_sel_Dhl) ? cs0[`RISCV_INST_MSG_RF_WEN]
                             : cs1[`RISCV_INST_MSG_RF_WEN];

  wire [4:0] rfB_waddr_Dhl
    = (steering_mux_sel_Dhl) ? cs0[`RISCV_INST_MSG_RF_WADDR]
                             : cs1[`RISCV_INST_MSG_RF_WADDR];

  // CSR register write enable

  wire csr_wen_Dhl
    = (steering_mux_sel_Dhl) ? cs1[`RISCV_INST_MSG_CSR_WEN]
                             : cs0[`RISCV_INST_MSG_CSR_WEN];

  // CSR address - 根據選擇的指令取得正確的 CSR 地址
  wire [11:0] csr_addr_Dhl
    = (steering_mux_sel_Dhl) ? ir1_Dhl[31:20]
                             : ir0_Dhl[31:20];

  //----------------------------------------------------------------------
  // Squash and Stall Logic
  //----------------------------------------------------------------------

  // Squash instruction in D if a valid branch in X is taken

  wire squash_Dhl = ( inst_val_X0hl && brj_taken_X0hl );

  // For Part 2 of this lab, replace the multdiv and ld stall logic with a scoreboard based stall logic

  // Stall in D if muldiv unit is not ready and there is a valid request
  //Quest: 為什麼要檢查到is_muldiv_X3hl? 不是到is_muldiv_X2hl就好了嗎，助教說可調整
  
  wire stall_0_muldiv_use_Dhl = inst_val_Dhl && (
                              ( inst_val_X0hl && rs10_en_Dhl && rfA_wen_X0hl
                                && ( rs10_addr_Dhl == rfA_waddr_X0hl )
                                && ( rfA_waddr_X0hl != 5'd0 ) && is_muldiv_X0hl )
                           || ( inst_val_X1hl && rs10_en_Dhl && rfA_wen_X1hl
                                && ( rs10_addr_Dhl == rfA_waddr_X1hl )
                                && ( rfA_waddr_X1hl != 5'd0 ) && is_muldiv_X1hl )
                           || ( inst_val_X2hl && rs10_en_Dhl && rfA_wen_X2hl
                                && ( rs10_addr_Dhl == rfA_waddr_X2hl )
                                && ( rfA_waddr_X2hl != 5'd0 ) && is_muldiv_X2hl )
                           || ( inst_val_X0hl && rs20_en_Dhl && rfA_wen_X0hl
                                && ( rs20_addr_Dhl == rfA_waddr_X0hl )
                                && ( rfA_waddr_X0hl != 5'd0 ) && is_muldiv_X0hl )
                           || ( inst_val_X1hl && rs20_en_Dhl && rfA_wen_X1hl
                                && ( rs20_addr_Dhl == rfA_waddr_X1hl )
                                && ( rfA_waddr_X1hl != 5'd0 ) && is_muldiv_X1hl )
                           || ( inst_val_X2hl && rs20_en_Dhl && rfA_wen_X2hl
                                && ( rs20_addr_Dhl == rfA_waddr_X2hl )
                                && ( rfA_waddr_X2hl != 5'd0 ) && is_muldiv_X2hl ));
  wire stall_1_muldiv_use_Dhl = inst_val_Dhl && (
                              ( inst_val_X0hl && rs11_en_Dhl && rfA_wen_X0hl
                                && ( rs11_addr_Dhl == rfA_waddr_X0hl )
                                && ( rfA_waddr_X0hl != 5'd0 ) && is_muldiv_X0hl )
                           || ( inst_val_X1hl && rs11_en_Dhl && rfA_wen_X1hl
                                && ( rs11_addr_Dhl == rfA_waddr_X1hl )
                                && ( rfA_waddr_X1hl != 5'd0 ) && is_muldiv_X1hl )
                           || ( inst_val_X2hl && rs11_en_Dhl && rfA_wen_X2hl
                                && ( rs11_addr_Dhl == rfA_waddr_X2hl )
                                && ( rfA_waddr_X2hl != 5'd0 ) && is_muldiv_X2hl )
                           || ( inst_val_X0hl && rs21_en_Dhl && rfA_wen_X0hl
                                && ( rs21_addr_Dhl == rfA_waddr_X0hl )
                                && ( rfA_waddr_X0hl != 5'd0 ) && is_muldiv_X0hl )
                           || ( inst_val_X1hl && rs21_en_Dhl && rfA_wen_X1hl
                                && ( rs21_addr_Dhl == rfA_waddr_X1hl )
                                && ( rfA_waddr_X1hl != 5'd0 ) && is_muldiv_X1hl )
                           || ( inst_val_X2hl && rs21_en_Dhl && rfA_wen_X2hl
                                && ( rs21_addr_Dhl == rfA_waddr_X2hl )
                                && ( rfA_waddr_X2hl != 5'd0 ) && is_muldiv_X2hl )); 

  // Stall for load-use only if instruction in D is valid and either of
  // the source registers match the destination register of of a valid
  // instruction in a later stage.


  wire stall_0_load_use_Dhl = inst_val_Dhl && (
                            ( inst_val_X0hl && rs10_en_Dhl && rfA_wen_X0hl
                              && ( rs10_addr_Dhl == rfA_waddr_X0hl )
                              && ( rfA_waddr_X0hl != 5'd0 ) && is_load_X0hl )
                         || ( inst_val_X0hl && rs20_en_Dhl && rfA_wen_X0hl
                              && ( rs20_addr_Dhl == rfA_waddr_X0hl )
                              && ( rfA_waddr_X0hl != 5'd0 ) && is_load_X0hl ));

  wire stall_1_load_use_Dhl = inst_val_Dhl && (
                            ( inst_val_X0hl && rs11_en_Dhl && rfA_wen_X0hl
                              && ( rs11_addr_Dhl == rfA_waddr_X0hl )
                              && ( rfA_waddr_X0hl != 5'd0 ) && is_load_X0hl )
                         || ( inst_val_X0hl && rs21_en_Dhl && rfA_wen_X0hl
                              && ( rs21_addr_Dhl == rfA_waddr_X0hl )
                              && ( rfA_waddr_X0hl != 5'd0 ) && is_load_X0hl ));
 
  // Aggregate Stall Signal
  //MODIFY: stall_0_Dhl & stall_1_Dhl 
  wire stall_0_Dhl=( stall_X0hl || stall_0_muldiv_use_Dhl || stall_0_load_use_Dhl);
  wire stall_1_Dhl=(stall_X0hl || stall_1_reg);

  //Quest:是否要刪掉或更改，目前等同於stall_1_Dh1
  wire stall_Dhl = (stall_X0hl || stall_0_Dhl);

  // Next bubble bit

  wire bubble_sel_Dhl  = ( squash_Dhl || stall_0_Dhl ); //Quest: stall_0_Dhl是什麼
  wire bubble_next_Dhl = ( !bubble_sel_Dhl ) ? bubble_Dhl
                       : ( bubble_sel_Dhl )  ? 1'b1
                       :                       1'bx;

  //----------------------------------------------------------------------
  // X0 <- D
  //----------------------------------------------------------------------

  //ADD: IR registers for both pipelines，以此類推
  reg [31:0] irA_X0hl;
  reg [31:0] irB_X0hl;
  reg  [2:0] br_sel_X0hl;
  //MODIFY: change aluA/B fn
  reg  [3:0] aluA_fn_X0hl;
  reg  [3:0] aluB_fn_X0hl;

  reg        muldivreq_val_X0hl;
  reg  [2:0] muldivreq_msg_fn_X0hl;
  reg        muldiv_mux_sel_X0hl;
  reg        execute_mux_sel_X0hl;
  reg        is_load_X0hl;
  reg        is_muldiv_X0hl;
  reg        dmemreq_msg_rw_X0hl;
  reg  [1:0] dmemreq_msg_len_X0hl;
  reg        dmemreq_val_X0hl;
  reg  [2:0] dmemresp_mux_sel_X0hl;
  reg        memex_mux_sel_X0hl;
  reg        rfA_wen_X0hl;
  reg  [4:0] rfA_waddr_X0hl;
  reg        rfB_wen_X0hl;
  reg  [4:0] rfB_waddr_X0hl;
  reg        csr_wen_X0hl;
  reg [11:0] csr_addr_X0hl;

  reg        bubble_X0hl;

  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      bubble_X0hl <= 1'b1;
    end
    else if( !stall_X0hl ) begin

      br_sel_X0hl           <= br_sel_Dhl;
      //ADD: rfB_wen & waddr
      //MODIFY: change aluA/B fn
      irA_X0hl              <= irA_Dhl;
      aluA_fn_X0hl          <= aluA_fn_Dhl;
      rfA_wen_X0hl          <= rfA_wen_Dhl;
      rfA_waddr_X0hl        <= rfA_waddr_Dhl;
      //MODIFY: To make sure Pipeline B is not working
      //FIXME: Part2的時候
      irB_X0hl              <= irB_Dhl;
      aluB_fn_X0hl          <= aluB_fn_Dhl;
      rfB_wen_X0hl          <= rfB_wen_Dhl;
      rfB_waddr_X0hl        <= rfB_waddr_Dhl;

      muldivreq_val_X0hl    <= muldivreq_val_Dhl;
      muldivreq_msg_fn_X0hl <= muldivreq_msg_fn_Dhl;
      muldiv_mux_sel_X0hl   <= muldiv_mux_sel_Dhl;
      execute_mux_sel_X0hl  <= execute_mux_sel_Dhl;
      is_load_X0hl          <= is_load_Dhl;
      is_muldiv_X0hl        <= muldivreq_val_Dhl;
      //data memory
      dmemreq_msg_rw_X0hl   <= dmemreq_msg_rw_Dhl;
      dmemreq_msg_len_X0hl  <= dmemreq_msg_len_Dhl;
      dmemreq_val_X0hl      <= dmemreq_val_Dhl;
      dmemresp_mux_sel_X0hl <= dmemresp_mux_sel_Dhl;
      memex_mux_sel_X0hl    <= memex_mux_sel_Dhl;
      csr_wen_X0hl          <= csr_wen_Dhl;
      csr_addr_X0hl         <= csr_addr_Dhl;

      bubble_X0hl           <= bubble_next_Dhl;
    end

  end

  //----------------------------------------------------------------------
  // Execute Stage
  //----------------------------------------------------------------------

  // Is the current stage valid?

  wire inst_val_X0hl = ( !bubble_X0hl && !squash_X0hl );

  // Muldiv request

  assign muldivreq_val = muldivreq_val_Dhl && inst_val_Dhl && (!bubble_next_Dhl); //Quest: 出現
  assign muldivresp_rdy = 1'b1;
  wire muldiv_stall_mult1 = stall_X1hl;

  // Only send a valid dmem request if not stalled

  assign dmemreq_msg_rw  = dmemreq_msg_rw_X0hl;
  assign dmemreq_msg_len = dmemreq_msg_len_X0hl;
  assign dmemreq_val     = ( inst_val_X0hl && !stall_X0hl && dmemreq_val_X0hl );

  // Resolve Branch

  wire bne_taken_X0hl  = ( ( br_sel_X0hl == br_bne ) && branch_cond_ne_X0hl );
  wire beq_taken_X0hl  = ( ( br_sel_X0hl == br_beq ) && branch_cond_eq_X0hl );
  wire blt_taken_X0hl  = ( ( br_sel_X0hl == br_blt ) && branch_cond_lt_X0hl );
  wire bltu_taken_X0hl = ( ( br_sel_X0hl == br_bltu) && branch_cond_ltu_X0hl);
  wire bge_taken_X0hl  = ( ( br_sel_X0hl == br_bge ) && branch_cond_ge_X0hl );
  wire bgeu_taken_X0hl = ( ( br_sel_X0hl == br_bgeu) && branch_cond_geu_X0hl);


  wire any_br_taken_X0hl
    = ( beq_taken_X0hl
   ||   bne_taken_X0hl
   ||   blt_taken_X0hl
   ||   bltu_taken_X0hl
   ||   bge_taken_X0hl
   ||   bgeu_taken_X0hl );

  wire brj_taken_X0hl = ( inst_val_X0hl && any_br_taken_X0hl );

  // Dummy Squash Signal

  wire squash_X0hl = 1'b0;

  // Stall in X if muldiv reponse is not valid and there was a valid request

  wire stall_muldiv_X0hl = 1'b0; //( muldivreq_val_X0hl && inst_val_X0hl && !muldivresp_val );
  //Quest: Maybe have to change

  // Stall in X if imem is not ready

  wire stall_imem_X0hl = !imemreq0_rdy || !imemreq1_rdy;

  // Stall in X if dmem is not ready and there was a valid request

  wire stall_dmem_X0hl = ( dmemreq_val_X0hl && inst_val_X0hl && !dmemreq_rdy );

  // Aggregate Stall Signal

  assign stall_X0hl = ( stall_X1hl || stall_muldiv_X0hl || stall_imem_X0hl || stall_dmem_X0hl );

  // Next bubble bit

  wire bubble_sel_X0hl  = ( squash_X0hl || stall_X0hl );
  wire bubble_next_X0hl = ( !bubble_sel_X0hl ) ? bubble_X0hl
                       : ( bubble_sel_X0hl )  ? 1'b1
                       :                       1'bx;

  //----------------------------------------------------------------------
  // X1 <- X0
  //----------------------------------------------------------------------

  reg [31:0] irA_X1hl;
  reg [31:0] irB_X1hl; 
  reg        is_load_X1hl;
  reg        is_muldiv_X1hl;
  reg        dmemreq_val_X1hl;
  reg  [2:0] dmemresp_mux_sel_X1hl;
  reg        memex_mux_sel_X1hl;
  reg        execute_mux_sel_X1hl;
  reg        muldiv_mux_sel_X1hl;
  reg        rfA_wen_X1hl;
  reg  [4:0] rfA_waddr_X1hl;
  reg        rfB_wen_X1hl;
  reg  [4:0] rfB_waddr_X1hl;
  reg        csr_wen_X1hl;
  reg  [4:0] csr_addr_X1hl;

  reg        bubble_X1hl;

  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      dmemreq_val_X1hl <= 1'b0;

      bubble_X1hl <= 1'b1;
    end
    else if( !stall_X1hl ) begin
      irA_X1hl <= irA_X0hl;
      irB_X1hl <= irB_X0hl;
      is_load_X1hl          <= is_load_X0hl;
      is_muldiv_X1hl        <= is_muldiv_X0hl;
      dmemreq_val_X1hl      <= dmemreq_val;
      dmemresp_mux_sel_X1hl <= dmemresp_mux_sel_X0hl;
      memex_mux_sel_X1hl    <= memex_mux_sel_X0hl;
      execute_mux_sel_X1hl  <= execute_mux_sel_X0hl;
      muldiv_mux_sel_X1hl   <= muldiv_mux_sel_X0hl;
      rfA_wen_X1hl          <= rfA_wen_X0hl;
      rfA_waddr_X1hl        <= rfA_waddr_X0hl;
      rfB_wen_X1hl          <= rfB_wen_X0hl;
      rfB_waddr_X1hl        <= rfB_waddr_X0hl;
      csr_wen_X1hl          <= csr_wen_X0hl;
      csr_addr_X1hl         <= csr_addr_X0hl;

      bubble_X1hl           <= bubble_next_X0hl;
    end
  end

  //----------------------------------------------------------------------
  // X1 Stage
  //----------------------------------------------------------------------

  // Is current stage valid?

  wire inst_val_X1hl = ( !bubble_X1hl && !squash_X1hl );

  // Data memory queue control signals

  assign dmemresp_queue_en_X1hl = ( stall_X1hl && dmemresp_val );
  wire   dmemresp_queue_val_next_X1hl
    = stall_X1hl && ( dmemresp_val || dmemresp_queue_val_X1hl );

  // Dummy Squash Signal

  wire squash_X1hl = 1'b0;

  // Stall in X1 if memory response is not returned for a valid request

  wire stall_dmem_X1hl
    = ( !reset && dmemreq_val_X1hl && inst_val_X1hl && !dmemresp_val && !dmemresp_queue_val_X1hl );
  //Quest: 可能出問題
  wire stall_imem_X1hl
    = ( !reset && imemreq_val_Fhl && inst_val_Fhl && !imemresp0_val && !imemresp0_queue_val_Fhl )
   || ( !reset && imemreq_val_Fhl && inst_val_Fhl && !imemresp1_val && !imemresp1_queue_val_Fhl );

  // Aggregate Stall Signal
  //MODIFY: stall_X1hl

  wire stall_X1hl = ( stall_X2hl || stall_imem_X1hl || stall_dmem_X1hl );

  // Next bubble bit

  wire bubble_sel_X1hl  = ( squash_X1hl || stall_X1hl );
  wire bubble_next_X1hl = ( !bubble_sel_X1hl ) ? bubble_X1hl
                       : ( bubble_sel_X1hl )  ? 1'b1
                       :                       1'bx;

  //----------------------------------------------------------------------
  // X2 <- X1
  //----------------------------------------------------------------------

  reg [31:0] irA_X2hl;
  reg [31:0] irB_X2hl;
  reg        is_muldiv_X2hl;
  reg        dmemresp_queue_val_X1hl;
  reg        rfA_wen_X2hl;
  reg  [4:0] rfA_waddr_X2hl;
  reg        rfB_wen_X2hl;
  reg  [4:0] rfB_waddr_X2hl;
  reg        csr_wen_X2hl;
  reg  [4:0] csr_addr_X2hl;
  reg        execute_mux_sel_X2hl;
  reg        muldiv_mux_sel_X2hl;

  reg        bubble_X2hl;

  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      bubble_X2hl <= 1'b1;
    end
    else if( !stall_X2hl ) begin
      irA_X2hl <= irA_X1hl;
      irB_X2hl <= irB_X1hl;
      is_muldiv_X2hl        <= is_muldiv_X1hl;
      muldiv_mux_sel_X2hl   <= muldiv_mux_sel_X1hl;
      rfA_wen_X2hl          <= rfA_wen_X1hl;
      rfA_waddr_X2hl        <= rfA_waddr_X1hl;
      rfB_wen_X2hl          <= rfB_wen_X1hl;
      rfB_waddr_X2hl        <= rfB_waddr_X1hl;
      csr_wen_X2hl          <= csr_wen_X1hl;
      csr_addr_X2hl         <= csr_addr_X1hl;
      execute_mux_sel_X2hl  <= execute_mux_sel_X1hl;

      bubble_X2hl           <= bubble_next_X1hl;
    end
    dmemresp_queue_val_X1hl <= dmemresp_queue_val_next_X1hl;
  end

  //----------------------------------------------------------------------
  // X2 Stage
  //----------------------------------------------------------------------

  // Is current stage valid?

  wire inst_val_X2hl = ( !bubble_X2hl && !squash_X2hl );

  // Dummy Squash Signal

  wire squash_X2hl = 1'b0;

  // Dummy Stall Signal

  wire stall_X2hl = 1'b0;

  // Next bubble bit

  wire bubble_sel_X2hl  = ( squash_X2hl || stall_X2hl );
  wire bubble_next_X2hl = ( !bubble_sel_X2hl ) ? bubble_X2hl
                       : ( bubble_sel_X2hl )  ? 1'b1
                       :                       1'bx;

  //----------------------------------------------------------------------
  // X3 <- X2
  //----------------------------------------------------------------------

  reg [31:0] irA_X3hl;
  reg [31:0] irB_X3hl;
  reg        is_muldiv_X3hl;
  reg        rfA_wen_X3hl;
  reg  [4:0] rfA_waddr_X3hl;
  reg        rfB_wen_X3hl;
  reg  [4:0] rfB_waddr_X3hl;
  reg        csr_wen_X3hl;
  reg  [4:0] csr_addr_X3hl;
  reg        execute_mux_sel_X3hl;
  reg        muldiv_mux_sel_X3hl;

  reg        bubble_X3hl;

  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      bubble_X3hl <= 1'b1;
    end
    else if( !stall_X3hl ) begin
      irA_X3hl <= irA_X2hl;
      irB_X3hl <= irB_X2hl;
      is_muldiv_X3hl        <= is_muldiv_X2hl;
      muldiv_mux_sel_X3hl   <= muldiv_mux_sel_X2hl;
      rfA_wen_X3hl          <= rfA_wen_X2hl;
      rfA_waddr_X3hl        <= rfA_waddr_X2hl;
      rfB_wen_X3hl          <= rfB_wen_X2hl;
      rfB_waddr_X3hl        <= rfB_waddr_X2hl;
      csr_wen_X3hl          <= csr_wen_X2hl;
      csr_addr_X3hl         <= csr_addr_X2hl;
      execute_mux_sel_X3hl  <= execute_mux_sel_X2hl;

      bubble_X3hl           <= bubble_next_X2hl;
    end
  end

  //----------------------------------------------------------------------
  // X3 Stage
  //----------------------------------------------------------------------

  // Is current stage valid?

  wire inst_val_X3hl = ( !bubble_X3hl && !squash_X3hl );

  // Dummy Squash Signal

  wire squash_X3hl = 1'b0;

  // Dummy Stall Signal

  wire stall_X3hl = 1'b0;

  // Next bubble bit

  wire bubble_sel_X3hl  = ( squash_X3hl || stall_X3hl );
  wire bubble_next_X3hl = ( !bubble_sel_X3hl ) ? bubble_X3hl
                       : ( bubble_sel_X3hl )  ? 1'b1
                       :                       1'bx;

  //----------------------------------------------------------------------
  // W <- X3
  //----------------------------------------------------------------------

  reg [31:0] irA_Whl;
  reg [31:0] irB_Whl;
  reg        rfA_wen_Whl;
  reg  [4:0] rfA_waddr_Whl;
  reg        rfB_wen_Whl;
  reg  [4:0] rfB_waddr_Whl;
  reg        csr_wen_Whl;
  reg  [4:0] csr_addr_Whl;

  reg        bubble_Whl;

  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      bubble_Whl <= 1'b1;
    end
    else if( !stall_Whl ) begin
      irA_Whl <= irA_X3hl;
      irB_Whl <= irB_X3hl;
      rfA_wen_Whl      <= rfA_wen_X3hl;
      rfA_waddr_Whl    <= rfA_waddr_X3hl;
      rfB_wen_Whl      <= rfB_wen_X3hl;
      rfB_waddr_Whl    <= rfB_waddr_X3hl;
      csr_wen_Whl      <= csr_wen_X3hl;
      csr_addr_Whl     <= csr_addr_X3hl;

      bubble_Whl       <= bubble_next_X3hl;
    end
  end

  //----------------------------------------------------------------------
  // Writeback Stage
  //----------------------------------------------------------------------

  // Is current stage valid?

  wire inst_val_Whl = ( !bubble_Whl && !squash_Whl );

  // Only set register file wen if stage is valid
  //ADD: rfA_wen_out_Whl
  assign rfA_wen_out_Whl = ( inst_val_Whl && !stall_Whl && rfA_wen_Whl );
  assign rfB_wen_out_Whl = ( inst_val_Whl && !stall_Whl && rfB_wen_Whl );

  // Dummy squash and stall signals

  wire squash_Whl = 1'b0;
  wire stall_Whl  = 1'b0;

  //----------------------------------------------------------------------
  // Debug registers for instruction disassembly
  //----------------------------------------------------------------------

  reg [31:0] irA_debug;
  reg [31:0] irB_debug;
  reg        inst_val_debug;

  always @ ( posedge clk ) begin
    irA_debug       <= irA_Whl;
    inst_val_debug <= inst_val_Whl;
    irB_debug       <= irB_Whl; // FIXME: fix this when you can have two instructions issued per cycle!
  end

  //----------------------------------------------------------------------
  // CSR register
  //----------------------------------------------------------------------

  reg  [31:0] csr_status;
  reg         csr_stats;

  always @ ( posedge clk ) begin
    if ( csr_wen_Whl && inst_val_Whl ) begin
      case ( csr_addr_Whl )
        12'd10 : csr_stats  <= proc2csr_data_Whl[0];
        12'd21 : csr_status <= proc2csr_data_Whl;
      endcase
    end
  end
//Quest: Disassemble instructions需要修正?
//========================================================================
// Disassemble instructions
//========================================================================

  `ifndef SYNTHESIS

  riscv_InstMsgDisasm inst0_msg_disasm_D
  (
    //Quest: 可能要更動
    .msg ( ir0_Dhl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_X0
  (
    .msg ( irA_X0hl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_X1
  (
    .msg ( irA_X1hl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_X2
  (
    .msg ( irA_X2hl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_X3
  (
    .msg ( irA_X3hl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_W
  (
    .msg ( irA_Whl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_debug
  (
    .msg ( irA_debug )
  );

  riscv_InstMsgDisasm inst1_msg_disasm_D
  (
    .msg ( ir1_Dhl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_X0
  (
    .msg ( irB_X0hl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_X1
  (
    .msg ( irB_X1hl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_X2
  (
    .msg ( irB_X2hl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_X3
  (
    .msg ( irB_X3hl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_W
  (
    .msg ( irB_Whl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_debug
  (
    .msg ( irB_debug )
  );

  `endif

//========================================================================
// Assertions
//========================================================================
// Detect illegal instructions and terminate the simulation if multiple
// illegal instructions are detected in succession.

  `ifndef SYNTHESIS

  reg overload = 1'b0;

  always @ ( posedge clk ) begin
    if (( !cs0[`RISCV_INST_MSG_INST_VAL] && !reset ) 
     || ( !cs1[`RISCV_INST_MSG_INST_VAL] && !reset )) begin
      $display(" RTL-ERROR : %m : Illegal instruction!");

      if ( overload == 1'b1 ) begin
        $finish;
      end

      overload = 1'b1;
    end
    else begin
      overload = 1'b0;
    end
  end

  `endif

//========================================================================
// Stats
//========================================================================

  `ifndef SYNTHESIS

  reg [31:0] num_inst    = 32'b0;
  reg [31:0] num_cycles  = 32'b0;
  reg        stats_en    = 1'b0; // Used for enabling stats on asm tests

  always @( posedge clk ) begin
    if ( !reset ) begin

      // Count cycles if stats are enabled

      if ( stats_en || csr_stats ) begin
        num_cycles = num_cycles + 1;

        // Count instructions for every cycle not squashed or stalled

        // FIXME: fix this when you can have at most two instructions issued per cycle!
        if ( inst_val_Dhl && !stall_Dhl ) begin
          num_inst = num_inst + 1;
        end

      end

    end
  end

  `endif

endmodule

`endif

// vim: set textwidth=0 ts=2 sw=2 sts=2 :
