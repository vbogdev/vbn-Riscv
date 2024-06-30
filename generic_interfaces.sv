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

interface branch_fb_ifc();
    logic if_branch;
    logic if_prediction_correct;
    riscv_pkg::BranchOutcome outcome;
    logic [`ADDR_WIDTH-1:0] branch_pc;
    logic [`ADDR_WIDTH-1:0] new_pc;
    
    modport in(input if_branch, if_prediction_correct, outcome, branch_pc, new_pc);
    modport out(output if_branch, if_prediction_correct, outcome, branch_pc, new_pc);
    
endinterface

interface branch_fb_decode_ifc();
    logic if_branch;
    logic [`ADDR_WIDTH-1:0] branch_target;
    logic if_prediction_correct;
    riscv_pkg::BranchOutcome prediction;
    logic [`ADDR_WIDTH-1:0] prediction_pc;
    logic [`ADDR_WIDTH-1:0] new_pc;
    
    modport in(input if_branch, branch_target, if_prediction_correct, prediction, prediction_pc, new_pc);
    modport out(output if_branch, branch_target, if_prediction_correct, prediction, prediction_pc, new_pc);    
endinterface 
    
    
interface decode_out_ifc();
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
    
    modport in(input uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, imm, alu_operation, is_fp, target,
        is_branch, is_jump, is_jump_register, branch_op, prediction, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type);
    
    modport out(output uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, imm, alu_operation, is_fp, target,
        is_branch, is_jump, is_jump_register, branch_op, prediction, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type);
endinterface