`timescale 1ns / 1ps
`include "riscv_core.svh"

module free_list(
    input clk, input reset,
    ext_flush, ext_stall,
    //allocated instructions
    input uses_rd [2],
    input valid [2],
    //recall
    input if_recall,
    input [383:0] recalled_list,
    input [5:0] recalled_front_ptr, recalled_back_ptr,
    input [6:0] recalled_list_size,
    //feedback from al
    input if_freed,
    input [5:0] freed_reg,
    //make checkpoint
    input make_checkpoint [2],
    output logic [383:0] checkpointed_list,
    output logic [5:0] checkpointed_front_ptr, checkpointed_back_ptr,
    output logic [6:0] checkpointed_list_size,
    //allocated phys reg
    output logic [5:0] allocated_regs [2],
    output int_stall
    );
    
    logic [5:0] full_list [64];
    logic [5:0] expected_list [64]; //used to combinationally apply changes for checkpointing
    logic [5:0] front_ptr, back_ptr, expected_front_ptr, expected_back_ptr;
    logic [6:0] list_size, expected_list_size;
    
    
    logic stall;
    assign stall = ext_stall || ((list_size - (uses_rd[0] && valid[0]) - (uses_rd[1] && valid[1])) < 0) || if_recall;
    assign int_stall = ((list_size - (uses_rd[0] && valid[0]) - (uses_rd[1] && valid[1])) < 0) || if_recall;
    
    genvar j;
    generate
        for(j = 0; j < 64; j++) begin
            assign checkpointed_list[j*6+:6] = expected_list[j];
            assign expected_list[j] = (if_freed && (back_ptr == j)) ? freed_reg : full_list[j];
        end
    endgenerate
    
    always_comb begin
        expected_front_ptr = front_ptr;
        expected_back_ptr = back_ptr;
        expected_list_size = list_size;
        
        allocated_regs[0] = 0;
        allocated_regs[1] = 0;
    
        if(if_freed) begin
            expected_back_ptr = back_ptr + 1;
        end
        if(~stall) begin
            if(uses_rd[0] && valid[0] && uses_rd[1] && valid[1]) begin
                expected_front_ptr = front_ptr + 2;
                allocated_regs[0] = full_list[front_ptr];
                allocated_regs[1] = full_list[front_ptr + 1];
                if(if_freed) begin
                    expected_list_size = list_size + 1;
                end else begin
                    expected_list_size = list_size + 2;
                end
            end else if(uses_rd[0] && valid[0]) begin
                expected_front_ptr = front_ptr + 1;
                allocated_regs[0] = full_list[front_ptr];
                if(if_freed) begin
                    expected_list_size = list_size;
                end else begin
                    expected_list_size = list_size + 1;
                end
            end else if(uses_rd[1] && valid[1]) begin
                expected_front_ptr = front_ptr + 1;
                allocated_regs[1] = full_list[front_ptr];
                if(if_freed) begin
                    expected_list_size = list_size;
                end else begin
                    expected_list_size = list_size + 1;
                end
            end else begin
                if(if_freed) begin
                    expected_list_size = list_size - 1;
                end else begin
                    expected_list_size = list_size;
                end
            end
        end
        
        checkpointed_front_ptr = 0;
        checkpointed_back_ptr = 0;
        checkpointed_list_size = 0;
        if(make_checkpoint[0]) begin
            //calculate ptr position 
            checkpointed_back_ptr = expected_back_ptr;
            if(uses_rd[0] && valid[0]) begin
                //if checkpoint does required rd (JALR)
                checkpointed_front_ptr = front_ptr + 1;
                if(if_freed) begin
                    checkpointed_list_size = list_size;
                end else begin
                    checkpointed_list_size = list_size - 1;
                end
            end else begin
                //if checkpoint doesn't require an rd
                checkpointed_front_ptr = front_ptr;
                if(if_freed) begin
                    checkpointed_list_size = list_size + 1;
                end else begin
                    checkpointed_list_size = list_size;
                end
            end
        end else if(make_checkpoint[1]) begin
            //just use expected ptr postions as everything is already calculated
            checkpointed_back_ptr = expected_back_ptr;
            checkpointed_front_ptr = expected_front_ptr;
            checkpointed_list_size = expected_list_size;
        end
    end
    
    always_ff @(posedge clk) begin
        if(reset) begin
            for(int i = 0; i < 64; i++) begin
                full_list[i] <= i;
            end
            front_ptr <= 32;
            back_ptr <= 63;
            list_size <= 32;
        end else if(if_recall) begin
            front_ptr <= recalled_front_ptr;
            back_ptr <= recalled_back_ptr;
            list_size <= recalled_list_size;
            for(int i = 0; i < 64; i++) begin
                full_list[i] <= recalled_list[i*6+:6];
            end
        end else begin
            front_ptr <= expected_front_ptr;
            back_ptr <= expected_back_ptr;
            list_size <= expected_list_size;
            for(int i = 0; i < 64; i++) begin
                full_list[i] <= expected_list[i];
            end
        end
    end
endmodule
