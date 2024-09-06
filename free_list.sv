`timescale 1ns / 1ps
`include "riscv_core.svh"

module free_list(
    input clk, input reset,
    ext_stall,
    //allocated instructions
    input uses_rd [2],
    input valid [2],
    //recall
    input if_recall,
    input [$clog2(`NUM_PR)-1:0] recalled_front_ptr,
    //feedback from al
    input if_freed,
    input [$clog2(`NUM_PR)-1:0] freed_reg,
    //make checkpoint
    input make_checkpoint [2],
    output logic [$clog2(`NUM_PR)-1:0] checkpointed_front_ptr,
    //allocated phys reg
    output logic [$clog2(`NUM_PR)-1:0] allocated_regs [2],
    output int_stall
    );
    
    logic [$clog2(`NUM_PR)-1:0] full_list [`NUM_PR];
    logic [$clog2(`NUM_PR):0] list_size;
    logic [$clog2(`NUM_PR)-1:0] front_ptr, back_ptr;
    
    assign list_size = (front_ptr > back_ptr) ? (`NUM_PR - front_ptr + back_ptr) : 
        (back_ptr - front_ptr);
        
    assign allocated_regs[0] = full_list[front_ptr];
    assign allocated_regs[1] = full_list[front_ptr + 1];
    assign int_stall = (list_size < (uses_rd[0] && valid[0]) + (uses_rd[1] && valid[1]));
    
    always_comb begin
        if(make_checkpoint[0]) begin
            checkpointed_front_ptr = front_ptr;
        end else if(make_checkpoint[1]) begin
            checkpointed_front_ptr = front_ptr + (valid[0]);
        end else begin
            checkpointed_front_ptr = 0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(reset) begin
            for(int i = 0; i < `NUM_PR; i++) begin
                full_list[i] <= i;
            end
            front_ptr <= 'd32;
            back_ptr <= 0;
        end else if(~ext_stall || ~int_stall) begin
            if(~if_recall) begin
                if(uses_rd[0] && valid[0] && uses_rd[1] && valid[1] && (list_size >= 2)) begin
                    front_ptr <= front_ptr + 2;
                end else if(uses_rd[0] && valid[0] && (list_size >= 1)) begin
                    front_ptr <= front_ptr + 1;
                end else if(uses_rd[1] && valid[1] && (list_size >= 1)) begin
                    front_ptr <= front_ptr + 1;
                end
            end else if(if_recall) begin
                front_ptr <= recalled_front_ptr;
            end
            
            if(if_freed) begin
                back_ptr <= back_ptr + 1;
                full_list[back_ptr] <= freed_reg;
            end
        end
    end
endmodule
