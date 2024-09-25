`timescale 1ns / 1ps
`include "riscv_core.svh"

/*
TO GET EXTRA PERFORMANCE GO ONLY GUESS A BRANCH IF pred_addr != next_addr + 8
COSTS A GOOD BIT OF EXTRA RESOURCES AND SLACK THOUGH
*/
module next_pc_predictor(
    input clk, reset, ext_stall, ext_flush,
    branch_fb_ifc.in i_branch [2],
    branch_fb_decode_ifc.in i_dec,
    output logic [`ADDR_WIDTH-1:0] guess [2],
    output logic guess_valid [2],
    output logic guesses_branch [2]
    );
    
    logic [`ADDR_WIDTH-1:0] select_output [2];
    
    logic [`ADDR_WIDTH-1:0] read_addr [2];
    logic [`ADDR_WIDTH-1:0] read_addr_stored [2];
    logic read_addr_valid [2];
    assign read_addr_valid[0] = 1;
    assign read_addr_valid[1] = 1;
    
    logic [`ADDR_WIDTH-1:0] fb_new_pc;
    logic fb_new_pc_valid;
    
    always_ff @(posedge clk) begin
        read_addr_stored[0] <= read_addr[0];
        read_addr_stored[1] <= read_addr[1];
        
        if(reset) begin
            fb_new_pc <= 0;
            fb_new_pc_valid <= 0;
        end else if(ext_stall) begin
        
        end else if(~i_branch[0].if_prediction_correct) begin
            fb_new_pc <= i_branch[0].new_pc;
            fb_new_pc_valid <= 1;
        end else if(~i_dec.if_prediction_correct) begin
            fb_new_pc <= i_dec.new_pc;
            fb_new_pc_valid <= 1;
        end else begin
            fb_new_pc_valid <= 0;
        end
    end
    
    logic [`ADDR_WIDTH-1:0] btb_guess [2];
    logic guess_valid_btb [2];
    logic btb_stall;
    logic tag_match [2];
    /*branch_target_buffer BTB(
        .clk, .reset,
        .i_fb(i_branch),
        .read_addr,
        .valid_read_addr(read_addr_valid),
        .guess(btb_guess),
        .guess_valid(guess_valid_btb),
        .int_stall(btb_stall),
        .tag_match
    );*/
    
    riscv_pkg::BranchOutcome prediction [2];
    logic pred_stall;
    /*gshare PREDICTOR(
        .clk, .reset,
        .i_fb(i_branch),
        .pred_addr(read_addr),
        .pred_addr_valid(read_addr_valid),
        .prediction,
        .int_stall(pred_stall)
    );*/
    
    logic [`ADDR_WIDTH-1:0] final_pred_addr [2];
    always_comb begin

        if(pred_stall || btb_stall) begin
            guesses_branch[0] = 0;
            guesses_branch[1] = 0;
            final_pred_addr[0] = read_addr_stored[0] + 'd8;
            final_pred_addr[1] = read_addr_stored[1] + 'd8;
        end else begin
            if((prediction[0] == TAKEN) && tag_match[0]) begin
                final_pred_addr[0] = btb_guess[0];
                final_pred_addr[1] = btb_guess[0] + 'd4;
                guesses_branch[0] = 1; //btb_guess[0] != (read_addr_stored[0] + 'd8);
                guesses_branch[1] = 0;
            end else if ((prediction[1] == TAKEN) && tag_match[1]) begin
                final_pred_addr[0] = read_addr_stored[1] + 'd4;
                final_pred_addr[1] = btb_guess[1];
                guesses_branch[0] = 0;
                guesses_branch[1] = 1;
            end else begin 
                final_pred_addr[0] = read_addr_stored[0] + 'd8;
                final_pred_addr[1] = read_addr_stored[1] + 'd8;
                guesses_branch[0] = 0;
                guesses_branch[1] = 0;
            end
        end 
    end
    
    always_comb begin
        if(reset) begin
            read_addr[0] = 'd0;
            read_addr[1] = 'd4;
        end else if(fb_new_pc_valid) begin
            read_addr[0] = fb_new_pc;
            read_addr[1] = fb_new_pc + 'd4;
        end else if(ext_stall) begin
            read_addr[0] = read_addr_stored[0];
            read_addr[1] = read_addr_stored[1];
        end else begin
            read_addr[0] = final_pred_addr[0];
            read_addr[1] = final_pred_addr[1];
        end
    end
    
    assign guess[0] = read_addr[0];
    assign guess[1] = read_addr[1];
    assign guess_valid[0] = ~ext_flush;
    assign guess_valid[1] = ~ext_flush;
endmodule
