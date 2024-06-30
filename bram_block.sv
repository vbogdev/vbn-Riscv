module bram_block #(
    parameter WIDTH = 32,
    parameter DEPTH = 32,
    parameter NUM_PORTS = 2
    )(
    input clk,
    input reset,
    input [$clog2(DEPTH)-1:0] addr [NUM_PORTS],
    input we [NUM_PORTS],
    input [WIDTH-1:0] din [NUM_PORTS],
    output logic [WIDTH-1:0] dout [NUM_PORTS]
    );
    
    
    logic [WIDTH-1:0] mem [DEPTH];
    
    genvar i;
    generate
        for(i = 0; i < NUM_PORTS; i++) begin
            always_ff @(posedge clk) begin
                if(we[i]) begin
                    mem[addr[i]] <= din[i];
                end
                dout[i] <= mem[addr[i]]; 
            end
        end
    endgenerate
    
    
endmodule