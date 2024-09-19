`timescale 1ns / 1ps
`include "riscv_core.svh"
module temp_i_cache#(
    parameter DEPTH = 512,
    parameter LINE_SIZE = 2
    )(
    input clk, reset,
    input [`ADDR_WIDTH-1:0] read_addr [2],
    input read_addr_valid [2],
    input [`ADDR_WIDTH-1:0] fetch_addr,
    input fetch_addr_valid,
    input [32*LINE_SIZE-1:0] fetched_data,
    input ext_stall, ext_flush,
    output logic [31:0] read_instr [2],
    output logic valid_read [2],
    output logic miss [2],
    output logic int_stall,
    output logic [`ADDR_WIDTH-1:0] prev_read_addr [2]
    );
    
    assign int_stall = ext_stall;
    assign miss[0] = 0;
    assign miss[1] = 0;
    
    logic [31:0] mem [1028];
    genvar i;
    generate
        for(i = 0; i < 2; i++) begin
            always_ff @(posedge clk) begin
                if(reset || ext_flush) begin
                    valid_read[i] <= 0;
                    read_instr[i] <= 'h23;
                    prev_read_addr[i] <= 0;
                end else if(~ext_stall) begin
                    if(read_addr_valid[i]) begin
                        valid_read[i] <= read_addr_valid[i];
                        read_instr[i] <= mem[read_addr[i]/4];
                        prev_read_addr[i] <= read_addr[i];
                    end else begin
                        valid_read[i] <= 0;
                        read_instr[i] <= 'h23;
                        prev_read_addr[i] <= 0;
                    end
                end
            end
        end
    endgenerate

endmodule
