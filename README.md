# Single-Cycle RV32I Processor Core

A fully functional **32-bit Single-Cycle RISC-V Processor Core** designed and implemented in **SystemVerilog**.

The processor implements a subset of the **RISC-V RV32I Base Integer ISA** and includes a complete single-cycle datapath, instruction decoding, register file, ALU, immediate generation, instruction memory, data memory, and branch/jump control logic.

The design has been verified using **Verilator** and **Icarus Verilog (`iverilog`)** by executing compiled RISC-V machine-code instructions directly from simulated memory.

---

## Architecture

The processor follows a classic **single-cycle CPU architecture**, where each instruction is fetched, decoded, executed, and completed within a single clock cycle.

**CPI = 1.0**

```mermaid
flowchart LR
    PC["Program Counter<br/>PC"] --> IMEM["Instruction Memory<br/>program.hex"]
    IMEM --> DEC["Instruction Decode"]
    DEC --> CTRL["Main Control Unit"]
    DEC --> IMM["Immediate Generator"]

    DEC -->|rs1, rs2| RF["Register File<br/>x0-x31"]
    CTRL -->|ALU operation type| ALUCTRL["ALU Control"]
    DEC -->|funct3, funct7[5]| ALUCTRL

    RF -->|read data 1| ASEL{"ALU input A"}
    PC -->|AUIPC source| ASEL
    CTRL -->|PC or rs1 select| ASEL
    ASEL --> ALU["32-bit ALU"]
    RF -->|read data 2| BSEL{"ALU input B"}
    IMM --> BSEL
    CTRL -->|register or immediate select| BSEL
    BSEL --> ALU
    ALUCTRL -->|operation| ALU

    ALU -->|address| DMEM["Data Memory"]
    RF -->|store data| DMEM
    CTRL -->|read / write enables| DMEM
    ALU --> WBSEL{"Writeback Select"}
    DMEM --> WBSEL
    PC4["PC + 4"] --> WBSEL
    CTRL -->|writeback source| WBSEL
    WBSEL -->|write result| RF

    PC --> PC4
    PC --> BTA["Branch Target<br/>PC + immediate"]
    ALU -->|JALR target<br/>(result & ~1)| PCSEL{"Next-PC Select"}
    BTA --> PCSEL
    PC4 --> PCSEL
    CTRL -->|branch / jump controls| PCSEL
    ALU -->|zero / signed lt / unsigned ltu| PCSEL
    PCSEL -->|next PC| PC
```

---

## Key Features

### 1. Strongly Typed SystemVerilog Design

The design uses SystemVerilog `enum` types for instruction opcodes and ALU operations.

This improves:

- Type safety
- Readability
- Maintainability
- Protection against accidental net-width mismatches

---

### 2. Two-Level Instruction Decoding

The control logic is divided into two stages.

#### Main Control Unit

The main control unit decodes the instruction opcode:

```text
inst[6:0]
```

and generates the primary datapath control signals:

- `reg_write`
- `alu_src`
- `mem_to_reg`
- `mem_read`
- `mem_write`
- `branch`
- `jump`

#### ALU Control Unit

The ALU control logic further decodes:

- ALU operation type
- `funct3`
- `funct7[5]`
- Instruction type

to generate the required ALU operation.

This allows the processor to correctly differentiate operations such as:

```text
ADD
SUB
ADDI
SLL
SRL
SRA
SLT
SLTU
```

---

## Processor Components

### ALU

The 32-bit ALU supports:

- Addition
- Subtraction
- Logical left shift (`SLL`)
- Logical right shift (`SRL`)
- Arithmetic right shift (`SRA`)
- Signed comparison (`SLT`)
- Unsigned comparison (`SLTU`)
- Bitwise AND
- Bitwise OR
- Bitwise XOR

The ALU also generates status information including:

- `zero`
- `sign`
- `overflow`
- `carry`
- `ltu`

---

### Register File

The processor contains:

```text
32 × 32-bit registers
```

from:

```text
x0 - x31
```

Register `x0` is hardwired to zero according to the RISC-V specification.

