`timescale 1ns / 1ps
`include "riscv_core.svh"

module arith_ex_stage(
    input clk, 
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    aiq_ifc.in i_aiq [2],
    input [31:0] i_regs [4],
    wb_ifc.out o_wb [2],
    branch_fb_ifc.out o_fb [2]
    );
    
    logic [31:0] rs1 [2];
    logic [31:0] rs2 [2];
    
    logic unsigned [31:0] rs1_u [2];
    logic unsigned [31:0] rs2_u [2];
    logic signed [31:0] rs1_s [2];
    logic signed [31:0] rs2_s [2];
    
    
    wb_ifc intermediate_wb[2]();
    
    assign rs1[0] = i_regs[0];
    assign rs1[1] = i_regs[2];
    assign rs2[0] = i_aiq[0].uses_imm ? i_aiq[0].imm : i_regs[1];
    assign rs2[1] = i_aiq[1].uses_imm ? i_aiq[1].imm : i_regs[3];
    
    
    branch_fb_ifc branches[2]();
    
    
    logic [$clog2(`AL_SIZE)-1:0] al_addrs [2];
    logic [1:0] valid_mask;
    assign al_addrs[0] = i_aiq[0].al_addr;
    assign al_addrs[1] = i_aiq[1].al_addr;
    assign valid_mask[0] = i_aiq[0].valid;
    assign valid_mask[1] = i_aiq[1].valid;
    
    logic [1:0] flush_mask;
    
    undo_checkpoint_module #(.DEPTH(2)) UCM (
        .new_front, .old_front, .back,
        .list(al_addrs),
        .i_valid(valid_mask),
        .flush_mask
    );
    
    genvar i;
    generate
        for(i = 0; i < 2; i++) begin
            always_comb begin
                rs1_u[i] = rs1[i];
                rs2_u[i] = rs2[i];
                rs1_s[i] = rs1[i];
                rs2_s[i] = rs2[i];
            
                case(i_aiq[i].alu_operation)
                    ALUCTL_ADD: intermediate_wb[i].data = rs1[i] + rs2[i];
                    ALUCTL_SUB: intermediate_wb[i].data = rs1[i] - rs2[i];
                    ALUCTL_AND: intermediate_wb[i].data = rs1[i] & rs2[i];   
                    ALUCTL_OR: intermediate_wb[i].data = rs1[i] | rs2[i];
                    ALUCTL_XOR: intermediate_wb[i].data = rs1[i] ^ rs2[i];   
                    ALUCTL_SLT: intermediate_wb[i].data = (rs1[i] > rs2[i]) ? 1 : 0;
                    ALUCTL_SLT: intermediate_wb[i].data = (rs1[i] > rs2[i]) ? 1 : 0;
                    ALUCTL_SLL: begin
                        if(i_aiq[i].uses_imm) begin
                            intermediate_wb[i].data = rs2[i] << rs1[i][4:0];
                        end else begin
                            intermediate_wb[i].data = rs2[i] << rs1[i];
                        end
                    end
                    ALUCTL_SRL: begin
                        if(i_aiq[i].uses_imm) begin
                            intermediate_wb[i].data = rs2[i] >> rs1[i][4:0];
                        end else begin
                            intermediate_wb[i].data = rs2[i] >> rs1[i];
                        end
                    end
                    ALUCTL_SRA: begin
                        if(i_aiq[i].uses_imm) begin
                            intermediate_wb[i].data = rs2[i] >>> rs1[i][4:0];
                        end else begin
                            intermediate_wb[i].data = rs2[i] >>> rs1[i];
                        end
                    end
                    ALUCTL_AUIPC: intermediate_wb[i].data = rs1[i] + rs2[i];
                    default: intermediate_wb[i].data = 0;
                endcase
                
               // branches[i].new_pc = (branches[i].outcome == TAKEN) ? i_aiq[i].
                case(i_aiq[i].branch_op) 
                    BEQ: branches[i].outcome = (rs1[i] == rs2[i]) ? TAKEN : NOT_TAKEN;
                    BNE: branches[i].outcome = (rs1[i] != rs2[i]) ? TAKEN : NOT_TAKEN;
                    BLT: branches[i].outcome = (rs1_s[i] < rs2_s[i]) ? TAKEN : NOT_TAKEN;
                    BGE: branches[i].outcome = (rs1_s[i] >= rs2_s[i]) ? TAKEN : NOT_TAKEN;
                    BLTU: branches[i].outcome = (rs1_u[i] < rs2_u[i]) ? TAKEN : NOT_TAKEN;
                    BGEU: branches[i].outcome = (rs1_u[i] >= rs2_u[i]) ? TAKEN : NOT_TAKEN;
                    default: branches[i].outcome = NOT_TAKEN;
                endcase
                branches[i].if_prediction_correct = i_aiq[i].is_jump_register ? 0 : (branches[i].outcome == i_aiq[i].prediction);
                branches[i].if_branch = i_aiq[i].is_branch;
                branches[i].cp_addr = i_aiq[i].cp_addr;
                branches[i].new_pc = i_aiq[i].is_jump_register ? (i_regs[0] + i_aiq[0].imm) : (i_aiq[i].pc + i_aiq[i].imm);
                branches[i].branch_pc = i_aiq[i].pc;
                branches[i].al_addr = i_aiq[i].al_addr;
            end
            
            
            always_ff @(posedge clk) begin
                o_wb[i].valid <= i_aiq[i].valid && ((~flush_mask[i] && if_recall) || ~if_recall);
                o_wb[i].al_idx <= i_aiq[i].al_addr;
                o_wb[i].data <= i_aiq[i].is_jump_register ? i_aiq[i].target : intermediate_wb[i].data;
                o_wb[i].rd <= i_aiq[i].rd;
                o_wb[i].uses_rd <= i_aiq[i].uses_rd;
            end
        end
        
    endgenerate
    
    
    //handle ordering branches so that oldest wrong branch is in o_fb[0]
    //this is because changing the pc and flushing instructions is done with o_fb[0]
    always_comb begin
        o_fb[0].if_branch = 0;
        o_fb[0].if_prediction_correct = branches[0].if_prediction_correct;
        o_fb[0].outcome = branches[0].outcome;
        o_fb[0].cp_addr = branches[0].cp_addr;
        o_fb[0].branch_pc = branches[0].branch_pc;
        o_fb[0].new_pc = branches[0].new_pc;
        o_fb[0].is_jr = 0;
        o_fb[1].if_branch = 0;
        o_fb[1].if_prediction_correct = branches[1].if_prediction_correct;
        o_fb[1].outcome = branches[1].outcome;
        o_fb[1].cp_addr = branches[1].cp_addr;
        o_fb[1].branch_pc = branches[1].branch_pc;
        o_fb[1].new_pc = branches[1].new_pc;
        o_fb[1].is_jr = 0;
            
        if(~branches[0].if_branch && ~branches[1].if_branch) begin
            o_fb[0].if_branch = branches[0].if_branch;
            o_fb[0].if_prediction_correct = branches[0].if_prediction_correct;
            o_fb[0].outcome = branches[0].outcome;
            o_fb[0].cp_addr = branches[0].cp_addr;
            o_fb[0].branch_pc = branches[0].branch_pc;
            o_fb[0].new_pc = branches[0].new_pc;
            o_fb[0].is_jr = i_aiq[0].is_jump_register;
            o_fb[0].al_addr = branches[0].al_addr;
            o_fb[1].if_branch = branches[1].if_branch;
            o_fb[1].if_prediction_correct = branches[1].if_prediction_correct;
            o_fb[1].outcome = branches[1].outcome;
            o_fb[1].cp_addr = branches[1].cp_addr;
            o_fb[1].branch_pc = branches[1].branch_pc;
            o_fb[1].new_pc = branches[1].new_pc;
            o_fb[1].is_jr = i_aiq[1].is_jump_register;
            o_fb[1].al_addr = branches[1].al_addr;
        end else if(branches[0].if_branch && ~branches[1].if_branch) begin
            o_fb[0].if_branch = branches[0].if_branch;
            o_fb[0].if_prediction_correct = branches[0].if_prediction_correct;
            o_fb[0].outcome = branches[0].outcome;
            o_fb[0].cp_addr = branches[0].cp_addr;
            o_fb[0].branch_pc = branches[0].branch_pc;
            o_fb[0].new_pc = branches[0].new_pc;
            o_fb[0].is_jr = i_aiq[0].is_jump_register;
            o_fb[0].al_addr = branches[0].al_addr;
            o_fb[1].if_branch = branches[1].if_branch;
            o_fb[1].if_prediction_correct = branches[1].if_prediction_correct;
            o_fb[1].outcome = branches[1].outcome;
            o_fb[1].cp_addr = branches[1].cp_addr;
            o_fb[1].branch_pc = branches[1].branch_pc;
            o_fb[1].new_pc = branches[1].new_pc;
            o_fb[1].is_jr = i_aiq[1].is_jump_register;
            o_fb[1].al_addr = branches[1].al_addr;
        end else if(branches[1].if_branch && ~branches[0].if_branch) begin
            o_fb[1].if_branch = branches[0].if_branch;
            o_fb[1].if_prediction_correct = branches[0].if_prediction_correct;
            o_fb[1].outcome = branches[0].outcome;
            o_fb[1].cp_addr = branches[0].cp_addr;
            o_fb[1].branch_pc = branches[0].branch_pc;
            o_fb[1].new_pc = branches[0].new_pc;
            o_fb[1].is_jr = i_aiq[0].is_jump_register;
            o_fb[1].al_addr = branches[0].al_addr;
            o_fb[0].if_branch = branches[1].if_branch;
            o_fb[0].if_prediction_correct = branches[1].if_prediction_correct;
            o_fb[0].outcome = branches[1].outcome;
            o_fb[0].cp_addr = branches[1].cp_addr;
            o_fb[0].branch_pc = branches[1].branch_pc;
            o_fb[0].new_pc = branches[1].new_pc;
            o_fb[0].is_jr = i_aiq[1].is_jump_register;
            o_fb[0].al_addr = branches[1].al_addr;
        end else if(~branches[0].if_prediction_correct && branches[1].if_prediction_correct && branches[0].if_branch && branches[1].if_branch) begin
            //places branches[0] in o_fb[0]
            o_fb[0].if_branch = branches[0].if_branch;
            o_fb[0].if_prediction_correct = branches[0].if_prediction_correct;
            o_fb[0].outcome = branches[0].outcome;
            o_fb[0].cp_addr = branches[0].cp_addr;
            o_fb[0].branch_pc = branches[0].branch_pc;
            o_fb[0].new_pc = branches[0].new_pc;
            o_fb[0].is_jr = i_aiq[0].is_jump_register;
            o_fb[0].al_addr = branches[0].al_addr;
            o_fb[1].if_branch = branches[1].if_branch;
            o_fb[1].if_prediction_correct = branches[1].if_prediction_correct;
            o_fb[1].outcome = branches[1].outcome;
            o_fb[1].cp_addr = branches[1].cp_addr;
            o_fb[1].branch_pc = branches[1].branch_pc;
            o_fb[1].new_pc = branches[1].new_pc;
            o_fb[1].is_jr = i_aiq[1].is_jump_register;
            o_fb[1].al_addr = branches[1].al_addr;
        end else if(~branches[1].if_prediction_correct && branches[0].if_prediction_correct && branches[0].if_branch && branches[1].if_branch) begin
            //places branches[1] in o_fb[0]
            o_fb[1].if_branch = branches[0].if_branch;
            o_fb[1].if_prediction_correct = branches[0].if_prediction_correct;
            o_fb[1].outcome = branches[0].outcome;
            o_fb[1].cp_addr = branches[0].cp_addr;
            o_fb[1].branch_pc = branches[0].branch_pc;
            o_fb[1].new_pc = branches[0].new_pc;
            o_fb[1].is_jr = i_aiq[0].is_jump_register;
            o_fb[1].al_addr = branches[0].al_addr;
            o_fb[0].if_branch = branches[1].if_branch;
            o_fb[0].if_prediction_correct = branches[1].if_prediction_correct;
            o_fb[0].outcome = branches[1].outcome;
            o_fb[0].cp_addr = branches[1].cp_addr;
            o_fb[0].branch_pc = branches[1].branch_pc;
            o_fb[0].new_pc = branches[1].new_pc;
            o_fb[0].is_jr = i_aiq[1].is_jump_register;
            o_fb[0].al_addr = branches[1].al_addr;
        end else if(branches[0].if_prediction_correct && branches[1].if_prediction_correct && branches[0].if_branch && branches[1].if_branch) begin
            //order doesnt matter as both dont need feedback
            o_fb[0].if_branch = branches[0].if_branch;
            o_fb[0].if_prediction_correct = branches[0].if_prediction_correct;
            o_fb[0].outcome = branches[0].outcome;
            o_fb[0].cp_addr = branches[0].cp_addr;
            o_fb[0].branch_pc = branches[0].branch_pc;
            o_fb[0].new_pc = branches[0].new_pc;
            o_fb[0].is_jr = i_aiq[0].is_jump_register;
            o_fb[0].al_addr = branches[0].al_addr;
            o_fb[1].if_branch = branches[1].if_branch;
            o_fb[1].if_prediction_correct = branches[1].if_prediction_correct;
            o_fb[1].outcome = branches[1].outcome;
            o_fb[1].cp_addr = branches[1].cp_addr;
            o_fb[1].branch_pc = branches[1].branch_pc;
            o_fb[1].new_pc = branches[1].new_pc;
            o_fb[1].is_jr = i_aiq[1].is_jump_register;
            o_fb[1].al_addr = branches[1].al_addr;
        end else begin
            //place older branch in o_fb[0]
            if(old_front > back) begin
                if(i_aiq[0].al_addr > i_aiq[1].al_addr) begin
                    //place branches[1] in o_fb[0]
                    o_fb[1].if_branch = branches[0].if_branch;
                    o_fb[1].if_prediction_correct = branches[0].if_prediction_correct;
                    o_fb[1].outcome = branches[0].outcome;
                    o_fb[1].cp_addr = branches[0].cp_addr;
                    o_fb[1].branch_pc = branches[0].branch_pc;
                    o_fb[1].new_pc = branches[0].new_pc;
                    o_fb[1].is_jr = i_aiq[0].is_jump_register;
                    o_fb[1].al_addr = branches[0].al_addr;
                    o_fb[0].if_branch = branches[1].if_branch;
                    o_fb[0].if_prediction_correct = branches[1].if_prediction_correct;
                    o_fb[0].outcome = branches[1].outcome;
                    o_fb[0].cp_addr = branches[1].cp_addr;
                    o_fb[0].branch_pc = branches[1].branch_pc;
                    o_fb[0].new_pc = branches[1].new_pc;
                    o_fb[0].is_jr = i_aiq[1].is_jump_register;
                    o_fb[0].al_addr = branches[1].al_addr;
                end else begin
                    //place branches[0] in o_fb[0]
                    o_fb[0].if_branch = branches[0].if_branch;
                    o_fb[0].if_prediction_correct = branches[0].if_prediction_correct;
                    o_fb[0].outcome = branches[0].outcome;
                    o_fb[0].cp_addr = branches[0].cp_addr;
                    o_fb[0].branch_pc = branches[0].branch_pc;
                    o_fb[0].new_pc = branches[0].new_pc;
                    o_fb[0].is_jr = i_aiq[0].is_jump_register;
                    o_fb[0].al_addr = branches[0].al_addr;
                    o_fb[1].if_branch = branches[1].if_branch;
                    o_fb[1].if_prediction_correct = branches[1].if_prediction_correct;
                    o_fb[1].outcome = branches[1].outcome;
                    o_fb[1].cp_addr = branches[1].cp_addr;
                    o_fb[1].branch_pc = branches[1].branch_pc;
                    o_fb[1].new_pc = branches[1].new_pc;
                    o_fb[1].is_jr = i_aiq[1].is_jump_register;
                    o_fb[1].al_addr = branches[1].al_addr;
                end
            end else begin
                // this one is a doozy
                if((i_aiq[0].al_addr > back) && (i_aiq[1].al_addr > back)) begin
                    if(i_aiq[0].al_addr > i_aiq[1].al_addr) begin
                        o_fb[1].if_branch = branches[0].if_branch;
                        o_fb[1].if_prediction_correct = branches[0].if_prediction_correct;
                        o_fb[1].outcome = branches[0].outcome;
                        o_fb[1].cp_addr = branches[0].cp_addr;
                        o_fb[1].branch_pc = branches[0].branch_pc;
                        o_fb[1].new_pc = branches[0].new_pc;
                        o_fb[1].is_jr = i_aiq[0].is_jump_register;
                        o_fb[1].al_addr = branches[0].al_addr;
                        o_fb[0].if_branch = branches[1].if_branch;
                        o_fb[0].if_prediction_correct = branches[1].if_prediction_correct;
                        o_fb[0].outcome = branches[1].outcome;
                        o_fb[0].cp_addr = branches[1].cp_addr;
                        o_fb[0].branch_pc = branches[1].branch_pc;
                        o_fb[0].new_pc = branches[1].new_pc;
                        o_fb[0].is_jr = i_aiq[1].is_jump_register;
                        o_fb[0].al_addr = branches[1].al_addr;
                    end else begin
                        o_fb[0].if_branch = branches[0].if_branch;
                        o_fb[0].if_prediction_correct = branches[0].if_prediction_correct;
                        o_fb[0].outcome = branches[0].outcome;
                        o_fb[0].cp_addr = branches[0].cp_addr;
                        o_fb[0].branch_pc = branches[0].branch_pc;
                        o_fb[0].new_pc = branches[0].new_pc;
                        o_fb[0].is_jr = i_aiq[0].is_jump_register;
                        o_fb[0].al_addr = branches[0].al_addr;
                        o_fb[1].if_branch = branches[1].if_branch;
                        o_fb[1].if_prediction_correct = branches[1].if_prediction_correct;
                        o_fb[1].outcome = branches[1].outcome;
                        o_fb[1].cp_addr = branches[1].cp_addr;
                        o_fb[1].branch_pc = branches[1].branch_pc;
                        o_fb[1].new_pc = branches[1].new_pc;
                        o_fb[1].is_jr = i_aiq[1].is_jump_register;
                        o_fb[1].al_addr = branches[1].al_addr;
                    end
                end else if((i_aiq[0].al_addr < back) && (i_aiq[1].al_addr > back)) begin
                    //place branches[1] in o_fb[0]
                    o_fb[1].if_branch = branches[0].if_branch;
                    o_fb[1].if_prediction_correct = branches[0].if_prediction_correct;
                    o_fb[1].outcome = branches[0].outcome;
                    o_fb[1].cp_addr = branches[0].cp_addr;
                    o_fb[1].branch_pc = branches[0].branch_pc;
                    o_fb[1].new_pc = branches[0].new_pc;
                    o_fb[1].is_jr = i_aiq[0].is_jump_register;
                    o_fb[1].al_addr = branches[0].al_addr;
                    o_fb[0].if_branch = branches[1].if_branch;
                    o_fb[0].if_prediction_correct = branches[1].if_prediction_correct;
                    o_fb[0].outcome = branches[1].outcome;
                    o_fb[0].cp_addr = branches[1].cp_addr;
                    o_fb[0].branch_pc = branches[1].branch_pc;
                    o_fb[0].new_pc = branches[1].new_pc;
                    o_fb[0].is_jr = i_aiq[1].is_jump_register;
                    o_fb[0].al_addr = branches[1].al_addr;
                end else if((i_aiq[0].al_addr > back) && (i_aiq[1].al_addr < back)) begin
                    //place branches[0] in o_fb[0]
                    o_fb[0].if_branch = branches[0].if_branch;
                    o_fb[0].if_prediction_correct = branches[0].if_prediction_correct;
                    o_fb[0].outcome = branches[0].outcome;
                    o_fb[0].cp_addr = branches[0].cp_addr;
                    o_fb[0].branch_pc = branches[0].branch_pc;
                    o_fb[0].new_pc = branches[0].new_pc;
                    o_fb[0].is_jr = i_aiq[0].is_jump_register;
                    o_fb[0].al_addr = branches[0].al_addr;
                    o_fb[1].if_branch = branches[1].if_branch;
                    o_fb[1].if_prediction_correct = branches[1].if_prediction_correct;
                    o_fb[1].outcome = branches[1].outcome;
                    o_fb[1].cp_addr = branches[1].cp_addr;
                    o_fb[1].branch_pc = branches[1].branch_pc;
                    o_fb[1].new_pc = branches[1].new_pc;
                    o_fb[1].is_jr = i_aiq[1].is_jump_register;
                    o_fb[1].al_addr = branches[1].al_addr;
                end else if((i_aiq[0].al_addr < old_front) && (i_aiq[1].al_addr < old_front)) begin
                    if(i_aiq[0].al_addr > i_aiq[1].al_addr) begin
                        o_fb[1].if_branch = branches[0].if_branch;
                        o_fb[1].if_prediction_correct = branches[0].if_prediction_correct;
                        o_fb[1].outcome = branches[0].outcome;
                        o_fb[1].cp_addr = branches[0].cp_addr;
                        o_fb[1].branch_pc = branches[0].branch_pc;
                        o_fb[1].new_pc = branches[0].new_pc;
                        o_fb[1].is_jr = i_aiq[0].is_jump_register;
                        o_fb[1].al_addr = branches[0].al_addr;
                        o_fb[0].if_branch = branches[1].if_branch;
                        o_fb[0].if_prediction_correct = branches[1].if_prediction_correct;
                        o_fb[0].outcome = branches[1].outcome;
                        o_fb[0].cp_addr = branches[1].cp_addr;
                        o_fb[0].branch_pc = branches[1].branch_pc;
                        o_fb[0].is_jr = i_aiq[1].is_jump_register;
                        o_fb[0].al_addr = branches[1].al_addr;
                    end else begin
                        o_fb[0].if_branch = branches[0].if_branch;
                        o_fb[0].if_prediction_correct = branches[0].if_prediction_correct;
                        o_fb[0].outcome = branches[0].outcome;
                        o_fb[0].cp_addr = branches[0].cp_addr;
                        o_fb[0].branch_pc = branches[0].branch_pc;
                        o_fb[0].new_pc = branches[0].new_pc;
                        o_fb[0].is_jr = i_aiq[0].is_jump_register;
                        o_fb[0].al_addr = branches[0].al_addr;
                        o_fb[1].if_branch = branches[1].if_branch;
                        o_fb[1].if_prediction_correct = branches[1].if_prediction_correct;
                        o_fb[1].outcome = branches[1].outcome;
                        o_fb[1].cp_addr = branches[1].cp_addr;
                        o_fb[1].branch_pc = branches[1].branch_pc;
                        o_fb[1].new_pc = branches[1].new_pc;
                        o_fb[1].is_jr = i_aiq[1].is_jump_register;
                        o_fb[1].al_addr = branches[1].al_addr;
                    end
                end 
            end
        end
        
    end
    
    
endmodule
