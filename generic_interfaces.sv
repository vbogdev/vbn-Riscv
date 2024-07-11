`include "riscv_core.svh"

interface fetch_out_ifc();
    logic valid;
    logic [`ADDR_WIDTH-1:0] pc;
    logic [31:0] instr;
    logic guesses_branch;
    logic [`ADDR_WIDTH-1:0] prediction;
    
    modport in(input valid, pc, instr, guesses_branch, prediction);
    modport out(output valid, pc, instr, guesses_branch, prediction);
endinterface

interface graduation_ifc();
    logic valid;
    modport in(input valid);
    modport out(output valid);
endinterface

interface wb_ifc();
    logic valid;
    logic [$clog2(`AL_SIZE)-1:0] al_idx;
    logic [31:0] data;
    logic [5:0] rd;
    logic uses_rd;
    modport in(input valid, al_idx, data, rd, uses_rd);
    modport out(output valid, al_idx, data, rd, uses_rd);
endinterface


interface branch_fb_ifc();
    logic if_branch;
    logic if_prediction_correct;
    riscv_pkg::BranchOutcome outcome;
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] cp_addr;
    logic [`ADDR_WIDTH-1:0] branch_pc;
    logic [`ADDR_WIDTH-1:0] new_pc;
    
    modport in(input if_branch, if_prediction_correct, outcome, cp_addr, branch_pc, new_pc);
    modport out(output if_branch, if_prediction_correct, outcome, cp_addr, branch_pc, new_pc);
    
endinterface

interface branch_fb_decode_ifc();
    logic if_branch;
    logic if_prediction_correct;
    logic [`ADDR_WIDTH-1:0] new_pc;
    
    modport in(input if_branch, if_prediction_correct, new_pc);
    modport out(output if_branch, if_prediction_correct, new_pc);    
endinterface 


    
interface decode_out_ifc();
    logic valid;
    
    logic uses_rd, uses_rs1, uses_rs2, uses_imm;
    logic [4:0] rd, rs1, rs2;
    logic [31:0] imm;
    riscv_pkg::AluCtl alu_operation;
    logic is_fp;
    
    logic [`ADDR_WIDTH-1:0] target;
    logic is_branch;
    logic is_jump;
    logic is_jump_register;
    riscv_pkg::funct3_branch branch_op;
    riscv_pkg::BranchOutcome prediction;
    
    logic is_mem_access;
    riscv_pkg::MemAccessType mem_access_type;
    riscv_pkg::MemWidth width;
    
    logic accesses_csr;
    riscv_pkg::funct3_CSR csr_op;
    logic [11:0] csr_addr;
    
    logic ecall;
    logic ebreak;
    
    logic amo_instr;
    logic aq;
    logic rl;
    riscv_pkg::AmoType amo_type;
    
    
    modport in(input valid, uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, imm, alu_operation, is_fp, target,
        is_branch, is_jump, is_jump_register, branch_op, prediction, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type);
    
    modport out(output valid, uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, imm, alu_operation, is_fp, target,
        is_branch, is_jump, is_jump_register, branch_op, prediction, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type);
endinterface


interface rename_out_ifc();
    logic valid;
    logic [5:0] rs1, rs2, rd;
    logic uses_rs1, uses_rs2, uses_rd, uses_imm;
    logic rs1_ready, rs2_ready;
    logic [31:0] imm;
    riscv_pkg::AluCtl alu_operation;
    logic is_fp;
    
    logic [`ADDR_WIDTH-1:0] target;
    logic is_branch;
    logic is_jump;
    logic is_jump_register;
    riscv_pkg::funct3_branch branch_op;
    riscv_pkg::BranchOutcome prediction;
    
    logic is_mem_access;
    riscv_pkg::MemAccessType mem_access_type;
    riscv_pkg::MemWidth width;
    
    logic accesses_csr;
    riscv_pkg::funct3_CSR csr_op;
    logic [11:0] csr_addr;
    
    logic ecall;
    logic ebreak;
    
    logic amo_instr;
    logic aq;
    logic rl;
    riscv_pkg::AmoType amo_type;
    
    logic [$clog2(`AL_SIZE)-1:0] al_addr;

     modport in(input valid, uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, imm, alu_operation, is_fp, target,
        is_branch, is_jump, is_jump_register, branch_op, prediction, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type, al_addr);
    
    modport out(output valid, uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, imm, alu_operation, is_fp, target,
        is_branch, is_jump, is_jump_register, branch_op, prediction, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type, al_addr);
endinterface

interface aiq_ifc();
    logic valid;
    logic [5:0] rs1, rs2, rd;
    logic uses_rs1, uses_rs2, uses_rd, uses_imm;
    logic [31:0] imm;
    riscv_pkg::AluCtl alu_operation;
    
    logic [`ADDR_WIDTH-1:0] target;
    logic is_branch;
    logic is_jump;
    logic is_jump_register;
    riscv_pkg::funct3_branch branch_op;
    riscv_pkg::BranchOutcome prediction;
    
    modport in(input valid, rs1, rs2, rd, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, alu_operation,
        target, is_branch, is_jump, is_jump_register, branch_op, prediction);
    modport out(output valid, rs1, rs2, rd, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, alu_operation,
        target, is_branch, is_jump, is_jump_register, branch_op, prediction);
    
endinterface 

interface ziq_ifc();
    logic valid;
    logic [5:0] rs1, rs2, rd;
endinterface

interface miq_ifc();
    
endinterface
