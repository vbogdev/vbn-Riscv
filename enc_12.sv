`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/08/2024 11:17:19 PM
// Design Name: 
// Module Name: enc_12
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


module enc_12 (
    input [11:0] in,
    output logic [3:0] out
    );
    
    always_comb begin
        if(in[0]) begin
            out = 4'd0;
        end else if(in[1]) begin
            out = 4'd1;
        end else if(in[2]) begin
            out = 4'd2;
        end else if(in[3]) begin
            out = 4'd3;
        end else if(in[4]) begin
            out = 4'd4;
        end else if(in[5]) begin
            out = 4'd5;
        end else if(in[6]) begin
            out = 4'd6;
        end else if(in[7]) begin
            out = 4'd7;
        end else if(in[8]) begin
            out = 4'd8;
        end else if(in[9]) begin
            out = 4'd9;
        end else if(in[10]) begin
            out = 4'd10;
        end else if(in[11]) begin
            out = 4'd11;
        end else begin
            out = 4'd0;
        end
    end
endmodule
