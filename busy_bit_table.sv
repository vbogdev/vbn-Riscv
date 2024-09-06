`timescale 1ns / 1ps
`include "riscv_core.svh"
module busy_bit_table(
    input clk, input reset,
    //busify reg
    input busify [2],
    input [$clog2(`NUM_PR)-1:0] busy_addr [2],
    input ext_stall,
    //unbusify reg
    input done [`NUM_INSTRS_COMPLETED],
    input [$clog2(`NUM_PR)-1:0] done_addr [`NUM_INSTRS_COMPLETED],
    //recall
    input if_recall,
    input [`NUM_PR-1:0] recalled_list,
    //output list
    output logic [`NUM_PR-1:0] expected_list
    );
    
    logic [`NUM_PR-1:0] busy_list;
    
    

    generate
        always_comb begin
            for(int i = 0; i < `NUM_PR; i++) begin
                expected_list[i] = busy_list[i];
                for(int j = 0; j < `NUM_INSTRS_COMPLETED; j++) begin
                    if(done[j] && (done_addr[j] == i) && ((i != busy_addr[0]) || ~busify[0]) && ((i != busy_addr[1]) || ~busify[1])) begin
                        expected_list[i] = 0;
                    end else if(((busy_addr[0] == i) && busify[0]) || ((busy_addr[1] == i) && busify[1])) begin
                        expected_list[i] = 1;
                    end
                end
            end
        end
    endgenerate
    
    always_ff @(posedge clk) begin
        for(int i = 0; i < `NUM_INSTRS_COMPLETED; i++) begin
            if(done[i]) begin
                busy_list[done_addr[i]] <= 0;
            end
        end
        if(reset) begin
            busy_list <= 0;
        end else if(if_recall) begin
            busy_list <= recalled_list;
        end else if(~ext_stall) begin
            for(int i = 0; i < 2; i++) begin
                if(busify[i]) begin
                    busy_list[busy_addr[i]] <= 1;
                end
            end
            
        end
    end
endmodule
