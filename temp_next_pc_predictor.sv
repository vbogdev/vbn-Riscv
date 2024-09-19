`timescale 1ns / 1ps
`include "riscv_core.svh"

module temp_next_pc_predictor(
    input clk, reset, ext_stall, ext_flush,
    branch_fb_ifc.in i_branch [2],
    branch_fb_decode_ifc.in i_dec,
    output logic [`ADDR_WIDTH-1:0] guess [2],
    output logic guess_valid [2],
    output logic guesses_branch [2]
    );
    
    logic [`ADDR_WIDTH-1:0] next_pc [2];
    
    always_ff @(posedge clk) begin
        if(reset) begin
            next_pc[0] <= 0;
            next_pc[1] <= 'd4;
        end else if(~i_branch[0].if_prediction_correct && i_branch[0].if_branch) begin
            next_pc[0] <= i_branch[0].new_pc;
            next_pc[1] <= i_branch[0].new_pc + 'd4;
        end else if(~i_dec.if_prediction_correct && i_dec.if_branch) begin
            next_pc[0] <= i_dec.new_pc;
            next_pc[1] <= i_dec.new_pc + 'd4;
        end else if(~ext_stall) begin
            next_pc[0] <= next_pc[0] + 'd8;
            next_pc[1] <= next_pc[1] + 'd8;
        end
    end
    
    assign guess[0] = next_pc[0];
    assign guess[1] = next_pc[1];
    assign guess_valid[0] = 1;
    assign guess_valid[1] = 1;
    assign guesses_branch[0] = 0;
    assign guesses_branch[1] = 0;
endmodule
