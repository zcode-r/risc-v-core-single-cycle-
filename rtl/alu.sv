`timescale 1ns/1ps

// ============================================================================
// Package: riscv_pkg
// ============================================================================
package riscv_pkg;

  // -------------------------------------------------------------
  // Fully Typed RV32I ALU Operation Selector
  // -------------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_SLL  = 4'b0010, // Shift Left Logical
    ALU_SLT  = 4'b0011, // Set Less Than (Signed)
    ALU_SLTU = 4'b0100, // Set Less Than (Unsigned)
    ALU_XOR  = 4'b0101,
    ALU_SRL  = 4'b0110, // Shift Right Logical
    ALU_SRA  = 4'b0111, // Shift Right Arithmetic (Preserves Sign)
    ALU_OR   = 4'b1000,
    ALU_AND  = 4'b1001,
    ALU_PASS = 4'b1111  // Pass Operand B (for LUI)
  } alu_op_e;

  // -------------------------------------------------------------
  // Standard RV32I 7-bit Opcodes
  // -------------------------------------------------------------
  typedef enum logic [6:0] {
    OPC_R_TYPE  = 7'b0110011, // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
    OPC_I_ARITH = 7'b0010011, // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
    OPC_I_LOAD  = 7'b0000011, // LW, LH, LB, LHU, LBU
    OPC_I_JALR  = 7'b1100111, // JALR
    OPC_S_TYPE  = 7'b0100011, // SW, SH, SB
    OPC_B_TYPE  = 7'b1100011, // BEQ, BNE, BLT, BGE, BLTU, BGEU
    OPC_U_LUI   = 7'b0110111, // LUI
    OPC_U_AUIPC = 7'b0010111, // AUIPC
    OPC_J_JAL   = 7'b1101111  // JAL
  } opcode_e;

  // -------------------------------------------------------------
  // Standard RV32I 3-bit funct3 Encodings
  // -------------------------------------------------------------
  localparam logic [2:0] F3_ADD_SUB = 3'b000;
  localparam logic [2:0] F3_SLL     = 3'b001;
  localparam logic [2:0] F3_SLT     = 3'b010;
  localparam logic [2:0] F3_SLTU    = 3'b011;
  localparam logic [2:0] F3_XOR     = 3'b100;
  localparam logic [2:0] F3_SRL_SRA = 3'b101;
  localparam logic [2:0] F3_OR      = 3'b110;
  localparam logic [2:0] F3_AND     = 3'b111;

  // Branch funct3 Encodings
  localparam logic [2:0] F3_BEQ     = 3'b000;
  localparam logic [2:0] F3_BNE     = 3'b001;
  localparam logic [2:0] F3_BLT     = 3'b100;
  localparam logic [2:0] F3_BGE     = 3'b101;
  localparam logic [2:0] F3_BLTU    = 3'b110;
  localparam logic [2:0] F3_BGEU    = 3'b111;

endpackage

import riscv_pkg::*;

// ============================================================================
// Module: ALU
// ============================================================================
module alu #(
  parameter int DATA_WIDTH = 32
)(
  input  logic [DATA_WIDTH-1:0] a,
  input  logic [DATA_WIDTH-1:0] b,
  input  alu_op_e               alu_op,

  output logic [DATA_WIDTH-1:0] alu_out,
  output logic                  zero,
  output logic                  carry,
  output logic                  sign,
  output logic                  overflow,
  output logic                  lt,   // Signed less-than flag  (for BLT/BGE)
  output logic                  ltu   // Unsigned less-than flag (for BLTU/BGEU)
);

  logic [DATA_WIDTH:0] temp_math;
  logic [4:0]          shift_amt;

  assign shift_amt = b[4:0]; // Limit shift amount to 0-31 bits

  always_comb begin
    alu_out   = '0;
    temp_math = '0;
    overflow  = 1'b0;
    carry     = 1'b0;

    case (alu_op)
      ALU_ADD: begin
        temp_math = {1'b0, a} + {1'b0, b};
        alu_out   = temp_math[DATA_WIDTH-1:0];
        carry     = temp_math[DATA_WIDTH];
        overflow  = (~(a[DATA_WIDTH-1] ^ b[DATA_WIDTH-1])) & (a[DATA_WIDTH-1] ^ alu_out[DATA_WIDTH-1]);
      end

      ALU_SUB: begin
        temp_math = {1'b0, a} - {1'b0, b};
        alu_out   = temp_math[DATA_WIDTH-1:0];
        carry     = temp_math[DATA_WIDTH];
        overflow  = ((a[DATA_WIDTH-1] ^ b[DATA_WIDTH-1])) & (a[DATA_WIDTH-1] ^ alu_out[DATA_WIDTH-1]);
      end

      ALU_SLL: begin
        alu_out = a << shift_amt;
      end

      ALU_SRL: begin
        alu_out = a >> shift_amt;
      end

      ALU_SRA: begin
        alu_out = $signed(a) >>> shift_amt;
      end

      ALU_SLT: begin
        alu_out = ($signed(a) < $signed(b)) ? {{DATA_WIDTH-1{1'b0}}, 1'b1} : '0;
      end

      ALU_SLTU: begin
        alu_out = (a < b) ? {{DATA_WIDTH-1{1'b0}}, 1'b1} : '0;
      end

      ALU_XOR:  alu_out = a ^ b;
      ALU_OR:   alu_out = a | b;
      ALU_AND:  alu_out = a & b;
      ALU_PASS: alu_out = b; // Pass Operand B (used by LUI)

      default:  alu_out = '0;
    endcase
  end

// Continuous Flag Outputs
  assign zero = (alu_out == 32'h0);
  assign sign = alu_out[DATA_WIDTH-1];

  // Explicit Signed Comparison (a < b)
  assign lt   = ($signed(a) < $signed(b)) ? 1'b1 : 1'b0;

  // Explicit Unsigned Comparison (a < b)
  assign ltu  = (a < b) ? 1'b1 : 1'b0;

endmodule

// ============================================================================
// Module: ALU Control
// ============================================================================
module alu_control (
  input  logic [1:0] alu_op_type,
  input  logic [2:0] funct3,
  input  logic       funct7_b5,
  input  logic       is_i_type,
  output alu_op_e    alu_ctrl
);

  always_comb begin
    case (alu_op_type)
      2'b00: alu_ctrl = ALU_ADD; // LW, SW, AUIPC, JALR

      // Branch Comparison Selection
      2'b01: begin
        case (funct3)
          F3_BEQ, F3_BNE:   alu_ctrl = ALU_SUB;  // Generates zero flag
          F3_BLT, F3_BGE:   alu_ctrl = ALU_SLT;  // Generates signed lt flag
          F3_BLTU, F3_BGEU: alu_ctrl = ALU_SLTU; // Generates unsigned ltu flag
          default:          alu_ctrl = ALU_SUB;
        endcase
      end

      // R-Type and I-Type Arithmetic
      2'b10: begin
        case (funct3)
          F3_ADD_SUB: begin
            if (!is_i_type && funct7_b5) alu_ctrl = ALU_SUB;
            else                         alu_ctrl = ALU_ADD;
          end

          F3_SLL:  alu_ctrl = ALU_SLL;
          F3_SLT:  alu_ctrl = ALU_SLT;
          F3_SLTU: alu_ctrl = ALU_SLTU;
          F3_XOR:  alu_ctrl = ALU_XOR;

          F3_SRL_SRA: begin
            if (funct7_b5) alu_ctrl = ALU_SRA;
            else           alu_ctrl = ALU_SRL;
          end

          F3_OR:   alu_ctrl = ALU_OR;
          F3_AND:  alu_ctrl = ALU_AND;
          default: alu_ctrl = ALU_ADD;
        endcase
      end

      2'b11:   alu_ctrl = ALU_PASS; // LUI
      default: alu_ctrl = ALU_ADD;
    endcase
  end

endmodule
