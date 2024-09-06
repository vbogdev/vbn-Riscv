`timescale 1ns / 1ps
`include "riscv_core.svh"

module rf_selector_module #(
    parameter NUM_BRAMS=4
    )(
    //input clk, reset, 
    input [11:0] r_read_mask,
    input [11:0] r_done_mask,
    output logic [3:0] r_selected_id [NUM_BRAMS*2],
    
    input [5:0] w_read_mask,
    input [5:0] w_done_mask,
    output logic [2:0] w_selected_id [2]
    );
    
    logic [11:0] r_full_mask [NUM_BRAMS*2];
    logic [5:0] w_full_mask [2];
    
    always_comb begin
        for(int n = 0; n < NUM_BRAMS*2; n++) begin
            for(int i = 0; i < 12; i++) begin
                if(n == 0) begin
                    r_full_mask[n][i] = r_read_mask[i] && ~r_done_mask[i];
                end else begin
                    r_full_mask[n][i] = r_read_mask[i] && ~r_done_mask[i] && r_full_mask[n-1][i];
                end
            end
            if(n > 0) begin
                r_full_mask[n][r_selected_id[n-1]] = 0;
            end
        end
        
        for(int n = 0; n < 2; n++) begin
            for(int i = 0; i < 6; i++) begin
                if(n == 0) begin
                    w_full_mask[n][i] = w_read_mask[i] && ~w_done_mask[i];
                end else begin
                    w_full_mask[n][i] = w_read_mask[i] && ~w_done_mask[i] && w_full_mask[n-1][i];
                end
            end
            
            if(n > 0) begin
                w_full_mask[n][w_selected_id[n-1]] = 0;
            end
        end
    end
    
    genvar j; 
    generate
        for(j = 0; j < NUM_BRAMS*2; j++) begin
            enc_12 ENC12 (.in(r_full_mask[j]), .out(r_selected_id[j]));
        end
        
        for(j = 0; j < 2; j++) begin
            enc_6 ENC6 (.in(w_full_mask[j]), .out(w_selected_id[j]));
        end
    endgenerate
    
    
endmodule