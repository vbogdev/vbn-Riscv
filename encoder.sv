`timescale 1ns / 1ps


module encoder #(
    parameter SIZE = 8
    )(
    input [SIZE-1:0] in,
    output logic [$clog2(SIZE)-1:0] out
    );
    
    always_comb begin
        out = 0;
        for(int i = 0; i < SIZE; i++) begin
            if(in[i]) begin
                out = i;
            end
        end
    end
endmodule
