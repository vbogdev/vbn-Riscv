`timescale 1ns / 1ps
`include "riscv_core.svh"
module improved_reg_read_stage #(
    parameter NUM_BRAMS=4,
    parameter NUM_READS=8,
    parameter NUM_WRITES=2,
    parameter NUM_ARITH=2,
    parameter NUM_MEM=2,
    parameter NUM_ZISC=1,
    parameter NUM_FLOAT=1
    )(
    input clk, reset,
    input ext_stall,
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    aiq_ifc.in i_arith [2],
    miq_ifc.in i_miq [2],
    wb_ifc.in i_wb [6],
    aiq_ifc.out o_arith [2],
    //aiq_ifc.out o_miq [2],
    //reg_out_ifc.out o_regs [2]
    output logic [31:0] read_data_regs [12],
    output logic ready
    );
    
    localparam NUM_READ_INPUTS=(NUM_ARITH+NUM_MEM+NUM_ZISC+NUM_FLOAT)*2;
    localparam NUM_WRITE_INPUTS=6;
    
    
    //CREATE MASKS THAT CAN BE USED TO CALCULATE THE NUMBER OF INPUTS
    //USED WHEN PLACING STUFF INTO BUFFERS
    //WILL BE USED TO CALCULATE POINTER POSITIONS AND COUNTERS
    logic [5:0] write_mask;
    logic [NUM_READ_INPUTS-1:0] read_mask;
    logic [$clog2(NUM_WRITE_INPUTS):0] num_writes_total, num_writes;
    logic [$clog2(NUM_READ_INPUTS):0] num_reads_total, num_reads;
    logic [NUM_READ_INPUTS-1:0] flushed_mask;
    genvar i;
    generate
        for(i = 0; i < 6; i++) begin
            assign write_mask[i] = i_wb[i].valid && i_wb[i].uses_rd;
        end
        for(i = 0; i < NUM_ARITH; i++) begin
            assign read_mask[i*2] = i_arith[i].uses_rs1 && i_arith[i].valid;
            assign read_mask[i*2+1] = i_arith[i].uses_rs2 && i_arith[i].valid;
        end
        for(i = 0; i < NUM_MEM; i++) begin
            assign read_mask[i*2+NUM_ARITH*2] = i_miq[i].uses_rs1 && i_miq[i].valid;
            assign read_mask[i*2+NUM_ARITH*2+1] = i_miq[i].uses_rs2 && i_miq[i].valid;
        end
        
        //only use 4 of the read ports, rest are invalid for now
        for(i = 0; i < 2; i++) begin
            assign read_mask[i*2+8] = 0;
            assign read_mask[i*2+9] = 0;
        end
        //*****************WHEN TESTING FOR ZISCR AND POSSIBLY FLOATING POINT USE THE THING A MA WHATSIT (add another for loop in the generate)************************
    endgenerate
    
    logic new_inputs, prev_new_inputs;

    always_comb begin
        num_reads_total = read_mask[0] + read_mask[1] + read_mask[2] + read_mask[3] + read_mask[4] + read_mask[5] + 
            read_mask[6] + read_mask[7] + read_mask[8] + read_mask[9] + read_mask[10] + read_mask[11];
        num_writes_total = write_mask[0] + write_mask[1] + write_mask[2] + write_mask[3] + write_mask[4] + write_mask[5];
    end
    
    logic [$clog2(`NUM_PR)-1:0] read_addr_list [12];
    logic [$clog2(`NUM_PR)-1:0] write_addr_list [6];
    logic [31:0] write_data_list [6];
    always_comb begin
        read_addr_list[0] = i_arith[0].rs1;
        read_addr_list[1] = i_arith[0].rs2;
        read_addr_list[2] = i_arith[1].rs1;
        read_addr_list[3] = i_arith[1].rs2;
        read_addr_list[4] = i_miq[0].rs1;
        read_addr_list[5] = i_miq[0].rs2;
        read_addr_list[6] = i_miq[1].rs1;
        read_addr_list[7] = i_miq[1].rs2;
        read_addr_list[8] = 0;
        read_addr_list[9] = 0;
        read_addr_list[10] = 0;
        read_addr_list[11] = 0;
        write_addr_list[0] = i_wb[0].rd;
        write_addr_list[1] = i_wb[1].rd;
        write_addr_list[2] = i_wb[2].rd;
        write_addr_list[3] = i_wb[3].rd;
        write_addr_list[4] = i_wb[4].rd;
        write_addr_list[5] = i_wb[5].rd;
        write_data_list[0] = i_wb[0].data;
        write_data_list[1] = i_wb[1].data;
        write_data_list[2] = i_wb[2].data;
        write_data_list[3] = i_wb[3].data;
        write_data_list[4] = i_wb[4].data;
        write_data_list[5] = i_wb[5].data;
    end
    
    //when new inputs is high, some extra stuff is need to setup handling multiple requests over several cycles
    always_ff @(posedge clk) begin
    
        prev_new_inputs <= new_inputs;
        
        if(reset) begin
            new_inputs <= 1;
        end else begin
            if(new_inputs) begin //new incoming requests
                if((num_reads_total == 0) && (num_writes_total == 2)) begin
                    new_inputs <= 1;
                end else if((num_reads_total <= NUM_BRAMS) && (num_writes_total == 1)) begin
                    new_inputs <= 1;
                end else if((num_reads_total <= NUM_BRAMS*2) && (num_writes_total == 0)) begin
                    new_inputs <= 1;
                end else begin
                    new_inputs <= 0;
                end
            end else begin //no change in requests handled
                if((num_reads == 0) && (num_writes == 2)) begin
                    new_inputs <= 1;
                end else if((num_reads <= NUM_BRAMS) && (num_writes == 1)) begin
                    new_inputs <= 1;
                end else if((num_reads <= NUM_BRAMS*2) && (num_writes == 0)) begin
                    new_inputs <= 1;
                end else begin
                    new_inputs <= 0;
                end
            end
        end
    end
    
    assign ready = new_inputs && ~ext_stall;
    
    
    logic [3:0] r_selected_id [NUM_READS];
    logic [2:0] w_selected_id [NUM_WRITES];
    
    logic [31:0] intermediate_read_storage [NUM_READ_INPUTS]; //CHANGE THIS IF NECESSARY AS ARCHITECTURE CHANGES ************************************************************
    logic [$clog2(`AL_SIZE)-1:0] al_idxs [NUM_WRITE_INPUTS]; //al_idxs[i] corresponds to read_buffer[2 * i (+1)]
    logic [NUM_READ_INPUTS-1:0] read_instr_valid; 
    //logic [$clog2(`NUM_PR)-1:0] read_buffer [NUM_READS];
    logic [NUM_READ_INPUTS-1:0] read_valid_regs, read_valid_mask;
    //logic [$clog2(`NUM_PR)-1:0] write_buffer [NUM_WRITES];
    logic [NUM_WRITE_INPUTS-1:0] write_valid_regs, write_valid_mask;
    
    always_comb begin
        read_instr_valid[0] = i_arith[0].valid;
        read_instr_valid[1] = i_arith[1].valid;
        read_instr_valid[2] = i_miq[0].valid;
        read_instr_valid[3] = i_miq[1].valid;
        read_instr_valid[4] = 0;
        read_instr_valid[5] = 0;
    end
    
    //***********************HANDLE SELECTING WHICH INCOMING REQUESTS TO HANDLE*****************************************
    //REQUESTS REFER TO VALID REG READS/WRITES
    logic [NUM_READ_INPUTS-1:0] read_done_mask, read_done_regs;
    logic [NUM_WRITE_INPUTS-1:0] write_done_mask, write_done_regs;
    
    //since it takes 1 cycle to updated the regs, the first cycle will use either the incoming mask or 0 (as no requests are completed at the start)
    assign write_done_mask = (new_inputs) ? 0 : write_done_regs;
    assign read_done_mask = (new_inputs) ? 0 : read_done_regs;
    assign write_valid_mask = (new_inputs) ? write_mask : write_valid_regs;
    assign read_valid_mask = (new_inputs) ? read_mask : read_valid_regs;
    
    rf_selector_module RFSM(
        .r_read_mask(read_valid_mask),
        .r_done_mask(read_done_mask),
        .r_selected_id,
        .w_read_mask(write_valid_mask),
        .w_done_mask(write_done_mask),
        .w_selected_id
    );
    
    
    undo_checkpoint_module #(.DEPTH(NUM_WRITE_INPUTS)) UCM (
        .new_front, .old_front, .back,
        .list(al_idxs),
        .i_valid(read_instr_valid),
        .flush_mask(flushed_mask)
    );
    
    always_ff @(posedge clk) begin
    
        if(new_inputs) begin
            //initialize valid masks
            for(int j = 0; j < 12; j++) begin
                if(flushed_mask[j]) begin
                    read_valid_regs[j] <= 0;
                end else begin
                    read_valid_regs[j] <= read_mask[j];
                end
            end
            for(int j = 0; j < 6; j++) begin
                write_valid_regs[j] <= write_mask[j];
            end 
            
            //update num_writes/reads and write/read_done_regs
            if(num_writes_total >= 2) begin
                num_writes <= num_writes_total - 2;
                num_reads <= num_reads_total;
                
                for(int j = 0; j < 6; j++) begin
                    if((j == w_selected_id[0]) || (j == w_selected_id[1])) begin
                        write_done_regs[j] <= 1;
                    end else begin
                        write_done_regs[j] <= 0;
                    end
                end
                for(int j = 0; j < 12; j++) begin
                    read_done_regs[j] <= 0;
                end
            end else if(num_writes_total == 1) begin
                num_writes <= 0;
                if(num_reads_total >= NUM_BRAMS) begin
                    num_reads <= num_reads_total - NUM_BRAMS;
                end else begin
                    num_reads <= 0;
                end
                
                for(int j = 0; j < 6; j++) begin
                    if(j == w_selected_id[0]) begin
                        write_done_regs[j] <= 1;
                    end else begin
                        write_done_regs[j] <= 0;
                    end
                end
                for(int j = 0; j < 12; j++) begin
                    if((j == r_selected_id[0]) || (j == r_selected_id[1]) || 
                        (j == r_selected_id[2]) || (j == r_selected_id[3])) begin
                        read_done_regs[j] <= 1;
                    end else begin
                        read_done_regs[j] <= 0;
                    end
                end
            end else begin
                num_writes <= 0;
                if(num_reads_total >= NUM_BRAMS*2) begin
                    num_reads <= num_reads_total - NUM_BRAMS*2;
                end else begin
                    num_reads <= 0;
                end
                
                for(int j = 0; j < 12; j++) begin
                    if((j == r_selected_id[0]) || (j == r_selected_id[1]) || 
                        (j == r_selected_id[2]) || (j == r_selected_id[3]) ||
                        (j == r_selected_id[4]) || (j == r_selected_id[5]) || 
                        (j == r_selected_id[6]) || (j == r_selected_id[7])) begin
                        read_done_regs[j] <= 1;
                    end else begin
                        read_done_regs[j] <= 0;
                    end
                end
            end
            
        end else begin
            if(num_writes >= 2) begin
                num_writes <= num_writes - 2;
                num_reads <= num_reads;
                
                for(int j = 0; j < 6; j++) begin
                    if((j == w_selected_id[0]) || (j == w_selected_id[1])) begin
                        write_done_regs[j] <= 1;
                    end else begin
                        write_done_regs[j] <= 0;
                    end
                end
            end else if(num_writes == 1) begin
                num_writes <= 0;
                if(num_reads >= NUM_BRAMS) begin
                    num_reads <= num_reads - NUM_BRAMS;
                end else begin
                    num_reads <= 0;
                end
                
                for(int j = 0; j < 6; j++) begin
                    if(j == w_selected_id[0]) begin
                        write_done_regs[j] <= 1;
                    end else begin
                        write_done_regs[j] <= 0;
                    end
                end
                for(int j = 0; j < 12; j++) begin
                    if((j == r_selected_id[0]) || (j == r_selected_id[1]) || 
                        (j == r_selected_id[2]) || (j == r_selected_id[3])) begin
                        read_done_regs[j] <= 1;
                    end else begin
                        read_done_regs[j] <= read_done_regs[j];
                    end
                end
            end else begin
                num_writes <= 0;
                if(num_reads >= NUM_BRAMS*2) begin
                    num_reads <= num_reads - NUM_BRAMS*2;
                end else begin
                    num_reads <= 0;
                end
                
                for(int j = 0; j < 12; j++) begin
                    if((j == r_selected_id[0]) || (j == r_selected_id[1]) || 
                        (j == r_selected_id[2]) || (j == r_selected_id[3]) ||
                        (j == r_selected_id[4]) || (j == r_selected_id[5]) || 
                        (j == r_selected_id[6]) || (j == r_selected_id[7])) begin
                        read_done_regs[j] <= 1;
                    end else begin
                        read_done_regs[j] <= read_done_regs[j];
                    end
                end
            end
        end        
    end


    //HANDLE INPUTS TO BRAMS HERE
    logic [1:0] mode, last_mode;
    logic [$clog2(`NUM_PR)-1:0] write_addr [2];
    logic [31:0] write_data [2];
    logic [$clog2(`NUM_PR)-1:0] read_addr [NUM_BRAMS*2];
    logic [31:0] read_data [NUM_BRAMS*2];
    
    logic [3:0] last_index_read [NUM_BRAMS*2];
    
    always_ff @(posedge clk) begin
        last_mode <= mode;
        for(int j = 0; j < NUM_BRAMS*2; j++) begin
            last_index_read[j] <= r_selected_id[j];        
        end
        if(last_mode == 2'b01) begin
            for(int j = 0; j < NUM_BRAMS; j++) begin
                read_data_regs[last_index_read[j]] <= read_data[j];
            end
        end else if(last_mode == 2'b10) begin
            for(int j = 0; j < NUM_BRAMS*2; j++) begin
                read_data_regs[last_index_read[j]] <= read_data[j];
            end
        end
    end
    
    always_comb begin
        if(new_inputs) begin
            if(num_writes_total >= 2) begin
                mode = 2'b00;
                write_addr[0] = write_addr_list[w_selected_id[0]];
                write_addr[1] = write_addr_list[w_selected_id[1]];
                write_data[0] = write_data_list[w_selected_id[0]];
                write_data[1] = write_data_list[w_selected_id[1]];
                for(int j = 0; j < NUM_BRAMS*2; j++) begin
                    read_addr[j] = 0;
                end
            end else if(num_writes_total == 1) begin
                mode = 2'b01;
                write_addr[0] = write_addr_list[w_selected_id[0]];
                write_data[0] = write_data_list[w_selected_id[0]];
                write_addr[1] = 0;
                write_data[1] = 0;
                for(int j = 0; j < NUM_BRAMS; j++) begin
                    read_addr[j] = read_addr_list[r_selected_id[j]];
                end
                for(int j = NUM_BRAMS; j < NUM_BRAMS*2; j++) begin
                    read_addr[j] = 0;
                end
            end else begin
                mode = 2'b10;
                write_addr[0] = 0;
                write_addr[1] = 0;
                write_data[0] = 0;
                write_data[1] = 0;
                for(int j = 0; j < NUM_BRAMS*2; j++) begin
                    read_addr[j] = read_addr_list[r_selected_id[j]];
                end
            end
        end else begin
            if(num_writes >= 2) begin
                mode = 2'b00;
                write_addr[0] = write_addr_list[w_selected_id[0]];
                write_addr[1] = write_addr_list[w_selected_id[1]];
                for(int j = 0; j < NUM_BRAMS*2; j++) begin
                    read_addr[j] = 0;
                end
            end else if(num_writes == 1) begin
                mode = 2'b01;
                write_addr[0] = write_addr_list[w_selected_id[0]];
                write_addr[1] = 0;
                for(int j = 0; j < NUM_BRAMS; j++) begin
                    read_addr[j] = read_addr_list[r_selected_id[j]];
                end
                for(int j = NUM_BRAMS; j < NUM_BRAMS*2; j++) begin
                    read_addr[j] = 0;
                end
            end else begin
                mode = 2'b10;
                write_addr[0] = 0;
                write_addr[1] = 0;
                for(int j = 0; j < NUM_BRAMS*2; j++) begin
                    read_addr[j] = read_addr_list[r_selected_id[j]];
                end
            end
        end
    end
    

    multi_bram_reg_file #(
        .NUM_BRAMS(NUM_BRAMS)
    ) MBRF (.*);
    
    logic prev_valid [6];
    logic [`ADDR_WIDTH-1:0] prev_pc [6];
    logic prev_uses_rs1 [6];
    logic prev_uses_rs2 [6];
    logic prev_uses_rd [6];
    logic [31:0] prev_imm [6];
    logic [$clog2(`NUM_PR)-1:0] prev_rd [6];
    logic prev_uses_imm [6];
    logic [$clog2(`AL_SIZE)-1:0] prev_al_addr [6];
    
    riscv_pkg::AluCtl prev_alu_operation [2];
    logic [`ADDR_WIDTH-1:0] prev_target [2];
    logic prev_is_branch [2];
    logic prev_is_jump [2];
    logic prev_is_jump_register [2];
    riscv_pkg::funct3_branch prev_branch_op [2];
    riscv_pkg::BranchOutcome prev_prediction [2];
    logic prev_cp_addr [2];
    
    logic prev_is_mem_access [2];
    riscv_pkg::MemAccessType prev_mem_access_type [2];
    riscv_pkg::MemWidth prev_width [2];
    
    
    logic next_cycle_step;
    assign next_cycle_step = ((new_inputs && (num_writes_total == 2) && (num_reads_total == 0)) || (new_inputs && 
            (num_writes_total == 1) && (num_reads_total <= NUM_BRAMS)) || (new_inputs && (num_writes_total == 0) 
            && (num_reads_total <= NUM_BRAMS*2)) || (~new_inputs && (num_writes == 2) && (num_reads == 0)) || 
            (~new_inputs && (num_writes == 1) && (num_reads <= NUM_BRAMS)) || (~new_inputs && (num_writes == 0) && 
            (num_reads <= NUM_BRAMS*2))) && ~ext_stall;
            
    generate
        for(i = 0; i < NUM_ARITH; i++) begin
            always_ff @(posedge clk) begin
                if(next_cycle_step) begin
                    prev_valid[i] <= i_arith[i].valid;
                    prev_pc[i] <= i_arith[i].pc;
                    prev_uses_rs2[i] <= i_arith[i].uses_rs2;
                    prev_uses_rs1[i] <= i_arith[i].uses_rs2;
                    prev_uses_rd[i] <= i_arith[i].uses_rd;
                    prev_uses_imm[i] <= i_arith[i].uses_imm;
                    prev_imm[i] <= i_arith[i].imm;
                    prev_rd[i] <= i_arith[i].rd;
                    prev_al_addr[i] <= i_arith[i].al_addr;
                    
                    prev_alu_operation[i] <= i_arith[i].alu_operation;
                    prev_target[i] <= i_arith[i].target;
                    prev_is_branch[i] <= i_arith[i].is_branch;
                    prev_is_jump[i] <= i_arith[i].is_jump;
                    prev_is_jump_register[i] <= i_arith[i].is_jump_register;
                    prev_branch_op[i] <= i_arith[i].branch_op;
                    prev_prediction[i] <= i_arith[i].prediction;
                    prev_cp_addr[i] <= i_arith[i].cp_addr;
                end
            end
        end
        
        for(i = 0; i < NUM_WRITES; i++) begin
            always_ff @(posedge clk) begin
                if(next_cycle_step) begin
                    prev_valid[i+NUM_ARITH] <= i_miq[i].valid;
                    prev_pc[i+NUM_ARITH] <= i_miq[i].pc;
                    prev_uses_rs2[i+NUM_ARITH] <= i_miq[i].uses_rs2;
                    prev_uses_rs1[i+NUM_ARITH] <= i_miq[i].uses_rs2;
                    prev_uses_rd[i+NUM_ARITH] <= i_miq[i].uses_rd;
                    prev_uses_imm[i+NUM_ARITH] <= i_miq[i].uses_imm;
                    prev_imm[i+NUM_ARITH] <= i_miq[i].imm;
                    prev_rd[i+NUM_ARITH] <= i_miq[i].rd;
                    prev_al_addr[i+NUM_ARITH] <= i_miq[i].al_addr;
                    
                    prev_is_mem_access[i] <= i_miq[i].is_mem_access;
                    prev_mem_access_type[i] <= i_miq[i].mem_access_type;;
                    prev_width[i] <= miq[i].prev_width;
                end
            end
        end
    endgenerate
    
endmodule
