`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/09/2024 03:39:19 PM
// Design Name: 
// Module Name: enc_6
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module enc_6(
    input [5:0] in,
    output logic [2:0] out
    );
    
    always_comb begin
        if(in[0]) begin
            out = 3'd0;
        end else if(in[1]) begin
            out = 3'd1;
        end else if(in[2]) begin
            out = 3'd2;
        end else if(in[3]) begin
            out = 3'd3;
        end else if(in[4]) begin
            out = 3'd4;
        end else if(in[5]) begin
            out = 3'd5;
        end else begin
            out = 3'd0;
        end
    end
endmodule
