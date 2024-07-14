`timescale 1ns / 1ps
`include "riscv_core.svh"

module arith_ex_stage(
    input clk, 
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    aiq_ifc.in i_aiq [2],
    reg_out_ifc.in i_regs [2],
    wb_ifc.out o_wb [2],
    branch_fb_ifc.out o_fb [2]
    );
    
    logic [31:0] rs1 [2];
    logic [31:0] rs2 [2];
    
    wb_ifc intermediate_wb[2]();
    
    assign rs1[0] = i_regs[0].rs1_val;
    assign rs1[1] = i_regs[1].rs1_val;
    assign rs2[0] = i_aiq[0].uses_imm ? i_aiq[0].imm : i_regs[0].rs2_val;
    assign rs2[1] = i_aiq[1].uses_imm ? i_aiq[1].imm : i_regs[1].rs2_val;
    
    genvar i;
    generate
        for(i = 0; i < 2; i++) begin
            always_comb begin
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
                
                o_fb[i].if_branch = 0;
                o_fb[i].if_prediction_correct = 1;
                o_fb[i].outcome = NOT_TAKEN;
            end
            
            
            always_ff @(posedge clk) begin
                o_wb[i].valid <= i_aiq[i].valid;
                o_wb[i].al_idx <= i_aiq[i].al_addr;
                o_wb[i].data <= intermediate_wb[i].data;
                o_wb[i].rd <= i_aiq[i].rd;
                o_wb[i].uses_rd <= i_aiq[i].uses_rd;
            end
        end
        
    endgenerate
    
    
endmodule