Therefore:

```text
x0 = 32'h00000000
```

regardless of attempted writes.

The register file supports:

- Two simultaneous read ports
- One write port
- Synchronous register writes

---

### Immediate Generator

The immediate generator supports the following RISC-V instruction formats:

- I-Type
- S-Type
- B-Type
- U-Type
- J-Type

Immediate values are extracted from the instruction and appropriately sign-extended to 32 bits.

---

### Instruction Memory

The instruction memory is implemented as a byte-addressed memory with word-aligned instruction access.

Instructions are loaded automatically using:

```systemverilog
$readmemh
```

The processor fetches instructions using the program counter:

```text
PC → Instruction Memory → Instruction
```

---

### Data Memory

The data memory provides:

- Asynchronous read access
- Synchronous write access
- Word-based data storage

This allows load/store instructions to operate within the single-cycle datapath.

---

# Supported RV32I Instructions

| Type | Instructions | Description |
|------|--------------|-------------|
| **R-Type** | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` | Register-register operations |
| **I-Type** | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` | Register-immediate operations |
| **Load** | `LW` | Load word from memory |
| **Store** | `SW` | Store word to memory |
| **Branch** | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` | Equality, signed, and unsigned conditional branches |
| **Jump** | `JAL`, `JALR` | Direct and register-indirect jump-and-link |
| **Upper Immediate** | `LUI`, `AUIPC` | Load upper immediate or add upper immediate to the PC |

---

# Repository Structure

```text
risc-v/
│
├── rtl/
│   ├── alu.sv
│   ├── control_unit.sv
│   ├── imm.sv
│   ├── reg_file.sv
│   ├── instruction_mem.sv
│   ├── data_mem.sv
│   └── riscv_top.sv
│
├── tb/
│   ├── alu_tb.sv
│   ├── control_unit_tb.sv
│   ├── imm_tb.sv
│   ├── reg_file_tb.sv
│   └── riscv_top_tb.sv
│
├── program.hex
├── riscv_top.gtkw
└── README.md
```

### Directory Description

| Directory/File | Purpose |
|----------------|---------|
| `rtl/` | Processor RTL implementation |
| `tb/` | Unit and integration testbenches |
| `program.hex` | Machine-code program executed by the processor |
| `riscv_top.gtkw` | GTKWave layout with useful CPU signals preselected |
| `README.md` | Project documentation |

---

# Verification

The processor is verified using both:

- **Verilator**
- **Icarus Verilog**

The integration testbench loads machine-code instructions from:

```text
program.hex
```

and executes them directly through the processor.

---

## Instruction-by-Instruction Program Walkthrough

The integration test executes the machine-code words in [`program.hex`](program.hex) from address `0x00`. This short program checks register setup, signed and unsigned branch decisions, `AUIPC`, and `JALR`.

| PC | Machine code | Assembly | Format | What happens |
|----|--------------|----------|--------|--------------|
| `0x00` | `00000093` | `ADDI x1, x0, 0` | I | Initialize `x1 = 0`. |
| `0x04` | `00100113` | `ADDI x2, x0, 1` | I | Initialize `x2 = 1`. |
| `0x08` | `00200193` | `ADDI x3, x0, 2` | I | Initialize `x3 = 2`. |
| `0x0C` | `0020C463` | `BLT x1, x2, 8` | B | Signed comparison `0 < 1` is true; branch to `0x14`, skipping the write to `x6`. |
| `0x10` | `06300313` | `ADDI x6, x0, 99` | I | Deliberately skipped; `x6` must remain `0`. |
| `0x14` | `0020D263` | `BGE x1, x2, 4` | B | Signed comparison `0 >= 1` is false; continue to `0x18`. |
| `0x18` | `0020E463` | `BLTU x1, x2, 8` | B | Unsigned comparison `0 < 1` is true; branch to `0x20`, skipping the write to `x7`. |
| `0x1C` | `06300393` | `ADDI x7, x0, 99` | I | Deliberately skipped; `x7` must remain `0`. |
| `0x20` | `0020F263` | `BGEU x1, x2, 4` | B | Unsigned comparison `0 >= 1` is false; continue to `0x24`. |
| `0x24` | `00000013` | `ADDI x0, x0, 0` (`NOP`) | I | No operation; writes to `x0` are ignored. |
| `0x28` | `00000013` | `ADDI x0, x0, 0` (`NOP`) | I | No operation; advances to `0x2C`. |
| `0x2C` | `00000013` | `ADDI x0, x0, 0` (`NOP`) | I | No operation; advances to `0x30`. |
| `0x30` | `00001217` | `AUIPC x4, 1` | U | Set `x4 = PC + (1 << 12) = 0x30 + 0x1000 = 0x1030`. |
| `0x34` | `000202E7` | `JALR x5, 0(x4)` | I | Jump to `x4 & ~1 = 0x1030`; save return address `0x38` in `x5`. |

### How the branch checks work

The two instructions that write `99` are intentional **poison instructions**: if either branch fails to take when expected, the corresponding register changes and the integration test fails.

- `BLT` and `BLTU` must take the branch and skip the write to `x6` or `x7`.
- `BGE` and `BGEU` must not take the branch for the values `x1 = 0` and `x2 = 1`.
- The testbench checks that both `x6` and `x7` remain zero.

### Expected final state

After the test program runs, the integration test checks:

| Register | Expected value | Reason |
|----------|----------------|--------|
| `x1` | `0x00000000` | Initial value for branch comparisons |
| `x2` | `0x00000001` | Initial value for branch comparisons |
| `x3` | `0x00000002` | Register setup instruction |
| `x4` | `0x00001030` | `AUIPC` result used as the `JALR` target |
| `x5` | `0x00000038` | Return address saved by `JALR` |
| `x6` | `0x00000000` | Confirms the `BLT` skipped its poison instruction |
| `x7` | `0x00000000` | Confirms the `BLTU` skipped its poison instruction |

---

# Running the Simulation

## Prerequisites

Install:

- SystemVerilog-compatible simulator
- Verilator
- Icarus Verilog
- GTKWave (optional, for waveform analysis)

The project was developed and tested under:

```text
Linux / WSL
Ubuntu
VS Code
```

---

## Verilator

Run:

```bash
verilator --binary --trace -j 0 -Wall \
  -Wno-DECLFILENAME \
  -Wno-IMPORTSTAR \
  -Wno-UNUSEDSIGNAL \
  -Wno-UNUSEDPARAM \
  rtl/alu.sv \
  rtl/imm.sv \
  rtl/reg_file.sv \
  rtl/control_unit.sv \
  rtl/instruction_mem.sv \
  rtl/data_mem.sv \
  rtl/riscv_top.sv \
  tb/riscv_top_tb.sv \
  --top-module riscv_top_tb
