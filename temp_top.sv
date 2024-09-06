`timescale 1ns / 1ps


module temp_top(
        input sys_clk_pin,
        input reset,
        input [11:0] in,
        input [1:0] i_num_reads,
        //input [2:0] sel,
        input [1:0] sel2,
        input [2:0] sel3,
        output logic [3:0] out
    );
    
    logic clk, locked;
    clk_100_mhz CLK_MANAGER(
        .clk_out1(clk), 
        .reset(reset), // input reset
        .locked(locked),       // output locked
        .clk_in(sys_clk_pin)      // input clk_in
    );
    
    logic [11:0] t_read_mask, t_valid_mask, t_done_mask, r_read_mask, r_valid_mask, r_done_mask;
    logic [3:0] r_selected_id [8];
    
    always_ff @(posedge clk) begin
        if(sel2 == 2'b00) begin
            t_read_mask <= in;
        end else if(sel2 == 2'b01) begin
            t_valid_mask <= in;
        end else if(sel2 == 2'b10) begin
            t_done_mask <= in;
        end else begin
            r_read_mask <= t_read_mask;
            r_valid_mask <= t_valid_mask;
            r_done_mask <= t_done_mask;
        end
    end
    
    always_comb begin
        case(sel3)
            3'b000: out = r_selected_id[0];
            3'b001: out = r_selected_id[1];
            3'b010: out = r_selected_id[2];
            3'b011: out = r_selected_id[3];
            3'b100: out = r_selected_id[4];
            3'b101: out = r_selected_id[5];
            3'b110: out = r_selected_id[6];
            3'b111: out = r_selected_id[7];
        endcase
    end
    
    logic [5:0] w_read_mask, w_valid_mask, w_done_mask;
    logic [2:0] w_selected_id [2];
    
    rf_selector_module RFSM(
        .*
    );
endmodule
