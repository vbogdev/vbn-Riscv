`timescale 1ns / 1ps
`include "riscv_core.svh"

module active_list(
    input clk, reset,
    ext_stall, ext_flush,
    //instructions to allocate
    input valid_instr [2],
    input uses_rd [2],
    input [5:0] phys_rd [2],
    input [4:0] arch_rd [2],
    //recall checkpoint
    input recall_checkpoint,
    input [$clog2(`AL_SIZE)-1:0] new_front,
    //finished instruction feedback
    input completed_valid [`NUM_INSTRS_COMPLETED],
    input [$clog2(`AL_SIZE)-1:0] completed_idx [`NUM_INSTRS_COMPLETED],
    //active list indices for instructions
    output logic [$clog2(`AL_SIZE)-1:0] al_idx [2],
    //if stall
    output logic int_stall,
    //outputs for graduated instructions
    output logic [5:0] free_phys_reg,
    output logic free_phys_reg_valid,
    //outputs for determining if you flush
    output logic [$clog2(`AL_SIZE)-1:0] al_front_ptr, al_back_ptr
    //outputs for checkpoint
    //output [$clog2(`AL_SIZE)-1:0] checkpoint_al_back <-- shouldnt be needed in checkpoint
    );
    
    logic [10:0] al_entry [`AL_SIZE];
    logic al_done [`AL_SIZE];
    logic [$clog2(`AL_SIZE)-1:0] al_front, al_back;
    logic [$clog2(`AL_SIZE):0] al_size;
    assign al_front_ptr = al_front;
    assign al_back_ptr = al_back;
    
    logic stall;
    assign stall = ext_stall || ((al_size + valid_instr[0] + valid_instr[1]) >= `AL_SIZE) || recall_checkpoint;
    assign int_stall = ((al_size + valid_instr[0] + valid_instr[1]) >= `AL_SIZE) || recall_checkpoint;
    
    always_comb begin
        al_idx[0] = 0;
        al_idx[1] = 0;
        if(~stall) begin
            if(valid_instr[0] && valid_instr[1]) begin
                al_idx[0] = al_front + 1;
                al_idx[1] = al_front + 2;
            end else if(valid_instr[0]) begin
                al_idx[0] = al_front + 1;
            end else if(valid_instr[1]) begin
                al_idx[1] = al_front + 1;
            end
        end
    end
    
    assign free_phys_reg_valid = al_done[al_back];
    assign free_phys_reg = al_entry[al_back][5:0];
    
    always_ff @(posedge clk) begin
        if(reset) begin
            al_front <= 0;
            al_back <= 0;
            al_size <= 0;
        end else begin
            //mark entries as done as necessary
            for(int i = 0; i < `NUM_INSTRS_COMPLETED; i++) begin
                if(completed_valid[i]) begin
                    al_done[completed_idx[i]] <= 1;
                end
            end
            
            if(recall_checkpoint) begin
                al_front <= new_front;
                al_size <= (new_front > al_back) ? (new_front - al_back) : (new_front - al_back + `AL_SIZE);
                if(al_done[al_back]) begin
                    al_back <= al_back + 1;
                end
            end else if(~stall) begin
                //handle allocating new entries and updating the size of it
                if(valid_instr[0] && valid_instr[1]) begin
                    al_done[al_front + 1] <= 0;
                    al_done[al_front + 2] <= 0;
                    al_entry[al_front + 1] <= {arch_rd[0], phys_rd[0]};
                    al_entry[al_front + 2] <= {arch_rd[1], phys_rd[1]};
                    if(al_done[al_back]) begin
                        al_back <= al_back + 1;
                        al_size <= al_size + 1;
                    end else begin
                        al_size <= al_size + 2;
                    end
                end else if(valid_instr[0]) begin
                    al_done[al_front + 1] <= 0;
                    al_entry[al_front + 1] <= {arch_rd[0], phys_rd[0]};
                    if(al_done[al_back]) begin
                        al_back <= al_back + 1;
                        al_size <= al_size;
                    end else begin
                        al_size <= al_size + 1;
                    end
                end else if(valid_instr[1]) begin
                    al_done[al_front + 1] <= 0;
                    al_entry[al_front + 1] <= {arch_rd[1], phys_rd[1]};
                    if(al_done[al_back]) begin
                        al_back <= al_back + 1;
                        al_size <= al_size;
                    end else begin
                        al_size <= al_size + 1;
                    end
                end else begin
                    if(al_done[al_back]) begin
                        al_back <= al_back + 1;
                        al_size <= al_size - 1;
                    end else begin
                        al_size <= al_size;
                    end
                end
            end else begin
                if(al_done[al_back]) begin
                    al_back <= al_back + 1;
                    al_size <= al_size - 1;
                end else begin
                    al_size <= al_size;
                end
            end
        end
    end
    
    
endmodule
