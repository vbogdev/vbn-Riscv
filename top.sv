`timescale 1ns / 1ps


module top(
    input reset,
    input sys_clk_pin,
    output [3:0] lights
    //output [31:0] out
    );
    
    
    logic clk, locked;
    clk_100_mhz CLK_MANAGER(
        .clk_out1(clk), 
        .reset(reset), // input reset
        .locked(locked),       // output locked
        .clk_in(sys_clk_pin)      // input clk_in
    );
    
    branch_fb_ifc branch_fb[2]();
    branch_fb_decode_ifc decode_fb();
    logic ext_stall, ext_flush;
    fetch_out_ifc instr[2]();
    decode_out_ifc dec_out[2]();
    
    fetch_stage(
        .clk, .reset,
        .branch_fb,
        .decode_fb,
        .ext_stall, .ext_flush,
        .o_instr(instr)
    );
    
    decode_stage(
        .clk, .reset,
        .i_fetch(instr),
        .ext_stall, .ext_flush,
        .o_decode(dec_out),
        .o_fb(decode_fb)
    );
    
    assign lights[0] = dec_out[0].uses_imm;
    assign lights[1] = dec_out[1].uses_imm;
    assign lights[2] = dec_out[0].target[3];
    assign lights[3] = dec_out[1].target[3];
    
    
endmodule
