`timescale 1ns / 1ps
`include "riscv_core.svh"

module decode_stage(
    fetch_out_ifc.in i_fetch [2],
    input clk, reset, ext_stall, ext_flush,
    decode_out_ifc.out o_decode [2],
    branch_fb_decode_ifc.out o_fb
    );
    
    
    decode_out_ifc pipeline_regs[2]();
    logic branch_inconsistency [2];
    logic [`ADDR_WIDTH-1:0] new_pc [2];
    
    decoder dec1(
        .valid(i_fetch[0].valid),
        .i_instr(i_fetch[0].instr),
        .i_pc(i_fetch[0].pc),
        .guesses_branch(i_fetch[0].guesses_branch),
        .prediction(i_fetch[0].prediction),
        .o_dec(pipeline_regs[0]),
        .o_branch_inconsistency(branch_inconsistency[0]),
        .o_new_pc(new_pc[0])
    );
    decoder dec2(
        .valid(i_fetch[1].valid),
        .i_instr(i_fetch[1].instr),
        .i_pc(i_fetch[1].pc),
        .guesses_branch(i_fetch[1].guesses_branch),
        .prediction(i_fetch[1].prediction),
        .o_dec(pipeline_regs[1]),
        .o_branch_inconsistency(branch_inconsistency[1]),
        .o_new_pc(new_pc[1])
    );
    
    always_comb begin
        o_fb.if_branch = 0;
        o_fb.if_prediction_correct = 1;
        o_fb.new_pc = 0;        
        if(branch_inconsistency[0]) begin
            o_fb.if_branch = 1;
            o_fb.if_prediction_correct = 0;
            o_fb.new_pc = new_pc[0];
        end else if(branch_inconsistency[1]) begin
            o_fb.if_branch = 1;
            o_fb.if_prediction_correct = 0;
            o_fb.new_pc = new_pc[1];
        end
    end
    
    genvar i;
    generate
        for(i = 0; i < 2; i++) begin
            always_ff @(posedge clk) begin
                if(reset || ext_flush) begin
                    o_decode[i].pc <= 0;
                    o_decode[i].valid <= 0;
                    o_decode[i].uses_rd <= 0;
                    o_decode[i].rd <= 0;
                    o_decode[i].uses_rs1 <= 0;
                    o_decode[i].rs1 <= 0;
                    o_decode[i].uses_rs2 <= 0;
                    o_decode[i].rs2 <= 0;
                    o_decode[i].uses_imm <= 0;
                    o_decode[i].imm <= 0;
                    o_decode[i].alu_operation <= ALUCTL_ADD;
                    o_decode[i].is_fp <= 0;
                    o_decode[i].target <= 0;
                    o_decode[i].is_branch <= 0;
                    o_decode[i].is_jump <= 0;
                    o_decode[i].is_jump_register <= 0;
                    o_decode[i].branch_op <= BEQ;
                    o_decode[i].prediction <= TAKEN;
                    o_decode[i].mem_access_type <= READ;
                    o_decode[i].is_mem_access <= 0;
                    o_decode[i].width <= M_B;
                    o_decode[i].accesses_csr <= 0;
                    o_decode[i].csr_op <= CSRRW;
                    o_decode[i].csr_addr <= 0;
                    o_decode[i].ecall <= 0;
                    o_decode[i].ebreak <= 0;
                    o_decode[i].amo_instr <= 0;
                    o_decode[i].aq <= 0;
                    o_decode[i].rl <= 0;
                    o_decode[i].amo_type <= AMO_LR;
                end else if(~ext_stall) begin
                    o_decode[i].valid <= pipeline_regs[i].valid;
                    o_decode[i].pc <= pipeline_regs[i].pc;
                    o_decode[i].uses_rd <= pipeline_regs[i].uses_rd;
                    o_decode[i].rd <= pipeline_regs[i].rd;
                    o_decode[i].uses_rs1 <= pipeline_regs[i].uses_rs1;
                    o_decode[i].rs1 <= pipeline_regs[i].rs1;
                    o_decode[i].uses_rs2 <= pipeline_regs[i].uses_rs2;
                    o_decode[i].rs2 <= pipeline_regs[i].rs2;
                    o_decode[i].uses_imm <= pipeline_regs[i].uses_imm;
                    o_decode[i].imm <= pipeline_regs[i].imm;
                    o_decode[i].alu_operation <= pipeline_regs[i].alu_operation;
                    o_decode[i].is_fp <= pipeline_regs[i].is_fp;
                    o_decode[i].target <= pipeline_regs[i].target;
                    o_decode[i].is_branch <= pipeline_regs[i].is_branch;
                    o_decode[i].is_jump <= pipeline_regs[i].is_jump;
                    o_decode[i].is_jump_register <= pipeline_regs[i].is_jump_register;
                    o_decode[i].branch_op <= pipeline_regs[i].branch_op;
                    o_decode[i].prediction <= pipeline_regs[i].prediction;
                    o_decode[i].mem_access_type <= pipeline_regs[i].mem_access_type;
                    o_decode[i].is_mem_access <= pipeline_regs[i].is_mem_access;
                    o_decode[i].width <= pipeline_regs[i].width;
                    o_decode[i].accesses_csr <= pipeline_regs[i].accesses_csr;
                    o_decode[i].csr_op <= pipeline_regs[i].csr_op;
                    o_decode[i].csr_addr <= pipeline_regs[i].csr_addr;
                    o_decode[i].ecall <= pipeline_regs[i].ecall;
                    o_decode[i].ebreak <= pipeline_regs[i].ebreak;
                    o_decode[i].amo_instr <= pipeline_regs[i].amo_instr;
                    o_decode[i].aq <= pipeline_regs[i].aq;
                    o_decode[i].rl <= pipeline_regs[i].rl;
                    o_decode[i].amo_type <= pipeline_regs[i].amo_type;
                end
            end
        end
    endgenerate
    
    
endmodule
