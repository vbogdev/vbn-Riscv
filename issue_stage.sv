`timescale 1ns / 1ps
`include "riscv_core.svh"
module issue_stage(
    input clk, reset,
    input ext_stall,
    //incoming instr
    rename_out_ifc.in i_ren [2],
    //recall
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    //free list
    input [63:0] bbt,
    aiq_ifc.out o_iq [`NUM_ARITH_CORE],
    //ziq_ifc.out o_ziq,
    //miq_ifc.out o_miq,
    output int_stall
    );
    
    arithmetic_iq AIQ(
        .*
    );
endmodule
