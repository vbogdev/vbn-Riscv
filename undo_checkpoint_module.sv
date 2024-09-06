`timescale 1ns / 1ps
`include "riscv_core.svh"

module undo_checkpoint_module #(
    parameter DEPTH=8
    )(
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    input [$clog2(`AL_SIZE)-1:0] list [DEPTH],
    input [DEPTH-1:0] i_valid,
    output logic [DEPTH-1:0] flush_mask
    );  
    
    
    genvar i;
    generate
        for(i = 0; i < DEPTH; i++) begin
            always_comb begin
                flush_mask[i] = 0;
                if((back <= new_front) && (new_front < old_front)) begin
                    flush_mask[i] = (list[i] > new_front) && i_valid[i];
                end else if((back <= new_front) && (old_front < new_front)) begin
                    flush_mask[i] = (list[i] > new_front) || (list[i] < back) && i_valid[i];
                end else if((back >= new_front) && (new_front < old_front)) begin
                    flush_mask[i] = (list[i] > new_front) && (list[i] < old_front) && i_valid[i];
                end else begin
                    flush_mask[i] = 0;
                end
            end
        end
    endgenerate
endmodule
