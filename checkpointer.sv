`timescale 1ns / 1ps
`include "riscv_core.svh"

/*
Module Purpose:
    -store data on checkpoints
    -output data on recall
    -handle logic for checking if checkpointer full
    -make checkpointer from ram into fifo with recall
*/
module checkpointer #(
    parameter LINE_SIZE = $clog2(`AL_SIZE) + $clog2(`NUM_PR) + $clog2(`NUM_PR)*32 + 64
    )(
    input clk, reset,
    input ext_stall,
    //validate checkpoint
    input validate [`NUM_BRANCHES_RESOLVED],
    input [$clog2(`NUM_CHECKPOINTS)-1:0] validated_id [`NUM_BRANCHES_RESOLVED],
    //recall data
    input recall_checkpoint,
    input [$clog2(`NUM_CHECKPOINTS)-1:0] recall_id,
    //create checkpoint
    input if_branch [2],
    input instrs_valid [2],
    input [$clog2(`NUM_PR)-1:0] fl_front,
    input [$clog2(`AL_SIZE)-1:0] al_front,
    input [$clog2(`NUM_PR)-1:0] RMT_copy [32],
    input [`NUM_PR-1:0] bbt,
    //outputs
    output logic [LINE_SIZE-1:0] recalled_data,
    output logic int_stall,
    output logic [$clog2(`AL_SIZE)-1:0] oldest_al,
    output logic no_checkpoints,
    output [$clog2(`NUM_CHECKPOINTS)-1:0] cp_addr
    );
    
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] checkpoint_front, checkpoint_back;
    logic [$clog2(`NUM_CHECKPOINTS):0] num_checkpoints;
    /*(* ram_style = "registers" *) */logic checkpoint_validated [`NUM_CHECKPOINTS];
    
    logic [LINE_SIZE-1:0] din;
    assign cp_addr = checkpoint_front;
    
    logic [$clog2(`AL_SIZE)-1:0] al_addresses [`NUM_CHECKPOINTS];
    
    assign din[$clog2(`NUM_PR)-1:0] = fl_front;
    assign din[$clog2(`AL_SIZE)-1+$clog2(`NUM_PR):$clog2(`NUM_PR)] = al_front;
    assign din[$clog2(`AL_SIZE)+$clog2(`NUM_PR)+`NUM_PR-1:$clog2(`AL_SIZE)+$clog2(`NUM_PR)] = bbt;
    genvar i;
    generate
        for(i = 0; i < 32; i++) begin
            assign din[i*$clog2(`NUM_PR)+64+$clog2(`AL_SIZE)+$clog2(`NUM_PR)+:$clog2(`NUM_PR)] = RMT_copy[i];
        end        
    endgenerate
    
    
    logic stall;
    logic we;
    
    assign we = ((if_branch[0] && instrs_valid[0]) || (if_branch[1] && instrs_valid[1]));
    assign int_stall = (if_branch[0] && instrs_valid[0] && if_branch[1] && instrs_valid[1]) || 
            ((num_checkpoints + if_branch[0] && instrs_valid[0] + if_branch[1] && instrs_valid[1]) >= `NUM_CHECKPOINTS);
    
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] addr;
    assign addr = recall_checkpoint ? recall_id : checkpoint_front;
    
    distributed_ram #(
        .WIDTH(LINE_SIZE),
        .DEPTH(`NUM_CHECKPOINTS)
    ) checkpoints (
        .clk,
        .addr,
        .we,
        .din,
        .dout(recalled_data)
    );
    
    assign oldest_al = al_addresses[checkpoint_back];
    assign no_checkpoints = (num_checkpoints == 0);
    
    always_ff @(posedge clk) begin
        if(reset) begin
            checkpoint_front <= 0;
            checkpoint_back <= 0;
            num_checkpoints <= 0;
        end else if(recall_checkpoint) begin
            checkpoint_front <= recall_id;
            num_checkpoints <= (checkpoint_front > checkpoint_back) ? (checkpoint_front - checkpoint_back) : (checkpoint_front - checkpoint_back + `NUM_CHECKPOINTS);
        end else if(we && ~int_stall && ~ext_stall) begin
            for(int i = 0; i < `NUM_BRANCHES_RESOLVED; i++) begin
                if((checkpoint_front != validated_id[i]) && validate[i]) begin
                    checkpoint_validated[validated_id[i]] <= 1;
                end
            end
            checkpoint_validated[checkpoint_front] <= 0;
            al_addresses[checkpoint_front] <= al_front;
            if(checkpoint_validated[checkpoint_back]) begin
                checkpoint_back <= checkpoint_back + 1; 
            end else begin
                num_checkpoints <= num_checkpoints + 1;
            end
        end else begin
            for(int i = 0; i < `NUM_BRANCHES_RESOLVED; i++) begin
                if(validate[i]) begin
                    checkpoint_validated[validated_id[i]] <= 1;
                end
            end
            if(checkpoint_validated[checkpoint_back]) begin
                checkpoint_back <= checkpoint_back + 1;
                num_checkpoints <= num_checkpoints - 1;
            end
        end
    end
endmodule
