`timescale 1ns/1ps

module riscv_top_tb;

  logic clk;
  logic reset;

  // Instantiate the complete CPU Core and load program.hex
  riscv_top #(
      .MEM_DEPTH(1024),
      .HEX_FILE ("program.hex")
  ) dut (
      .clk  (clk),
      .reset(reset)
  );

  // 10ns clock period (100MHz)
  always #5 clk <= ~clk;

  // Cycle counter for debugging
  int cycle_cnt;

  initial begin
    $dumpfile("riscv_top.vcd");
    $dumpvars(0, riscv_top_tb);

    clk       = 0;
    reset     = 1;
    cycle_cnt = 0;

    $display("=======================================================================");
    $display("               STARTING SINGLE-CYCLE RISC-V CPU SIMULATION             ");
    $display("=======================================================================");

    // Hold reset for 2 clock cycles
    #15;
    reset = 0;

    // Run through the branch cases, AUIPC, and JALR.
    repeat (12) begin
      @(posedge clk);
      #1; // Small delta delay to let signals settle after clock edge
      cycle_cnt++;
      $display("[Cycle %0d] PC: 0x%08h | Inst: 0x%08h | x1:%0d x2:%0d x3:%0d x4:0x%08h x5:0x%08h",
               cycle_cnt,
               dut.pc_curr,
               dut.inst,
               dut.u_reg_file.registers[1],
               dut.u_reg_file.registers[2],
               dut.u_reg_file.registers[3],
               dut.u_reg_file.registers[4],
               dut.u_reg_file.registers[5]);
    end

    $display("=======================================================================");
    $display("                       VERIFYING FINAL CPU STATE                       ");
    $display("=======================================================================");

    // Automated Assertions for New RV32I Features

    // 1. Register Initializations
    assert(dut.u_reg_file.registers[1] === 32'd0)
      else $fatal(1, "[FAILED] Register x1 should be 0, got %0d", dut.u_reg_file.registers[1]);

    assert(dut.u_reg_file.registers[2] === 32'd1)
      else $fatal(1, "[FAILED] Register x2 should be 1, got %0d", dut.u_reg_file.registers[2]);

    assert(dut.u_reg_file.registers[3] === 32'd2)
      else $fatal(1, "[FAILED] Register x3 should be 2, got %0d", dut.u_reg_file.registers[3]);

    assert(dut.u_reg_file.registers[6] === 32'd0)
      else $fatal(1, "[FAILED] BLT should skip the x6 write, got %0d", dut.u_reg_file.registers[6]);

    assert(dut.u_reg_file.registers[7] === 32'd0)
      else $fatal(1, "[FAILED] BLTU should skip the x7 write, got %0d", dut.u_reg_file.registers[7]);

    // 2. AUIPC Target Calculation: PC (0x30) + 0x1000 = 0x00001030
    assert(dut.u_reg_file.registers[4] === 32'h00001030)
      else $fatal(1, "[FAILED] Register x4 (AUIPC) should be 0x00001030, got 0x%08h", dut.u_reg_file.registers[4]);

    // 3. JALR Return Address Save: PC + 4 (0x34 + 4) = 0x00000038
    assert(dut.u_reg_file.registers[5] === 32'h00000038)
      else $fatal(1, "[FAILED] Register x5 (JALR Return Addr) should be 0x00000038, got 0x%08h", dut.u_reg_file.registers[5]);

    $display("[SUCCESS] All Branch (BLTU/BGE/BLT), AUIPC, and JALR tests PASSED!");
    $display("=======================================================================");
    $finish;
  end

endmodule
