`timescale 1ns / 1ps
`include "riscv_core.svh"

module undo_checkpoint_module #(
    parameter DEPTH=4
    )(
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    input [$clog2(`AL_SIZE)-1:0] list [DEPTH],
    input i_valid [DEPTH],
    output logic flush_mask [DEPTH]
    );  
    
    
    genvar i;
    generate
        for(i = 0; i < DEPTH; i++) begin
            always_comb begin
                flush_mask[i] = 0;
                if((back <= new_front) && (new_front < old_front)) begin
                    flush_mask[i] = list[i] > new_front;
                end else if((back <= new_front) && (old_front < new_front)) begin
                    flush_mask[i] = (list[i] > new_front) || (list[i] < back);
                end else if((back >= new_front) && (new_front < old_front)) begin
                    flush_mask[i] = (list[i] > new_front) && (list[i] < old_front);
                end
            end
        end
    endgenerate
endmodule
