`timescale 1ns / 1ps
`include "riscv_core.svh"
/*
Very simple gshare with 1 bit counters, only to be used in fetch stage
Decode stage might use a more complicated version but idk
*/

module gshare #(
    parameter HISTORY_WIDTH = 14
    )(
    input clk, reset,
    branch_fb_ifc.in i_fb [2],
    input [`ADDR_WIDTH-1:0] pred_addr [2],
    input pred_addr_valid [2],
    output riscv_pkg::BranchOutcome prediction[2],
    output logic int_stall
    );
    
    logic [HISTORY_WIDTH-1:0] history;
    
    logic [HISTORY_WIDTH-1:0] read_addr [2];
    logic [HISTORY_WIDTH-1:0] write_addr [2];
    
    assign read_addr[0] = history ^ pred_addr[0][HISTORY_WIDTH-1:0];
    assign read_addr[1] = history ^ pred_addr[1][HISTORY_WIDTH-1:0];
    assign write_addr[0] = history ^ i_fb[0].branch_pc[HISTORY_WIDTH-1:0];
    assign write_addr[1] = history ^ i_fb[1].branch_pc[HISTORY_WIDTH-1:0];
    
    
    logic [HISTORY_WIDTH-1:0] addr [2];
    logic we [2];
    logic din [2];
    logic dout [2];
    
    
    logic [1:0] write_sum, read_sum;
    logic [2:0] port_sum;
    always_comb begin
        read_sum = pred_addr_valid[0] + pred_addr_valid[1];
        write_sum = i_fb[0].if_branch + i_fb[1].if_branch;
        port_sum = write_sum + read_sum;
        if(port_sum > 2) begin
            int_stall = 1;
        end else begin
            int_stall = 0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(reset) begin
            history <= 0;
        end else begin
            if(i_fb[0].if_branch) begin
                if(i_fb[1].if_branch) begin
                    history <= {(history << 2), (i_fb[0].outcome == TAKEN), (i_fb[1].outcome == TAKEN)};
                end else begin
                    history <= {(history << 1), (i_fb[0].outcome == TAKEN)};
                end
            end else if(i_fb[1].if_branch) begin
                history <= {(history << 1), (i_fb[1].outcome == TAKEN)};
            end
        end
    end
    
    always_comb begin
        we[0] = 0;
        we[1] = 0;
        din[0] = 0;
        din[1] = 0;
        if(i_fb[0].if_branch) begin
            we[0] = 1;
            din[0] = (i_fb[0].outcome == TAKEN) ? 1 : 0;
            addr[0] = write_addr[0];
            if(i_fb[1].if_branch) begin
                we[1] = 1;
                din[1] = (i_fb[1].outcome == TAKEN) ? 1 : 0;
                addr[1] = write_addr[1];
            end else if(pred_addr_valid[0]) begin
                we[1] = 0;
                din[1] = 0;
                addr[1] = read_addr[0];
            end else if(pred_addr_valid[1]) begin
                we[1] = 0;
                din[1] = 0;
                addr[1] = read_addr[1];
            end else begin
                we[1] = 0;
                din[1] = 0;
                addr[1] = 0;
            end
        end else if (i_fb[1].if_branch) begin
            we[0] = 1;
            din[0] = (i_fb[1].outcome == TAKEN) ? 1 : 0;
            addr[0] = write_addr[1];
              
            if(pred_addr_valid[0]) begin
                we[1] = 0;
                din[1] = 0;
                addr[1] = read_addr[0];
            end else if(pred_addr_valid[1]) begin
                we[1] = 0;
                din[1] = 0;
                addr[1] = read_addr[1];
            end else begin
                we[1] = 0;
                din[1] = 0;
                addr[1] = 0;
            end
        end else begin
            we[0] = 0;
            din[0] = 0;
            addr[0] = read_addr[0];
            we[0] = 0;
            din[0] = 0;
            addr[1] = read_addr[1];
        end
    end
    
    bram_block #(.WIDTH(1), .DEPTH(1 << HISTORY_WIDTH)) HISTORY_TABLE(.*);
    
    assign prediction[0] = (dout[0] == 0) ? NOT_TAKEN : TAKEN;
    assign prediction[1] = (dout[1] == 0) ? NOT_TAKEN : TAKEN;

    
endmodule
