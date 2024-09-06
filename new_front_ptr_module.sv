`timescale 1ns / 1ps
`include "riscv_core.svh"

module new_front_ptr_module #(
    parameter SIZE = 8
    )(
    input [SIZE-1:0] valid,
    input [SIZE-1:0] flush,
    input [$clog2(SIZE)-1:0] front_ptr, back_ptr,
    output logic [$clog2(SIZE)-1:0] new_front_ptr,
    output logic change
    );
    
    logic [$clog2(SIZE)-1:0] addr;
    logic right_most_bit;
    
    always_comb begin
        if(back_ptr < front_ptr) begin
            addr = 0;
            change = 0;
            for(int i = 0; i < SIZE; i++) begin
                if(valid[i] && flush[i] && (i < front_ptr) && (i >= back_ptr)) begin
                    addr = i;
                    change = 1;
                    break;
                end
            end
            new_front_ptr = addr;
        end else if(back_ptr > front_ptr) begin
            addr = 0;
            change = 0;
            if(valid[0] && flush[0]) begin
                right_most_bit = 1;
                change = 1;
            end else begin
                right_most_bit = 0;
            end
        
            //if this is true, you must check from back to end
            if(right_most_bit) begin
                for(int i = 0; i < SIZE; i++) begin
                    if((i >= back_ptr) && valid[i] && flush[i]) begin
                        addr = i;
                        break;
                    end
                end
            
                if(addr == 0) begin
                    new_front_ptr = 0;
                end else begin
                    new_front_ptr = addr;
                end
            end else begin
            //if not, then you must check from 0 to front
                for(int i = 0; i < SIZE; i++) begin
                    if((i < front_ptr) && valid[i] && flush[i]) begin
                        addr = i;
                        change = 1;
                        break;
                    end
                end
                
                new_front_ptr = addr;
            end
            
            end else begin
                //can be done in module above this
                change = 0;
                new_front_ptr = 0;
            end
    end
    
endmodule
