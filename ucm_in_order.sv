`timescale 1ns / 1ps
`include "riscv_core.svh"
module ucm_in_order(
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    //input [$clog2(`AL_SIZE)-1:0] list [`AL_SIZE],
    input [`AL_SIZE-1:0] i_valid,
    output logic [`AL_SIZE-1:0] flush_mask
    );
    
    genvar i; 
    generate
        for(i = 0; i < `AL_SIZE; i++) begin
            always_comb begin
                if((back < new_front) && (new_front < old_front)) begin
                    if((i > back) && (i < new_front)) begin
                        flush_mask[i] = 0;
                    end else begin
                        flush_mask[i] = 1;
                    end 
                end else if((old_front < back) && (back < new_front)) begin
                    if((i > back) && (i < new_front)) begin
                        flush_mask[i] = 0;
                    end else begin
                        flush_mask[i] = 1;
                    end 
                end else if((new_front < old_front) && (old_front < back)) begin
                    if(i < new_front) begin
                        flush_mask[i] = 0;
                    end else if(i > back) begin
                        flush_mask[i] = 0;
                    end else begin
                        flush_mask[i] = 1;
                    end
                end else begin
                    flush_mask[i] = 0;
                end
            end
        end
    endgenerate
endmodule
