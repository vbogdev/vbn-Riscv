`timescale 1ns / 1ps
`include "riscv_core.svh"

/*
Register file runs on a 300 MHz clock
For each 100 MHz clock cycle, the reg file will do 3 data accesses
The first 2 will be 2 writes each (4 total)
The last will be 8 reads, directly outputted
*/
module fast_reg_file(
    input clk, f_clk, reset, ext_stall,
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    wb_ifc.in i_wb [4],
    aiq_ifc.in i_aiq [2],
    miq_ifc.in i_miq [2],
    output logic [31:0] o_regs [8],
    aiq_ifc.out_rf o_aiq [2],
    miq_ifc.out_rf o_miq [2],
    output logic int_stall
    );
    
    assign int_stall = ext_stall;
    
    
    logic [3:0] flush_mask, valid_mask;
    logic [$clog2(`AL_SIZE)-1:0] al_addrs [4];
    logic [$clog2(`NUM_PR)-1:0] read_addr [8];
    
    logic [$clog2(`NUM_PR)-1:0] read_local_reg [8];
    
    undo_checkpoint_module #(.DEPTH(4)) UCM(
        .new_front, .old_front, .back,
        .list(al_addrs),
        .i_valid(valid_mask),
        .flush_mask
    );
    
    
    logic [$clog2(`NUM_PR)-1:0] addr [4][2];
    logic we [4][2];
    logic [31:0] din [4][2];
    logic [31:0] dout [4][2];
    
    logic [1:0] state;


    genvar i;
    generate

    
        for(i = 0; i < 2; i++) begin
            assign valid_mask[i] = i_aiq[i].valid;
            assign valid_mask[i+2] = i_miq[i].valid;
            assign al_addrs[i] = i_aiq[i].al_addr;
            assign al_addrs[i+2] = 0;
            assign read_addr[2*i] = i_aiq[i].rs1;
            assign read_addr[2*i+1] = i_aiq[i].rs2;
            assign read_addr[2*i+4] = i_miq[i].rs1;
            assign read_addr[2*i+5] = i_miq[i].rs2;
        end
        
        for(i = 0; i < 4; i++) begin : gen_banks
             bram_block #(.WIDTH(32), .DEPTH(`NUM_PR)) BRAM_BLOCK(
                .clk(f_clk),
                .addr(addr[i]),
                .we(we[i]),
                .din(din[i]),
                .dout(dout[i])
            );
        end
    
        for(i = 0; i < 4; i++) begin
            always_comb begin
                if(state == 0) begin
                    we[i][0] = i_wb[0].uses_rd && i_wb[0].valid;
                    we[i][1] = i_wb[1].uses_rd && i_wb[1].valid;
                    addr[i][0] = i_wb[0].rd;
                    addr[i][1] = i_wb[1].rd;
                    din[i][0] = i_wb[0].data;
                    din[i][1] = i_wb[1].data;
                end else if(state == 1) begin
                    we[i][0] = i_wb[2].uses_rd && i_wb[2].valid;
                    we[i][1] = i_wb[3].uses_rd && i_wb[3].valid;
                    addr[i][0] = i_wb[2].rd;
                    addr[i][1] = i_wb[3].rd;
                    din[i][0] = i_wb[2].data;
                    din[i][1] = i_wb[3].data;
                end else begin
                    we[i][0] = 0;
                    we[i][1] = 0;
                    addr[i][0] = read_local_reg[2*i];
                    addr[i][1] = read_local_reg[2*i+1];
                    din[i][0] = 0;
                    din[i][1] = 0;
                end
            end
        
            
            //from clk to 2nd posedge of f_clk, giving 6.666ns for read addresses to be recieved from iq
            always_ff @(posedge f_clk) begin
                if(state == 1) begin
                    read_local_reg[2*i] <= read_addr[2*i];
                    read_local_reg[2*i+1] <= read_addr[2*i+1];
                end
            end
            
            always_ff @(posedge clk) begin
                o_regs[2*i] <= dout[i][0];
                o_regs[2*i+1] <= dout[i][1];
                
            end
        end
        
    endgenerate
    
    task update_reg(input [$clog2(`NUM_PR)-1:0] addr, input [31:0] val);
        top_tb.DUT.FRF.gen_banks[0].BRAM_BLOCK.mem[addr] = val;
        top_tb.DUT.FRF.gen_banks[1].BRAM_BLOCK.mem[addr] = val;
        top_tb.DUT.FRF.gen_banks[2].BRAM_BLOCK.mem[addr] = val;
        top_tb.DUT.FRF.gen_banks[3].BRAM_BLOCK.mem[addr] = val;
    endtask
    
    
    logic startup;
    always_ff @(posedge f_clk) begin
        if(reset && startup) begin
            state <= 0;
            startup <= 0;
        end else begin
            if(state == 0) begin
                state <= 1;
            end else if(state == 1) begin
                state <= 2;
            end else begin
                state <= 0;
            end
        end
    end
    
    generate
        for(i = 0; i < 2; i++) begin
            always_ff @(posedge clk) begin
                if(reset) begin
                    o_aiq[i].valid <= 0;
                    o_miq[i].valid <= 0;
                end else if(~ext_stall) begin
                    o_aiq[i].valid <= i_aiq[i].valid && ((~flush_mask[i] && if_recall) || ~if_recall);
                    o_aiq[i].pc <= i_aiq[i].pc;
                    o_aiq[i].rd <= i_aiq[i].rd;
                    o_aiq[i].uses_rd <= i_aiq[i].uses_rd;
                    o_aiq[i].imm <= i_aiq[i].imm;
                    o_aiq[i].uses_imm <= i_aiq[i].uses_imm;
                    o_aiq[i].alu_operation <= i_aiq[i].alu_operation;
                    o_aiq[i].al_addr <= i_aiq[i].al_addr;
                    o_aiq[i].target <= i_aiq[i].target;
                    o_aiq[i].is_branch <= i_aiq[i].is_branch;
                    o_aiq[i].is_jump <= i_aiq[i].is_jump;
                    o_aiq[i].is_jump_register <= i_aiq[i].is_jump_register;
                    o_aiq[i].branch_op <= i_aiq[i].branch_op;
                    o_aiq[i].prediction <= i_aiq[i].prediction;
                    o_aiq[i].cp_addr <= i_aiq[i].cp_addr;
                    
                    o_miq[i].valid <= i_miq[i].valid; // && ~flush_mask[i];
                    o_miq[i].pc <= i_miq[i].pc;
                    o_miq[i].rd <= i_miq[i].rd;
                    o_miq[i].uses_rd <= i_miq[i].uses_rd;
                    o_miq[i].uses_imm <= i_miq[i].uses_imm;
                    o_miq[i].imm <= i_miq[i].imm;
                    o_miq[i].is_mem_access <= i_miq[i].is_mem_access;
                    o_miq[i].mem_access_type <= i_miq[i].mem_access_type;
                    o_miq[i].width <= i_miq[i].width;
                    o_miq[i].al_addr <= i_miq[i].al_addr;
                end
            end
        end
    endgenerate
    
    

endmodule
