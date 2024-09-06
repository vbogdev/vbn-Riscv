`timescale 1ns / 1ps
`include "riscv_core.svh"

module t_mem_stage(
    input clk, 
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    miq_ifc.in i_miq [2],
    input [31:0] i_regs [4],
    wb_ifc.out o_wb [2]
    );
    
    logic [1:0] valid_mask, flush_mask;
    logic [$clog2(`AL_SIZE)-1:0] al_addrs [2];
    
    genvar i;
    generate
        for(i = 0; i < 2; i++) begin
            assign valid_mask[i] = i_miq[i].valid;
            assign al_addrs[i] = i_miq[i].al_addr;
        end
    endgenerate
    
    undo_checkpoint_module #(.DEPTH(2)) UCM(
        .new_front, .old_front, .back,
        .list(al_addrs),
        .i_valid(valid_mask),
        .flush_mask
    );
    
    
    logic [31:0] mem [1024];
    
    logic [`ADDR_WIDTH-1:0] addr [2];
    assign addr[0] = i_regs[0] + i_miq[0].imm;
    assign addr[1] = i_regs[2] + i_miq[1].imm;    
    
    always_ff @(posedge clk) begin
        if(i_miq[0].valid && i_miq[1].valid && (i_miq[0].mem_access_type == WRITE) && (i_miq[1].mem_access_type == READ) && (addr[0] == addr[1])) begin
            o_wb[0].valid <= 0;
            o_wb[1].valid <= 1;
            o_wb[0].data <= 0;
            o_wb[1].data <= i_miq[0].rs1;
            o_wb[0].rd <= 0;
            o_wb[1].rd <= i_miq[1].rd;
            o_wb[0].uses_rd <= 0;
            o_wb[1].uses_rd <= 1;
            o_wb[0].al_idx <= i_miq[0].al_addr;
            o_wb[1].al_idx <= i_miq[1].al_addr;
            
        end else begin
            if(i_miq[0].valid) begin
                o_wb[0].valid <= ~flush_mask[0];
                o_wb[0].data <= (i_miq[0].mem_access_type == READ) ? mem[addr[0]] : 0;
                o_wb[0].rd <= (i_miq[0].mem_access_type == READ) ? i_miq[0].rd : 0;
                o_wb[0].al_idx <= i_miq[0].al_addr;
                o_wb[0].uses_rd <= (i_miq[0].mem_access_type == READ) ? 1 : 0;
            end else begin
                o_wb[0].valid <= 0;
            end
            
            if(i_miq[1].valid) begin
                o_wb[1].valid <= ~flush_mask[1];
                o_wb[1].data <= (i_miq[1].mem_access_type == READ) ? mem[addr[1]] : 0;
                o_wb[1].rd <= (i_miq[1].mem_access_type == READ) ? i_miq[1].rd : 0;
                o_wb[1].al_idx <= i_miq[1].al_addr;
                o_wb[1].uses_rd <= (i_miq[1].mem_access_type == READ) ? 1 : 0;
            end else begin
                o_wb[1].valid <= 0;
            end
        end
        
        if(i_miq[0].valid && (i_miq[0].mem_access_type == WRITE) && ~flush_mask[0]) begin
            mem[addr[0]] <= i_regs[1];
        end
        if(i_miq[1].valid && (i_miq[1].mem_access_type == WRITE) && ~flush_mask[1]) begin
            mem[addr[1]] <= i_regs[3];
        end
    end
endmodule
