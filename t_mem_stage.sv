`timescale 1ns / 1ps
`include "riscv_core.svh"

module t_mem_stage(
    input clk, reset,
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    miq_ifc.in i_miq [2],
    input [31:0] i_regs [4],
    wb_ifc.out o_wb [2]
    );
    
    
    //logic [31:0] mem [1024];
    logic forward;
    
    logic [`ADDR_WIDTH-1:0] addr [2];
    assign addr[0] = i_regs[0] + i_miq[0].imm;
    assign addr[1] = i_regs[2] + i_miq[1].imm;
    
    logic [9:0] addr2 [2];
    assign addr2[0] = addr[0][9:0];
    assign addr2[1] = addr[1][9:0];    
    
    always_ff @(posedge clk) begin
        if(reset) begin
            forward <= 0;
            o_wb[0].valid <= 0;
            o_wb[1].valid <= 0;
        end else if(i_miq[0].valid && i_miq[1].valid && (i_miq[0].mem_access_type == WRITE) && (i_miq[1].mem_access_type == READ) && (addr[0] == addr[1])) begin
            o_wb[0].valid <= 1;
            o_wb[1].valid <= 1;
            //o_wb[0].data <= 0;
            //o_wb[1].data <= i_regs[1];
            o_wb[0].rd <= 0;
            o_wb[1].rd <= i_miq[1].rd;
            o_wb[0].uses_rd <= 0;
            o_wb[1].uses_rd <= 1;
            o_wb[0].al_idx <= i_miq[0].al_addr;
            o_wb[1].al_idx <= i_miq[1].al_addr;
            forward <= 1;
            
        end else begin
            if(i_miq[0].valid) begin
                o_wb[0].valid <= i_miq[0].valid; //~flush_mask[0];
                //o_wb[0].data <= (i_miq[0].mem_access_type == READ) ? mem[addr[0]] : 0;
                o_wb[0].rd <= (i_miq[0].mem_access_type == READ) ? i_miq[0].rd : 0;
                o_wb[0].al_idx <= i_miq[0].al_addr;
                o_wb[0].uses_rd <= (i_miq[0].mem_access_type == READ) ? 1 : 0;
                forward <= 0;
            end else begin
                o_wb[0].valid <= 0;
                forward <= 0;
            end
            
            if(i_miq[1].valid) begin
                o_wb[1].valid <= i_miq[1].valid; //~flush_mask[1];
                //o_wb[1].data <= (i_miq[1].mem_access_type == READ) ? mem[addr[1]] : 0;
                o_wb[1].rd <= (i_miq[1].mem_access_type == READ) ? i_miq[1].rd : 0;
                o_wb[1].al_idx <= i_miq[1].al_addr;
                o_wb[1].uses_rd <= (i_miq[1].mem_access_type == READ) ? 1 : 0;
                forward <= 0;
            end else begin
                o_wb[1].valid <= 0;
                forward <= 0;
            end
        end
        
        if(i_miq[0].valid && (i_miq[0].mem_access_type == WRITE)) begin
            //mem[addr[0]] <= i_regs[1];
            forward <= 0;
        end
        if(i_miq[1].valid && (i_miq[1].mem_access_type == WRITE)) begin
            //mem[addr[1]] <= i_regs[3];
            forward <= 0;
        end
    end
    
    logic [31:0] dout [2];
    
    assign o_wb[0].data = dout[0];
    assign o_wb[1].data = forward ? dout[0] : dout[1];
    
    logic we [2];
    assign we[0] = i_miq[0].valid && (i_miq[0].mem_access_type == WRITE);
    assign we[1] = i_miq[1].valid && (i_miq[1].mem_access_type == WRITE);
    
    logic [31:0] din [2];
    assign din[0] = i_regs[1];
    assign din[1] = i_regs[3];
    
    bram_block #(.DEPTH(1024)) MEM(
        .clk,
        .addr(addr2),
        .we(we),
        .din(din),
        .dout
    );
endmodule
