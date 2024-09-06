`timescale 1ns / 1ps

//ACTUALLY RETURNS THE RIGHT MOST INDEX
module select_left_most #(
    parameter SIZE = 8
    )(
    input [SIZE-1:0] input_mask,
    output logic [$clog2(SIZE)-1:0] o_idx
    );
    
    /*logic [SIZE-1:0] ready_mask;
    logic [SIZE-1:0] enc_val;
    genvar j;
    generate
        assign ready_mask[0] = input_mask[0];
        for(j = 1; j < SIZE; j++) begin
            assign ready_mask[j] = input_mask[j] || ready_mask[j-1];
        end
    endgenerate
    assign enc_val = ~ready_mask + 1'b1;
    encoder #(.SIZE(SIZE)) ENCODER (.in(enc_val), .out(o_idx));*/
    always_comb begin
        o_idx = SIZE-1;
        for(int i = SIZE-1; i >= 0; i--) begin
            if(input_mask[i]) begin
                o_idx = i;
            end
        end
    end
endmodule
