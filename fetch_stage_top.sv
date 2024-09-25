`timescale 1ns / 1ps
`include "riscv_core.svh"

module fetch_stage_top(
    input sys_clk,
    input reset,
    //requested instr inputs
    input [`ADDR_WIDTH-1:0] fetched_instr_addr,
    input [31:0] fetched_instr,
    input fetched_valid,
    //requested instr outputs
    output [`ADDR_WIDTH-1:0] fetch_req_addr,
    output fetch_req,
    //outgoing instr
    output [31:0] outgoing_instr [2],
    output outgoing_valid [2],
    output [`ADDR_WIDTH-1:0] outgoing_pc [2]
    );
    
    
endmodule
