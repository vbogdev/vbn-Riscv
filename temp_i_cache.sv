`timescale 1ns / 1ps
`include "riscv_core.svh"
module temp_i_cache#(
    parameter DEPTH = 512,
    parameter LINE_SIZE = 2
    )(
    input clk, reset,
    input [`ADDR_WIDTH-1:0] read_addr [2],
    input read_addr_valid [2],
    input ext_stall, ext_flush,
    input [`ADDR_WIDTH-1:0] fetch_addr,      
    input fetch_addr_valid,
    input [31:0] fetched_data,    
    output logic [31:0] read_instr [2],
    output logic valid_read [2],
    output logic miss [2],
    output logic int_stall,
    output logic [`ADDR_WIDTH-1:0] prev_read_addr [2]
    );
    
    assign int_stall = ext_stall || fetch_addr_valid;
    assign miss[0] = 0;
    assign miss[1] = 0;
    
    
    //logic [31:0] mem [1028];
    genvar i;
    generate
        for(i = 0; i < 2; i++) begin
            always_ff @(posedge clk) begin
                if(reset || ext_flush) begin
                    valid_read[i] <= 0;
                    //read_instr[i] <= 'h23;
                    prev_read_addr[i] <= 0;
                end else if(~ext_stall) begin
                    if(read_addr_valid[i]) begin
                        valid_read[i] <= read_addr_valid[i];
                        //read_instr[i] <= mem[read_addr[i]/4];
                        prev_read_addr[i] <= read_addr[i];
                    end else begin
                        valid_read[i] <= 0;
                        //read_instr[i] <= 'h23;
                        prev_read_addr[i] <= 0;
                    end
                end
            end
        end
    endgenerate
    
    logic [31:0] dout [2];
    
    
    logic [9:0] addr [2];
    logic we [2];
    logic [31:0] din [2];
    
    always_comb begin
        addr[0] = fetch_addr_valid ? fetch_addr[9:0] : read_addr[0];
        addr[1] = fetch_addr_valid ? 0 : read_addr[1];
        we[0] = fetch_addr_valid;
        we[1] = 0;
        din[0] = fetched_data;
        din[1] = 0;
    end
    
    bram_block #(.DEPTH(1024)) CACHE(
        .clk,
        .addr,
        .we,
        .din,
        .dout
    );
    
    assign read_instr[0] = dout[0];
    assign read_instr[1] = dout[1];
    

endmodule
