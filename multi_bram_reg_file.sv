`timescale 1ns / 1ps
`include "riscv_core.svh"

module multi_bram_reg_file #(
    parameter NUM_BRAMS=4,
    parameter DEPTH=`NUM_PR
    )(
    input clk, reset,
    input [1:0] mode,
    input [$clog2(`NUM_PR)-1:0] write_addr [2],
    input [31:0] write_data [2],
    input [$clog2(`NUM_PR)-1:0] read_addr [NUM_BRAMS*2],
    output logic [31:0] read_data [NUM_BRAMS*2]
    );
    
    logic [1:0] prev_state;
    always_ff @(posedge clk) begin
        if(reset) begin
            prev_state <= 2'b00;
        end else begin
            prev_state <= mode;
        end
    end
    
    
    logic [31:0] din [NUM_BRAMS][2];
    logic [$clog2(`NUM_PR)-1:0] addr [NUM_BRAMS][2];
    logic we [NUM_BRAMS][2];
    logic [31:0] dout [NUM_BRAMS][2];
    
    genvar i;
    generate 
        for(i = 0; i < NUM_BRAMS; i++) begin : gen_bram
            bram_block #(
                .WIDTH(32),
                .DEPTH(DEPTH)
            ) BRAM_BLOCK (
                .clk,
                .reset,
                .addr(addr[i]),
                .we(we[i]),
                .din(din[i]),
                .dout(dout[i])
            );
            
            always_comb begin
                if(mode == 2'b00) begin //2 writes
                    addr[i][0] = write_addr[0];
                    addr[i][1] = write_addr[1];
                    we[i][0] = 1;
                    we[i][1] = 1;
                    din[i][0] = write_data[0];
                    din[i][1] = write_data[1];
                end else if(mode == 2'b01) begin //1 writes
                    addr[i][0] = write_addr[0];
                    addr[i][1] = read_addr[i];
                    we[i][0] = 1;
                    we[i][1] = 0;
                    din[i][0] = write_data[0];
                    din[i][1] = 0;
                end else if(mode == 2'b10) begin //0 writes
                    addr[i][0] = read_addr[2*i];
                    addr[i][1] = read_addr[2*i+1];
                    we[i][0] = 0;
                    we[i][1] = 0;
                    din[i][0] = 0;
                    din[i][1] = 0;
                end else if(mode == 2'b11) begin //do nothing
                    addr[i][0] = read_addr[0];
                    addr[i][1] = read_addr[0];
                    we[i][0] = 0;
                    we[i][1] = 0;
                    din[i][0] = 0;
                    din[i][1] = 0;
                end
                
                if(prev_state == 2'b00) begin
                    read_data[2*i] = 0;
                    read_data[2*i+1] = 0;
                end else if(prev_state == 2'b01) begin
                    read_data[i+NUM_BRAMS] = 0;
                    read_data[i] = dout[i][1];
                end else if(prev_state == 2'b10) begin
                    read_data[2*i] = dout[i][0];
                    read_data[2*i+1] = dout[i][1];
                end else if(prev_state == 2'b11) begin
                    read_data[2*i] = 0;
                    read_data[2*i+1] = 0;
                end
            end
        end
    endgenerate
    
    
endmodule
