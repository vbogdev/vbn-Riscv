`timescale 1ns / 1ps
`include "riscv_core.svh"
module issue_stage(
    input clk, reset,
    input ext_stall,
    //incoming instr
    rename_out_ifc.in_aiq i_ren_aiq [2],
    rename_out_ifc.in_ioiq i_ren_ioiq [2],
    //wb
    wb_ifc.in i_wb [4],
    //recall
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    input [$clog2(`AL_SIZE)-1:0] oldest_branch_al_addr,
    input no_checkpoints,
    //free list
    aiq_ifc.out o_iq [2],
    //ziq_ifc.out o_ziq [2],
    miq_ifc.out o_miq [2],
    output int_stall
    );
    
    logic aiq_stall;
    banked_aiq AIQ(
        .clk, .reset,
        .ext_stall,
        .i_ren(i_ren_aiq),
        .if_recall,
        .new_front,
        .old_front,
        .back,
        .i_wb,
        .o_iq,
        .int_stall(aiq_stall)
    );
    
    logic ioiq_stall;
    inorder_issue_queue IOIQ(
        .clk, .reset,
        .ext_stall,
        .i_ren(i_ren_ioiq),
        .i_wb,
        .if_recall,
        .new_front,
        .old_front,
        .back,
        .oldest_branch_al_addr,
        .no_branches(no_checkpoints),
        .o_miq,
        .int_stall(ioiq_stall)
    );
    
    assign int_stall = ioiq_stall || aiq_stall || ext_stall;
    
endmodule
