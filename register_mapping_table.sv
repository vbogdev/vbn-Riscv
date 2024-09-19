
`timescale 1ns / 1ps
`include "riscv_core.svh"


module register_mapping_table(
    input clk, reset,
    ext_stall, ext_flush,
    //read reg mappings
    input valid_instr [2],
    input [4:0] rs1 [2],
    input [4:0] rs2 [2],
    //recieve new mappings
    input valid_new_rd [2],
    input [4:0] rd [2],
    input [$clog2(`NUM_PR)-1:0] phys_rd [2],
    //if checkpointif_branch
    input if_checkpoint [2], //which instruction is checkpointed
    output logic [$clog2(`NUM_PR)-1:0] checkpointed_rmt [32],
    //if recall
    input if_recall,
    input [$clog2(`NUM_PR)-1:0] recalled_rmt [32],
    //outputs
    output logic [$clog2(`NUM_PR)-1:0] phys_rs1 [2],
    output logic [$clog2(`NUM_PR)-1:0] phys_rs2 [2],
    output logic [$clog2(`NUM_PR)-1:0] old_rd [2],
    output int_stall
    );
    
    logic [$clog2(`NUM_PR)-1:0] rmt [32];
    logic stall;
    assign stall = ext_stall || if_recall;
    assign int_stall = if_recall;
    
    always_comb begin
        //handle for checkpointing
        for(int i = 0; i < 32; i++) begin
            checkpointed_rmt[i] = rmt[i];
        end
        if(if_checkpoint[0]) begin
            for(int i = 0; i < 32; i++) begin 
                if(valid_new_rd[0] && valid_instr[0] && (rd[0] == i)) begin
                    checkpointed_rmt[i] = phys_rd[0];
                end else begin
                    checkpointed_rmt[i] = rmt[i];
                end
            end  
        end else if(if_checkpoint[1]) begin
            for(int i = 0; i < 32; i++) begin
                if(valid_new_rd[0] && valid_new_rd[1] && (rd[0] == rd[1]) && (rd[1] == i)) begin
                    checkpointed_rmt[i] = phys_rd[1];
                end else if(valid_new_rd[0] && valid_new_rd[1] && (rd[0] != rd[1]) && (rd[0] == i)) begin
                    checkpointed_rmt[i] = phys_rd[0];
                end else if(valid_new_rd[0] && valid_new_rd[1] && (rd[0] != rd[1]) && (rd[1] == i)) begin
                    checkpointed_rmt[i] = phys_rd[1];
                end else begin
                    checkpointed_rmt[i] = rmt[i];
                end
            end  
        end
        
        
        
        //handle outputting mappings
        phys_rs1[0] = rmt[rs1[0]];
        phys_rs2[0] = rmt[rs2[0]];
        old_rd[0] = rmt[rd[0]];
        
        if(valid_new_rd[0] && valid_instr[0] && (rs1[1] == rd[0])) begin
            phys_rs1[1] = phys_rd[0];
        end else begin
            phys_rs1[1] = rmt[rs1[1]];
        end
        if(valid_new_rd[0] && valid_instr[0] && (rs2[1] == rd[0])) begin
            phys_rs2[1] = phys_rd[0];
        end else begin
            phys_rs2[1] = rmt[rs2[1]];
        end
        if(valid_new_rd[0] && valid_instr[0] && (rd[1] == rd[0])) begin
            old_rd[1] = phys_rd[0];
        end else begin
            old_rd[1] = rmt[rd[1]];
        end
        
    end
    
    always_ff @(posedge clk) begin
        if(reset) begin
            for(int i = 0; i < 32; i++) begin
                rmt[i] <= i;
            end
        end else if(if_recall) begin
            for(int i = 0; i < 32; i++) begin
                rmt[i] <= recalled_rmt[i];
            end
        end else if(~stall) begin
            if(valid_new_rd[0] && valid_instr[0] && valid_new_rd[1] && valid_instr[1]) begin
                if(rd[0] == rd[1]) begin
                    rmt[rd[1]] <= phys_rd[1];
                end else begin
                    rmt[rd[0]] <= phys_rd[0];
                    rmt[rd[1]] <= phys_rd[1];
                end
            end else if(valid_new_rd[0] && valid_instr[0]) begin
                rmt[rd[0]] <= phys_rd[0];
            end else if(valid_new_rd[1] && valid_instr[1]) begin
                rmt[rd[1]] <= phys_rd[0];
            end
        end
    end
endmodule

