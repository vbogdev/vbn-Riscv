`timescale 1ns / 1ps
`include "riscv_core.svh"
module reg_read_stage(
    input clk, reset,
    input ext_stall,
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    aiq_ifc.in i_arith [2],
    wb_ifc.in i_wb [2],
    aiq_ifc.out o_arith [2],
    reg_out_ifc.out o_regs [2]
    );
    
    logic [$clog2(`AL_SIZE)-1:0] al_addrs [2];
    assign al_addrs[0] = i_arith[0].al_addr;
    assign al_addrs[1] = i_arith[1].al_addr;
    logic valid [2];
    assign valid[0] = i_arith[0].valid;
    assign valid[1] = i_arith[1].valid;
    
    logic flush_mask [2];
    
    undo_checkpoint_module #(
        .DEPTH(2)
        )UDM(
        .new_front,
        .old_front,
        .back,
        .list(al_addrs),
        .i_valid(valid),
        .flush_mask(flush_mask)
    );
    
    
    (* ram_style = "registers" *) logic [31:0] registers [64];
    
 
    always_ff @(posedge clk) begin
        if(i_wb[0].uses_rd && i_wb[1].uses_rd && i_wb[0].valid && i_wb[1].valid && (i_wb[0].rd == i_wb[1].rd)) begin
            registers[i_wb[1].rd] <= i_wb[1].data;
        end else begin
            if(i_wb[0].uses_rd && i_wb[0].valid) begin
                registers[i_wb[0].rd] <= i_wb[0].data;    
            end
            if(i_wb[1].uses_rd && i_wb[1].valid) begin
                registers[i_wb[1].rd] <= i_wb[1].data;    
            end
        end
    end
 
    genvar i;
    generate
        for(i = 0; i < 2; i++) begin
            assign o_regs[i].rs1_val = registers[i_arith[i].rs1];
            assign o_regs[i].rs2_val = registers[i_arith[i].rs2];
        end
        
        for(i = 0; i < 2; i++) begin
            always_ff @(posedge clk) begin
                if(flush_mask[i]) begin
                    o_arith[i].valid <= 0;
                end else if(~ext_stall) begin
                    o_arith[i].valid <= i_arith[i].valid;
                    o_arith[i].rs1 <= i_arith[i].rs1;
                    o_arith[i].rs2 <= i_arith[i].rs2;
                    o_arith[i].rd <= i_arith[i].rd;
                    o_arith[i].uses_rs1 <= i_arith[i].uses_rs1;
                    o_arith[i].uses_rs2<= i_arith[i].uses_rs2;
                    o_arith[i].uses_rd <= i_arith[i].uses_rd;
                    o_arith[i].uses_imm <= i_arith[i].uses_imm;
                    o_arith[i].imm <= i_arith[i].imm;
                    o_arith[i].alu_operation <= i_arith[i].alu_operation;
                    o_arith[i].al_addr <= i_arith[i].al_addr;
                    o_arith[i].target = i_arith[i].target;
                    o_arith[i].is_branch = i_arith[i].is_branch;
                    o_arith[i].is_jump = i_arith[i].is_jump;
                    o_arith[i].is_jump_register = i_arith[i].is_jump_register;
                    o_arith[i].branch_op = i_arith[i].branch_op;
                    o_arith[i].prediction = i_arith[i].prediction;
                    o_arith[i].cp_addr = i_arith[i].cp_addr;
                end
            end
        end
    endgenerate
    
    
endmodule
