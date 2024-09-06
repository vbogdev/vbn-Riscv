`timescale 1ns / 1ps
`include "riscv_core.svh"

module fetch_stage(
    input clk, reset,
    branch_fb_ifc.in branch_fb [2],
    branch_fb_decode_ifc.in decode_fb,
    input ext_stall, ext_flush,
    fetch_out_ifc.out o_instr [2],
    
    input [`ADDR_WIDTH-1:0] fetch_addr,
    input fetch_addr_valid,
    input [32*2-1:0] fetched_data
    );
    
    logic miss [2];
    logic [`ADDR_WIDTH-1:0] predicted_pc [2];
    logic predicted_pc_valid [2];
    logic predictor_stall;
    logic cache_stall;
    logic guesses_branch [2];
    assign predictor_stall = cache_stall || ext_stall;
    
    
    temp_next_pc_predictor PREDICTOR(
        .clk, .reset, 
        .ext_stall(predictor_stall), 
        .ext_flush,
        .i_branch(branch_fb),
        .i_dec(decode_fb),
        .guess(predicted_pc),
        .guess_valid(predicted_pc_valid),
        .guesses_branch
    );
    
    
    logic [31:0] read_instr [2];
    logic valid_read [2];
    logic [`ADDR_WIDTH-1:0] read_pc [2];
    
    logic [`ADDR_WIDTH-1:0] prev_addr [2];
    always_ff @(posedge clk) begin
        
        read_pc[0] <= predicted_pc[0];
        read_pc[1] <= predicted_pc[1];
        if(reset) begin
            prev_addr[0] <= 'd16;
            prev_addr[1] <= 'd16;
        end else begin
            prev_addr[0] <= read_pc[0];
            prev_addr[1] <= read_pc[1];
        end
    end
    
    
    logic [`ADDR_WIDTH-1:0] prev_read_addr [2];
    temp_i_cache I_CACHE(
        .clk, .reset,
        .read_addr(predicted_pc),
        .read_addr_valid(predicted_pc_valid),
        .fetch_addr,
        .fetch_addr_valid,
        .fetched_data,
        .ext_stall,
        .ext_flush,
        .read_instr,
        .valid_read,
        .miss,
        .int_stall(cache_stall),
        .prev_read_addr
    );
    
    assign o_instr[0].valid = ~miss[0] && valid_read[0];// && (prev_addr[0] != read_pc[0]);
    assign o_instr[0].pc = prev_read_addr[0];
    assign o_instr[0].instr = read_instr[0];
    assign o_instr[0].guesses_branch = guesses_branch[0];
    assign o_instr[0].prediction = predicted_pc[0];
    assign o_instr[1].valid = ~miss[1] && valid_read[1];// && (prev_addr[1] != read_pc[1]);
    assign o_instr[1].pc = prev_read_addr[1];
    assign o_instr[1].instr = read_instr[1];
    assign o_instr[1].guesses_branch = guesses_branch[1];
    assign o_instr[1].prediction = predicted_pc[1];

endmodule



