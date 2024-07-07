`timescale 1ns / 1ps
`include "riscv_core.svh"
module decoder(
    input [31:0] i_instr,
    input guesses_branch,
    input [`ADDR_WIDTH-1:0] prediction,
    input [`ADDR_WIDTH-1:0] i_pc,
    decode_out_ifc.out o_dec,
    output logic o_branch_inconsistency,
    output logic [`ADDR_WIDTH-1:0] o_new_pc
    );
    
    
    logic [6:0] funct7, opcode;
    logic [31:0] imm;
    logic [4:0] rd, rs1, rs2;
    logic [2:0] funct3;
    
    logic uses_csr;
    logic [11:0] csr_addr;

    assign opcode = i_instr[6:0];
    assign funct3 = i_instr[14:12];
    assign funct7 = i_instr[31:25];

    task r_type(input [31:0] instr);
        o_dec.valid = 1;
        o_dec.rs2 = instr[24:20];
        o_dec.rs1 = instr[19:15];
        o_dec.rd = instr[11:7];
    endtask 
    
    task i_type(input [31:0] instr);
        o_dec.valid = 1;
        o_dec.imm = {{20{instr[31]}}, instr[31:20]};
        o_dec.rs1 = instr[19:15];
        o_dec.rd = instr[11:7];
    endtask
    
    task s_type(input [31:0] instr);
        o_dec.valid = 1;
        o_dec.imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        o_dec.rs2 = instr[24:20];
        o_dec.rs1 = instr[19:15];
    endtask
    
    task b_type(input [31:0] instr);
        o_dec.valid = 1;
        o_dec.imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        o_dec.rs2 = instr[24:20];
        o_dec.rs1 = instr[19:15];
    endtask
    
    task u_type(input [31:0] instr);
        o_dec.valid = 1;
        o_dec.imm = {instr[31:12], {20{1'b0}}};
        o_dec.rd = instr[11:7];
    endtask
    
    task j_type(input [31:0] instr);
        o_dec.valid = 1;
        o_dec.rd = instr[11:7];
        o_dec.imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    endtask
    
    task arithmetic_i_type(input [2:0] funct3);
        case(funct3) 
            3'b000: o_dec.alu_operation = ALUCTL_ADD;
            3'b001: o_dec.alu_operation = ALUCTL_SLL;
            3'b010: o_dec.alu_operation = ALUCTL_SLT;
            3'b011: o_dec.alu_operation = ALUCTL_SLTU;
            3'b100: o_dec.alu_operation = ALUCTL_XOR;
            3'b101: begin
                if(i_instr[31:25] == 7'b0000000) begin
                    o_dec.alu_operation = ALUCTL_SRL;
                end else begin
                    o_dec.alu_operation = ALUCTL_SRA;
                end
            end
            3'b110: o_dec.alu_operation = ALUCTL_OR;
            3'b111: o_dec.alu_operation = ALUCTL_AND;
        endcase
    endtask
    
    task arithmetic_r_type(input [6:0] funct7, input [2:0] funct3);
        if(funct7 == f7_standard) begin
            case(funct3)
                3'b000: o_dec.alu_operation = ALUCTL_ADD;
                3'b001: o_dec.alu_operation = ALUCTL_SLL;
                3'b010: o_dec.alu_operation = ALUCTL_SLT;
                3'b011: o_dec.alu_operation = ALUCTL_SLTU;
                3'b100: o_dec.alu_operation = ALUCTL_XOR;
                3'b101: o_dec.alu_operation = ALUCTL_SRL;
                3'b110: o_dec.alu_operation = ALUCTL_OR;
                3'b111: o_dec.alu_operation = ALUCTL_AND;
            endcase
        end else if(funct7 == f7_inverted) begin
            case(funct3) 
                3'b000: o_dec.alu_operation = ALUCTL_SUB;
                3'b101: o_dec.alu_operation = ALUCTL_SRA;
                default: o_dec.alu_operation = ALUCTL_ADD;
            endcase
        end else if(funct7 == f7_multiply) begin
            case(funct3) 
                3'b000: o_dec.alu_operation = ALUCTL_MUL;
                3'b001: o_dec.alu_operation = ALUCTL_MULH;
                3'b010: o_dec.alu_operation = ALUCTL_MULHSU;
                3'b011: o_dec.alu_operation = ALUCTL_MULHU;
                3'b100: o_dec.alu_operation = ALUCTL_DIV;
                3'b101: o_dec.alu_operation = ALUCTL_DIVU;
                3'b110: o_dec.alu_operation = ALUCTL_REM;
                3'b111: o_dec.alu_operation = ALUCTL_REMU;
            endcase
        end
    endtask
    
    task memory_type(input [2:0] funct3, input [6:0] opcode);
        if(opcode == 7'b0100011) begin
            case(funct3)
                3'b000: o_dec.width = M_B;
                3'b001: o_dec.width = M_H;
                3'b010: o_dec.width = M_W;
                3'b011: o_dec.width = M_D;
                default: o_dec.width = M_B;
            endcase
        end else begin
            case(funct3) 
                3'b000: o_dec.width = M_B;
                3'b001: o_dec.width = M_H;
                3'b010: o_dec.width = M_W;
                3'b011: o_dec.width = M_D;
                3'b100: o_dec.width = M_BU;
                3'b101: o_dec.width = M_HU;
                3'b110: o_dec.width = M_WU;
                3'b111: o_dec.width = M_DU;
            endcase
        end
    endtask
    
    task branch_type(input [2:0] funct3);
        if(funct3 == 3'b000) begin
            o_dec.branch_op = BEQ;
        end else if(funct3 == 3'b001) begin
            o_dec.branch_op = BNE;
        end else if(funct3 == 3'b100) begin
            o_dec.branch_op = BLT;
        end else if(funct3 == 3'b101) begin
            o_dec.branch_op = BGE;
        end else if(funct3 == 3'b110) begin
            o_dec.branch_op = BLTU;
        end else if(funct3 == 3'b111) begin
            o_dec.branch_op = BGEU;
        end else begin
            o_dec.branch_op = BEQ;
        end
    endtask
    
    task csr_type(input [2:0] funct3);
        if(funct3 == 3'b001) begin
            o_dec.csr_op = CSRRW;
            o_dec.uses_rs1 = 1;
        end else if(funct3 == 3'b010) begin
            o_dec.csr_op = CSRRS;
            o_dec.uses_rs1 = 1;
        end else if(funct3 == 3'b011) begin
            o_dec.csr_op = CSRRC;
            o_dec.uses_rs1 = 1;
        end else if(funct3 == 3'b101) begin
            o_dec.csr_op = CSRRWI;
            o_dec.uses_imm = 1;
            o_dec.imm = {{27{1'b0}}, i_instr[19:15]};
        end else if(funct3 == 3'b110) begin
            o_dec.csr_op = CSRRSI;
            o_dec.uses_imm = 1;
            o_dec.imm = {{27{1'b0}}, i_instr[19:15]};
        end else if(funct3 == 3'b111) begin
            o_dec.csr_op = CSRRCI;
            o_dec.uses_imm = 1;
            o_dec.imm = {{27{1'b0}}, i_instr[19:15]};
        end else begin
            
        end
    endtask
    
    task fp_type(input [6:0] funct7, input [2:0] funct3);
        o_dec.is_fp = 1;
        case(funct7[6:2]) 
            default: ;
        endcase
    endtask
    
    task amo_type(input [2:0] funct3);
        o_dec.amo_instr = 1;
        o_dec.aq = i_instr[26];
        o_dec.rl = i_instr[25];
        if(funct3 == 3'b010) begin
            o_dec.amo_type = AMO_LR;
            o_dec.uses_rd = 1;
            o_dec.uses_rs1 = 1;
            o_dec.width = M_W;
        end else if(funct3 == 3'b011) begin
            o_dec.amo_type = AMO_SC;
            o_dec.uses_rd = 1;
            o_dec.uses_rs1 = 1;
            o_dec.uses_rs2 = 1;
            o_dec.width = M_D;
        end
    endtask
    
    always_comb begin
        //default values for a NOP i guess
        o_dec.uses_rd = 0;
        o_dec.rd = 0;
        o_dec.uses_rs1 = 0;
        o_dec.rs1 = 0;
        o_dec.uses_rs2 = 0;
        o_dec.rs2 = 0;
        o_dec.uses_imm = 0;
        o_dec.imm = 0;
        o_dec.alu_operation = ALUCTL_ADD;
        o_dec.is_fp = 0;
        o_dec.target = 0;
        o_dec.is_branch = 0;
        o_dec.is_jump = 0;
        o_dec.is_jump_register = 0;
        o_dec.branch_op = BEQ;
        o_dec.prediction = 0;
        o_dec.is_mem_access = 0;
        o_dec.mem_access_type = READ;
        o_dec.width = M_B;
        o_dec.accesses_csr = 0;
        o_dec.csr_op = CSRRW;
        o_dec.csr_addr = 0;
        o_dec.ecall = 0;
        o_dec.ebreak = 0;
        o_dec.amo_instr = 0;
        o_dec.aq = 0;
        o_dec.rl = 0;
        o_dec.amo_type = AMO_LR;
        o_branch_inconsistency = ~guesses_branch;
        o_new_pc = i_pc + 'd4;
        o_dec.valid = 0;
        case(opcode)
            7'b0010011: begin //op imm
                i_type(.instr(i_instr));
                arithmetic_i_type(.funct3(funct3));
                o_dec.uses_rd = 1;
                o_dec.uses_rs1 = 1;
                o_dec.uses_imm = 1;
            end
            7'b0110111: begin //lui
                u_type(.instr(i_instr));
                o_dec.uses_rd = 1;
                o_dec.uses_rs1 = 1;
                o_dec.rs1 = 0;
                o_dec.uses_imm = 1;
            end
            7'b0010111: begin //auipc
                u_type(.instr(i_instr));
                o_dec.imm = {i_instr[31:12], {12{1'b0}}} + i_pc;
                o_dec.uses_imm = 1;
                o_dec.uses_rs1 = 1;
                o_dec.rs1 = 0;
            end
            7'b0110011: begin //op
                r_type(.instr(i_instr));
                arithmetic_r_type(.funct7(funct7), .funct3(funct3));
                o_dec.uses_rd = 1;
                o_dec.uses_rs1 = 1;
                o_dec.uses_rs2 = 1;
            end
            7'b1101111: begin //jal
                j_type(.instr(i_instr));
                o_dec.is_jump = 1;
                o_dec.target = i_pc + {{11{i_instr[31]}}, i_instr[31], i_instr[19:12], i_instr[20], i_instr[30:21], 1'b0};
                o_dec.imm = i_pc + 'd4;
                o_dec.uses_rd = 1;
                o_dec.uses_rs1 = 1;
                o_dec.rs1 = 0;
                o_dec.uses_imm = 1;
                o_branch_inconsistency = ~(guesses_branch && (o_dec.target == prediction));
                o_new_pc = o_dec.target;
            end
            7'b1100111: begin //jalr
                i_type(.instr(i_instr));
                o_dec.is_jump = 1;
                o_dec.is_jump_register = 1;
                o_dec.target = i_pc + 'd4;
                o_dec.uses_rd = 1;
                o_dec.uses_rs1 = 1;
                o_dec.uses_imm = 1;
                o_branch_inconsistency = 0;
            end
            7'b1100011: begin //branch
                b_type(.instr(i_instr));
                branch_type(.funct3(funct3));
                o_dec.target = o_dec.imm + i_pc;
                o_dec.uses_rs1 = 1;
                o_dec.uses_rs2 = 1;
                o_dec.is_branch = 1;
                o_dec.prediction = (prediction == i_pc + 'd4) ? TAKEN : NOT_TAKEN;
                o_branch_inconsistency = ~(guesses_branch && (o_dec.target == prediction));
                o_new_pc = o_dec.target;
            end
            7'b0000011: begin //load
                i_type(.instr(i_instr));
                memory_type(.funct3(funct3), .opcode(opcode));
                o_dec.uses_rs1 = 1;
                o_dec.uses_rd = 1;
                o_dec.uses_imm = 1;
                o_dec.is_mem_access = 1;
                o_dec.alu_operation = ALUCTL_ADD;
            end
            7'b0100011: begin //store
                s_type(.instr(i_instr));
                memory_type(.funct3(funct3), .opcode(opcode));
                o_dec.uses_rs1 = 1;
                o_dec.uses_rs2 = 1;
                o_dec.uses_imm = 1;
                o_dec.is_mem_access = 1;
                o_dec.mem_access_type = WRITE;
                o_dec.alu_operation = ALUCTL_ADD;
            end
            7'b0001111: begin //fence
                i_type(.instr(i_instr));
                //WIP
            end
            7'b1110011: begin //csr stuff and ecall/ebreak
                i_type(.instr(i_instr));
                if(funct3 == 3'b000) begin
                    if(i_instr[31:20] == 12'b000000000001) begin
                        o_dec.ebreak = 1;
                    end else if(i_instr[31:20] == 12'b000000000000) begin
                        o_dec.ecall = 1;
                    end
                end else begin
                    csr_type(.funct3(funct3));
                    o_dec.uses_rd = 1;
                end
            end
            7'b0101111: begin //AMO
                r_type(.instr(i_instr));
                amo_type(.funct3(funct3));
            end
            default: ;
        endcase
    end
    
endmodule