```

Then run the generated simulation:

```bash
./obj_dir/Vriscv_top_tb
```

---

## Icarus Verilog

Compile the design:

```bash
iverilog -g2012 \
  rtl/alu.sv \
  rtl/imm.sv \
  rtl/reg_file.sv \
  rtl/control_unit.sv \
  rtl/instruction_mem.sv \
  rtl/data_mem.sv \
  rtl/riscv_top.sv \
  tb/riscv_top_tb.sv \
  -o sim_cpu
```

Run:

```bash
vvp sim_cpu
```

## View the waveform in GTKWave

The integration testbench writes signal activity to `riscv_top.vcd`. Run the simulation from the repository root, then open the waveform with the included signal layout:

```bash
gtkwave riscv_top.vcd riscv_top.gtkw
```

The layout preselects the clock and reset, PC and instruction, ALU inputs and result, branch decisions, and register writeback signals. The VCD is generated locally and is intentionally ignored by Git; rerun the simulation whenever you want a fresh trace.

### GTKWave screenshot

To add a screenshot, save it as `docs/images/riscv-top-waveform.png`, then insert it here:

```markdown
![RISC-V CPU waveform in GTKWave](docs/images/riscv-top-waveform.png)
```

---

# Expected Verification Output

A successful simulation produces output similar to:

```text
=======================================================================
               STARTING SINGLE-CYCLE RISC-V CPU SIMULATION
