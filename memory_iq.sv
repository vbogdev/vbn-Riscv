`timescale 1ns / 1ps


module memory_iq(
    input clk, reset,
    input ext_flush, ext_stall,
    //incoming instr
    rename_out_ifc.in i_ren [2],
    //recall
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    //free list
    input [63:0] bbt
    );
endmodule
