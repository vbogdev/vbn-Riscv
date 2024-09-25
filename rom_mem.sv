`timescale 1ns / 1ps
module rom_mem #(
    parameter WIDTH = 32,
    parameter DEPTH = 32,
    parameter NUM_PORTS = 2
    )(
    input clk,
    input [$clog2(DEPTH)-1:0] addr [NUM_PORTS],
    output logic [WIDTH-1:0] dout [NUM_PORTS]
    );
    
    
    genvar i;
    generate
        for(i = 0; i < NUM_PORTS; i++) begin
            always_ff @(posedge clk) begin
                dout[i] <= addr[i];//mem[addr[i]]; 
            end
        end
    endgenerate
    
    
endmodule