=======================================================================

[Cycle 10] PC: 0x00000030 | Inst: 0x00001217 | x1:0 x2:1 x3:2 x4:0x00000000 x5:0x00000000
[Cycle 11] PC: 0x00000034 | Inst: 0x000202e7 | x1:0 x2:1 x3:2 x4:0x00001030 x5:0x00000000
[Cycle 12] PC: 0x00001030 | Inst: 0x00000000 | x1:0 x2:1 x3:2 x4:0x00001030 x5:0x00000038

=======================================================================
                       VERIFYING FINAL CPU STATE
=======================================================================

[SUCCESS] All Branch (BLTU/BGE/BLT), AUIPC, and JALR tests PASSED!

=======================================================================
```

---

# Verification Strategy

The project uses multiple levels of verification.

### Unit-Level Verification

Individual modules are tested independently:

```text
ALU
│
├── Arithmetic operations
├── Logical operations
├── Shift operations
├── Comparison operations
└── Status flags
```

```text
Register File
│
├── Register reads
├── Register writes
└── x0 hardwired-zero behavior
```

```text
Immediate Generator
│
├── I-Type
├── S-Type
├── B-Type
├── U-Type
└── J-Type
```

```text
Control Unit
│
└── Opcode → Control Signal verification
```

### Integration-Level Verification

The complete processor is tested by executing actual RISC-V machine instructions through the entire datapath:

```text
Machine Code
     ↓
Instruction Memory
     ↓
Instruction Decode
     ↓
Register File
     ↓
Immediate Generator
     ↓
ALU
     ↓
Data Memory
     ↓
Writeback
     ↓
Register File
```

This verifies that the individual modules work correctly together as a processor.

---

# Tools & Technologies

| Category | Tool |
|----------|------|
| HDL | SystemVerilog |
| ISA | RISC-V RV32I |
| Simulation | Verilator |
| Simulation | Icarus Verilog |
| Waveform Analysis | GTKWave |
| Development Environment | VS Code |
| OS | Linux / WSL Ubuntu |

---

# Design Highlights

Some of the key concepts implemented in this project include:

- Single-cycle CPU datapath
- RISC-V instruction decoding
- SystemVerilog `enum` types
- Two-level control decoding
- Register file design
- Immediate generation
- ALU design
- Branch decision logic
- Program counter logic
- Instruction memory
- Data memory
- Load/store operations
- Synchronous memory writes
- Asynchronous memory reads
- Machine-code execution
- RTL simulation and verification

---

# Future Work

The current processor implements a tested subset of RV32I. Planned improvements include:

- [ ] Add byte and halfword loads:
  - `LB`
  - `LH`
  - `LBU`
  - `LHU`
- [ ] Add byte and halfword stores:
  - `SB`
  - `SH`
- [ ] Add official RISC-V architecture compliance testing
- [ ] Run the `riscv-arch-test` compliance suite
- [ ] Improve memory subsystem
- [ ] Add more comprehensive automated testbenches
- [ ] Convert the single-cycle processor into a **5-stage pipelined RV32I processor**
- [ ] Implement pipeline registers
- [ ] Add hazard detection
- [ ] Add data forwarding
- [ ] Handle control hazards and pipeline flushing

---

# Learning Outcomes

This project provided hands-on experience with:

- RISC-V ISA and instruction encoding
- Computer architecture
- Datapath and control-path design
- RTL design using SystemVerilog
- Hardware modularization
- Synchronous digital design
- Memory modeling
- Instruction decoding
- CPU verification
- Simulation and waveform debugging
- Linux/WSL-based HDL development

---

## Project Status

**Status: Functional and Verified**

The processor successfully executes the implemented RV32I instructions and has been verified through both unit-level and processor-level simulation.

---

## Author

**Ravi Teja**

Electronics & Communication Engineering

Interested in:

- Digital Design
- RTL Design
- Computer Architecture
- RISC-V
- SystemVerilog
- Verification
- VLSI
- Machine Learning / AI
