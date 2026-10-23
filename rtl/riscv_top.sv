`timescale 1ns/1ps

import riscv_pkg::*;

module riscv_top #(
    parameter int    MEM_DEPTH = 1024,
    parameter HEX_FILE  = "program.hex"
) (
    input logic clk,
    input logic reset
);

  // Signals
  logic [31:0] pc_curr, pc_next, pc_plus4, branch_target, jalr_target, jump_target;
  logic [31:0] inst;
  logic [6:0]  opcode;
  logic [4:0]  rs1, rs2, rd;
  logic [2:0]  funct3;
  logic        funct7_b5;

  logic [1:0]  alu_op_type;
  logic        is_i_type, alu_src, reg_write, mem_read, mem_write, branch, jump, pc_src_a, is_jalr;
  logic [1:0]  mem_to_reg;
  alu_op_e     alu_ctrl;

  logic [31:0] imm_out, rdata1, rdata2, alu_operand_a, alu_operand_b, alu_result, mem_rdata, writeback_data;
  logic        alu_zero, alu_sign, alu_overflow, alu_carry, alu_lt, alu_ltu;
  logic        take_branch, pc_src;

  // Slicing
  assign opcode    = inst[6:0];
  assign rd        = inst[11:7];
  assign funct3    = inst[14:12];
  assign rs1       = inst[19:15];
  assign rs2       = inst[24:20];
  assign funct7_b5 = inst[30];

  // PC Logic
  assign pc_plus4      = pc_curr + 32'd4;
  assign branch_target = pc_curr + $signed(imm_out);
  assign jalr_target   = alu_result & ~32'h1;
  assign jump_target   = (is_jalr) ? jalr_target : branch_target;

  always_comb begin
    case (funct3)
      F3_BEQ:  take_branch = alu_zero;
      F3_BNE:  take_branch = !alu_zero;
      F3_BLT:  take_branch = alu_lt;
      F3_BGE:  take_branch = !alu_lt;
      F3_BLTU: take_branch = alu_ltu;
      F3_BGEU: take_branch = !alu_ltu;
      default: take_branch = 1'b0;
    endcase
  end

  assign pc_src  = (branch & take_branch) | jump;
  assign pc_next = (pc_src) ? jump_target : pc_plus4;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) pc_curr <= 32'h00000000;
    else       pc_curr <= pc_next;
  end

  // Instruction Memory
  instruction_mem #(
      .MEM_DEPTH(MEM_DEPTH),
      .HEX_FILE (HEX_FILE)
  ) u_imem (
      .addr(pc_curr),
      .inst(inst)
  );

  // Control Unit
  control_unit u_ctrl (
      .opcode     (opcode),
      .alu_op_type(alu_op_type),
      .is_i_type  (is_i_type),
      .alu_src    (alu_src),
      .mem_to_reg (mem_to_reg),
      .reg_write  (reg_write),
      .mem_read   (mem_read),
      .mem_write  (mem_write),
      .branch     (branch),
      .jump       (jump),
      .pc_src_a   (pc_src_a),
      .is_jalr    (is_jalr)
  );

  alu_control u_alu_ctrl (
      .alu_op_type(alu_op_type),
      .funct3     (funct3),
      .funct7_b5  (funct7_b5),
      .is_i_type  (is_i_type),
      .alu_ctrl   (alu_ctrl)
  );

  imm_gen u_imm_gen (
      .inst   (inst),
      .imm_out(imm_out)
  );

  reg_file #(
      .DATA_WIDTH(32),
      .REG_COUNT (32)
  ) u_reg_file (
      .clk   (clk),
      .reset (reset),
      .wen   (reg_write),
      .waddr (rd),
      .wdata (writeback_data),
      .raddr1(rs1),
      .rdata1(rdata1),
      .raddr2(rs2),
      .rdata2(rdata2)
  );

  assign alu_operand_a = (pc_src_a) ? pc_curr : rdata1;
  assign alu_operand_b = (alu_src)  ? imm_out : rdata2;

  alu #(
      .DATA_WIDTH(32)
  ) u_alu (
      .a       (alu_operand_a),
      .b       (alu_operand_b),
      .alu_op  (alu_ctrl),
      .alu_out (alu_result),
      .zero    (alu_zero),
      .sign    (alu_sign),
      .overflow(alu_overflow),
      .carry   (alu_carry),
      .lt      (alu_lt),
      .ltu     (alu_ltu)
  );

  data_mem #(
      .MEM_DEPTH(MEM_DEPTH)
  ) u_dmem (
      .clk      (clk),
      .reset    (reset),
      .mem_read (mem_read),
      .mem_write(mem_write),
      .addr     (alu_result),
      .wdata    (rdata2),
      .rdata    (mem_rdata)
  );

  always_comb begin
    case (mem_to_reg)
      2'b00:   writeback_data = alu_result;
      2'b01:   writeback_data = mem_rdata;
      2'b10:   writeback_data = pc_plus4;
      default: writeback_data = alu_result;
    endcase
  end

endmodule
