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
    parameter LINE_SIZE = $clog2(`AL_SIZE) * 2 + 6*64 + 7 + 6 + 6 + 6*32 + $clog2(`AL_SIZE)+1
    )(
    input clk, reset,
    input ext_stall, ext_flush,
    //validate checkpoint
    input validate [`NUM_BRANCHES_RESOLVED],
    input [$clog2(`NUM_CHECKPOINTS)-1:0] validated_id [`NUM_BRANCHES_RESOLVED],
    //recall data
    input recall_checkpoint,
    input [$clog2(`NUM_CHECKPOINTS)-1:0] recall_id,
    //create checkpoint
    input if_branch [2],
    input instrs_valid [2],
    input [5:0] free_list [64],
    input [6:0] fl_size,
    input [5:0] fl_front, fl_back,
    input [$clog2(`AL_SIZE)-1:0] al_front, al_back,
    input [$clog2(`AL_SIZE):0] al_size,
    input [5:0] RMT_copy [32],
    //outputs
    output logic [LINE_SIZE-1:0] recalled_data,
    output logic int_stall
    );
    
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] checkpoint_front, checkpoint_back;
    logic [$clog2(`NUM_CHECKPOINTS):0] num_checkpoints;
    /*(* ram_style = "registers" *) */logic checkpoint_validated [`NUM_CHECKPOINTS];
    
    logic [LINE_SIZE-1:0] din;
    
    assign din[390:384] = fl_size;
    assign din[396:391] = fl_front;
    assign din[402:397] = fl_back;
    assign din[$clog2(`AL_SIZE)-1+403:403] = al_front;
    assign din[$clog2(`AL_SIZE)-1+403+$clog2(`AL_SIZE):$clog2(`AL_SIZE)+403] = 0;//al_back; <-- YOU SHOULDNT NEED THE BACK OF THE ACTIVE LIST
    assign din[$clog2(`AL_SIZE)+403+$clog2(`AL_SIZE)+$clog2(`AL_SIZE):$clog2(`AL_SIZE)+403+$clog2(`AL_SIZE)] = al_size;
    localparam t = $clog2(`AL_SIZE)+403+$clog2(`AL_SIZE)+$clog2(`AL_SIZE)+1;
    genvar i;
    generate
        for(i = 0; i < 64; i++) begin
            assign din[i*6+:6] = free_list[i];
        end
        for(i = 0; i < 32; i++) begin
            //assign din[5*(i+1)+$clog2(`AL_SIZE)-1+403+$clog2(`AL_SIZE):i+$clog2(`AL_SIZE)+403+$clog2(`AL_SIZE)] = RMT_copy[i];
            assign din[i*6+t+:6] = RMT_copy[i];
        end
        
    endgenerate
    
    
    logic stall;
    logic we;
    assign stall = ext_stall || (if_branch[0] && instrs_valid[0] && if_branch[1] && instrs_valid[1]) || 
            ((num_checkpoints + if_branch[0] && instrs_valid[0] + if_branch[1] && instrs_valid[1]) >= `NUM_CHECKPOINTS);
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
    
    
    always_ff @(posedge clk) begin
        if(reset) begin
            checkpoint_front <= 0;
            checkpoint_back <= 0;
            num_checkpoints <= 0;
        end else if(recall_checkpoint) begin
            checkpoint_front <= recall_id;
            num_checkpoints <= (checkpoint_front > checkpoint_back) ? (checkpoint_front - checkpoint_back) : (checkpoint_front - checkpoint_back + `NUM_CHECKPOINTS);
        end else if(we && ~stall) begin
            for(int i = 0; i < `NUM_BRANCHES_RESOLVED; i++) begin
                if((checkpoint_front != validated_id[i]) && validate[i]) begin
                    checkpoint_validated[validated_id[i]] <= 1;
                end
            end
            checkpoint_validated[checkpoint_front] <= 0;
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
