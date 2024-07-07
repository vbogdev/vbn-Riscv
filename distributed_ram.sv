module distributed_ram #(
    parameter WIDTH = 605,
    parameter DEPTH = 16
    )(
    input clk,
    input [$clog2(DEPTH)-1:0] addr,
    input we,
    input [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout
    );
    
    
    (* ram_style = "distributed" *) logic [WIDTH-1:0] mem [DEPTH];
    
    always_ff @(posedge clk) begin
        if(we) begin
            mem[addr] <= din;
        end
       
     end
     
     assign dout = mem[addr];
     
    
    
endmodule