`timescale 1ns / 1ps
`include "riscv_core.svh"

module banked_aiq(
    input clk, reset,
    input ext_stall,
    //incoming instr
    rename_out_ifc.in_aiq i_ren [2],
    //recall
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    //free list
    wb_ifc.in i_wb [4],
    //wb_ifc.wb i_wb [`NUM_INSTRS_COMPLETED],
    //outputs
    aiq_ifc.out o_iq [2],
    output int_stall
    );
    
    logic stalls [2];
    
    aiq_bank BANK_0(
        .clk, .reset, .ext_stall,
        .i_ren(i_ren[0]),
        .if_recall,
        .new_front, .old_front, .back,
        .i_wb,
        .o_iq(o_iq[0]),
        .int_stall(stalls[0])
    );
    
    aiq_bank BANK_1(
        .clk, .reset, .ext_stall,
        .i_ren(i_ren[1]),
        .if_recall,
        .new_front, .old_front, .back,
        .i_wb,
        .o_iq(o_iq[1]),
        .int_stall(stalls[1])
    );
    
    assign int_stall = stalls[0] || stalls[1];
endmodule
