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
    modport wb(input valid, uses_rd, rd);
endinterface


interface branch_fb_ifc();
    logic if_branch;
    logic if_prediction_correct;
    riscv_pkg::BranchOutcome outcome;
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] cp_addr;
    logic [$clog2(`AL_SIZE)-1:0] al_addr;
    logic [`ADDR_WIDTH-1:0] branch_pc;
    logic [`ADDR_WIDTH-1:0] new_pc;
    logic is_jr;
    
    modport in(input if_branch, if_prediction_correct, outcome, cp_addr, al_addr, branch_pc, new_pc, is_jr);
    modport out(output if_branch, if_prediction_correct, outcome, cp_addr, al_addr, branch_pc, new_pc, is_jr);
    
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
    logic [`ADDR_WIDTH-1:0] pc;
    
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
    
    
    modport in(input valid, pc, uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, imm, alu_operation, is_fp, target,
        is_branch, is_jump, is_jump_register, branch_op, prediction, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type);
    
    modport out(output valid, pc, uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, imm, alu_operation, is_fp, target,
        is_branch, is_jump, is_jump_register, branch_op, prediction, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type);
endinterface


interface rename_out_ifc();
    logic valid;
    logic [`ADDR_WIDTH-1:0] pc;
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
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] cp_addr;
    
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

     modport in(input valid, pc, uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, rs1_ready, rs2_ready, imm, alu_operation, is_fp, 
        target, is_branch, is_jump, is_jump_register, branch_op, prediction, cp_addr, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type, al_addr);
    
    modport out(output valid, pc, uses_rd, uses_rs1, uses_rs2, uses_imm, rd, rs1, rs2, rs1_ready, rs2_ready, imm, alu_operation, 
        is_fp, target, is_branch, is_jump, is_jump_register, branch_op, prediction, cp_addr, is_mem_access, mem_access_type, width, 
        accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type, al_addr);
        
    modport in_aiq(input valid, pc, rs1, rs2, rd, rs1_ready, rs2_ready, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, alu_operation,
        al_addr, target, is_branch, is_jump, is_jump_register, branch_op, prediction, cp_addr, is_fp, accesses_csr, is_mem_access);
    
    modport in_ioiq(input valid, pc, rs1, rs2, rd, rs1_ready, rs2_ready, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, al_addr, 
        cp_addr, is_mem_access, mem_access_type, width, accesses_csr, csr_op, csr_addr, ecall, ebreak, amo_instr, aq, rl, amo_type);
endinterface

interface instr_type_ifc();
    logic is_fp;
    logic is_mem_access;
    logic accesses_csr;
    
    modport in(input is_fp, is_mem_access, accesses_csr);
    modport out(output is_fp, is_mem_access, accesses_csr);
endinterface

interface aiq_ifc();
    logic valid;
    logic [`ADDR_WIDTH-1:0] pc;
    logic [5:0] rs1, rs2, rd;
    logic uses_rs1, uses_rs2, uses_rd, uses_imm;
    logic [31:0] imm;
    riscv_pkg::AluCtl alu_operation;
    logic [$clog2(`AL_SIZE)-1:0] al_addr;
    
    logic [`ADDR_WIDTH-1:0] target;
    logic is_branch;
    logic is_jump;
    logic is_jump_register;
    riscv_pkg::funct3_branch branch_op;
    riscv_pkg::BranchOutcome prediction;
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] cp_addr;

    modport in(input valid, pc, rs1, rs2, rd, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, alu_operation,
        al_addr, target, is_branch, is_jump, is_jump_register, branch_op, prediction, cp_addr);
    modport out(output valid, pc, rs1, rs2, rd, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, alu_operation,
        al_addr, target, is_branch, is_jump, is_jump_register, branch_op, prediction, cp_addr);
    modport out_rf(output valid, pc, rd, uses_rd, uses_imm, imm, alu_operation, al_addr, target, is_branch, 
        is_jump, is_jump_register, branch_op, prediction, cp_addr);
    
endinterface 

/*interface ziq_ifc();
    logic valid;
    logic [`ADDR_WIDTH-1:0] pc;
    logic [5:0] rs1, rs2, rd;
    logic uses_rs1, uses_rs2, uses_rd, uses_imm;
    logic [31:0] imm;
    
    logic accesses_csr;
    riscv_pkg::funct3_CSR csr_op;
    logic [11:0] csr_addr;
    
    modport in(input valid, pc, rs1, rs2, rd, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, accesses_csr,
        csr_op, csr_addr);
    modport out(output valid, pc, rs1, rs2, rd, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, accesses_csr,
        csr_op, csr_addr);
endinterface*/

interface miq_ifc();
    logic valid;
    logic [`ADDR_WIDTH-1:0] pc;
    logic [$clog2(`NUM_PR)-1:0] rs1, rs2, rd;
    logic uses_rs1, uses_rs2, uses_rd, uses_imm;
    logic [31:0] imm;
    logic [$clog2(`AL_SIZE)-1:0] al_addr;
    
    logic is_mem_access;
    riscv_pkg::MemAccessType mem_access_type;
    riscv_pkg::MemWidth width;
    
    
    modport in(input valid, pc, rs1, rs2, rd, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, is_mem_access,
        mem_access_type, width, al_addr);
    modport out(output valid, pc, rs1, rs2, rd, uses_rs1, uses_rs2, uses_rd, uses_imm, imm, is_mem_access,
        mem_access_type, width, al_addr);
    modport out_rf(output valid, pc, rd, uses_rd, uses_imm, imm, is_mem_access,
        mem_access_type, width, al_addr);
             
endinterface

interface reg_out_ifc();
    logic [31:0] rs1_val, rs2_val;
    modport in(input rs1_val, rs2_val);
    modport out(output rs1_val, rs2_val);
endinterface

interface reg_data_written();
    logic [$clog2(`NUM_PR)-1:0] rd;
    logic valid;
    modport in(input rd, valid);
    modport out(output rd, valid);
endinterface    