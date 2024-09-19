`timescale 1ns / 1ps
`include "riscv_core.svh"

module banked_in_order_iq(
    input clk, reset, 
    ext_stall,
    rename_out_ifc.in_ioiq i_ren [2],
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    input [$clog2(`AL_SIZE)-1:0] oldest_branch_al_addr,
    input no_checkpoints,
    //free list
    wb_ifc.in i_wb [4],
    //outputs
    miq_ifc.out o_miq [2],
    output int_stall 
    );
    
    in_order_iq bank_0(
        .clk, .reset, .ext_stall,
        .i_ren(i_ren[0]),
        .if_recall,
        .new_front,
        .old_front,
        .i_wb,
        .back,
        .oldest_branch_al_addr,
        .no_branches(no_checkpoints),
        .o_miq(o_miq[0]),
        .int_stall(int_stall_b0)
    );
    
    in_order_iq bank_1(
        .clk, .reset, .ext_stall,
        .i_ren(i_ren[1]),
        .if_recall,
        .new_front,
        .old_front,
        .i_wb,
        .back,
        .oldest_branch_al_addr,
        .no_branches(no_checkpoints),
        .o_miq(o_miq[1]),
        .int_stall(int_stall_b1)
    );
    
    assign int_stall = int_stall_b0 || int_stall_b1 || ext_stall;
endmodule
