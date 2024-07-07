`timescale 1ns / 1ps

module rename_stage(
    input clk, reset,
    ext_stall, ext_flush,
    decode_out_ifc.in i_decode [2],
    branch_fb_ifc.in i_branch_fb [`NUM_BRANCHES_RESOLVED],
    
    wb_ifc.in i_wb [`NUM_INSTRS_COMPLETED],
    rename_out_ifc.out o_renamed [2],
    output logic int_stall
    );
    /*
    ENSURE STALLING BECAUSE INDIVIDUAL COMPONENTS ARE FULL/EMPTY WORKS
    CURRENTLY IT SHOULD ONLY WORK WITH AN EXTERNAL STALL
    INTERNAL STALLS CREATE A PERMANENT LOOP I THINK
    */
    /*
    Formats for renaming:
    2 non-branch instructions - 1 cycle
    1 branch, 1 non-branch - 1 cycle
    2 branch instructions - 2 cycles
    1 non-branch, 1 branch - 1 cycle
    
    If it takes 2 cycles, it will stall until the instructions are processed, while renaming them one at a time
    */
    logic two_cycle_rename; 
    logic instrs_left_to_rename; //should be high during the second instruction renamed
    logic instrs_valid [2];
    assign two_cycle_rename = (i_decode[0].valid && i_decode[0].is_branch && i_decode[1].valid && i_decode[1].is_branch) && ~instrs_left_to_rename; //should be high during first instruction renamed
    assign instrs_valid[0] = two_cycle_rename ? ~instrs_left_to_rename : 1;
    assign instrs_valid[1] = two_cycle_rename ? 0 : 1;
    
    logic stall;
    
    always_ff @(posedge clk) begin
        if(reset) begin
        
        end else begin
            if(ext_flush) begin
                instrs_left_to_rename <= 0;
            end else if(~stall) begin
                if(two_cycle_rename && ~instrs_left_to_rename) begin
                    //let through first instr
                    instrs_left_to_rename <= 1;
                end else if(instrs_left_to_rename) begin
                    //left through second instr if possible
                    instrs_left_to_rename <= 0;
                
                end else begin
                    //let through both instrs
                end
            end
        end
    end
    
    logic [4:0] rs1 [2];
    logic [4:0] rs2 [2];
    logic uses_rd [2];
    logic [4:0] rd [2];
    logic [5:0] phys_rd [2];
    logic if_checkpoint [2];
    logic [5:0] checkpointed_rmt [32];
    logic if_recall;
    logic [5:0] recalled_rmt [32];
    logic [5:0] phys_rs1 [2];
    logic [5:0] phys_rs2 [2];
    logic [5:0] old_rd [2];
    logic rmt_stall;
   
    
    logic [$clog2(`AL_SIZE)-1:0] new_al_front;
    logic completed_valid [`NUM_INSTRS_COMPLETED];
    logic [$clog2(`AL_SIZE)-1:0] completed_al_idx [`NUM_INSTRS_COMPLETED];
    logic [$clog2(`AL_SIZE)-1:0] allocated_al_idx [2];
    logic al_stall;
    logic [5:0] free_phys_reg;
    logic free_phys_reg_valid;
    logic [$clog2(`AL_SIZE)-1:0] al_front_ptr, al_back_ptr;
    
    logic [383:0] recalled_fl, checkpointed_fl;
    logic [5:0] recalled_front_fl, recalled_back_fl, checkpointed_front_fl, checkpointed_back_fl;
    logic [6:0] recalled_fl_size, checkpointed_fl_size;
    logic fl_stall;
    
    logic branch_validate [`NUM_BRANCHES_RESOLVED];
    logic [$clog2(`AL_SIZE)-1:0] branch_validated_id [`NUM_BRANCHES_RESOLVED];
    logic if_branch [2];
    logic [5:0] broken_up_free_list [64];
    logic [$clog2(`AL_SIZE)-1:0] checkpointed_al_idx;
    logic [$clog2(`AL_SIZE) * 2 + 6*64 + 7 + 6 + 6 + 6*32 + $clog2(`AL_SIZE)+1-1:0] checkpoint_line;
    logic checkpoint_stall;
    
    
    logic al_ext_stall;
    logic cp_ext_stall;
    logic rmt_ext_stall;
    logic fl_ext_stall;
    logic resource_stall;
    assign new_al_front = i_branch_fb[0].al_addr;
    assign al_ext_stall = ext_stall || checkpoint_stall || fl_stall;
    assign cp_ext_stall = ext_stall || al_stall || fl_stall;
    assign rmt_ext_stall = ext_stall || al_stall || checkpoint_stall || fl_stall;
    assign fl_ext_stall = ext_stall || al_stall || checkpoint_stall;
    assign if_recall = ~i_branch_fb[0].if_prediction_correct;
    assign stall = ext_stall || al_stall || checkpoint_stall || fl_stall;
    assign int_stall = ext_stall || two_cycle_rename || instrs_left_to_rename || al_stall || checkpoint_stall || fl_stall;

    localparam t = $clog2(`AL_SIZE)+403+$clog2(`AL_SIZE)+$clog2(`AL_SIZE)+1;
    always_comb begin
        recalled_fl_size = checkpoint_line[390:384];
        recalled_front_fl = checkpoint_line[396:391];
        recalled_back_fl = checkpoint_line[402:397];
        if(two_cycle_rename || instrs_left_to_rename) begin
            if(two_cycle_rename) begin
                checkpointed_al_idx = allocated_al_idx[0];
            end else begin
                checkpointed_al_idx = allocated_al_idx[1];
            end
        end else begin
            if(if_branch[0]) begin
                checkpointed_al_idx = allocated_al_idx[0];
            end else begin
                checkpointed_al_idx = allocated_al_idx[1];
            end
        end
    end
    genvar i;
    generate

        for(i = 0; i < 2; i++) begin
            assign rs1[i] = i_decode[i].rs1;
            assign rs2[i] = i_decode[i].rs2;
            assign uses_rd[i] = i_decode[i].uses_rd;
            assign rd[i] = i_decode[i].rd;
            assign if_checkpoint[i] = i_decode[i].is_branch || i_decode[i].is_jump_register;
            assign if_branch[i] = i_decode[i].is_branch;
        end
        
        for(i = 0; i < 32; i++) begin
            assign recalled_rmt[i] = checkpoint_line[i*6+t:6];
        end
        
        for(i = 0; i < 64; i++) begin
            assign broken_up_free_list[i] = checkpointed_fl[i*6+:6];
            assign recalled_fl[i*6+:6] = checkpoint_line[i*6+:6];
        end
        
        //assign recalled_front_fl = checkpoint_line[396:391];
        //assign recalled_back_fl = checkpoint_line[402:397];
        
        for(i = 0; i < `NUM_INSTRS_COMPLETED; i++) begin
            assign completed_valid[i] = i_wb[i].valid;
            assign completed_al_idx[i] = i_wb[i].al_idx;
        end
        
        for(i = 0; i < `NUM_BRANCHES_RESOLVED; i++) begin
            assign branch_validate[i] = i_branch_fb[i].if_branch && i_branch_fb[i].if_prediction_correct;
            assign branch_validated_id[i] = i_branch_fb[i].al_addr;
        end
        
    endgenerate
    
    
    register_mapping_table RMT(
        .clk, .reset, .ext_stall(rmt_ext_stall), .ext_flush,
        .valid_instr(instrs_valid),
        .rs1, .rs2, .valid_new_rd(uses_rd),
        .rd, .phys_rd,
        .if_checkpoint,
        .checkpointed_rmt,
        .if_recall,
        .recalled_rmt,
        .phys_rs1, .phys_rs2,
        .old_rd, .int_stall(rmt_stall)
    );
    
    
    active_list ACTIVE_LIST(
        .clk, .reset,
        .ext_flush,
        .ext_stall(al_ext_stall),
        .valid_instr(instrs_valid),
        .uses_rd,
        .phys_rd(old_rd),
        .arch_rd(rd),
        .recall_checkpoint(if_recall),
        .new_front(new_al_front),
        .completed_valid,
        .completed_idx(completed_al_idx),
        .al_idx(allocated_al_idx),
        .int_stall(al_stall),
        .free_phys_reg,
        .free_phys_reg_valid,
        .al_front_ptr,
        .al_back_ptr
    );
    
    
    free_list FREE_LIST(
        .clk, .reset,
        .ext_flush, .ext_stall(fl_ext_stall),
        .uses_rd,
        .valid(instrs_valid),
        .if_recall,
        .recalled_list(recalled_fl),
        .recalled_front_ptr(recalled_front_fl),
        .recalled_back_ptr(recalled_back_fl),
        .recalled_list_size(recalled_fl_size),
        .if_freed(free_phys_reg_valid),
        .freed_reg(free_phys_reg),
        .make_checkpoint(if_checkpoint),
        .checkpointed_list(checkpointed_fl),
        .checkpointed_front_ptr(checkpointed_front_fl),
        .checkpointed_back_ptr(checkpointed_back_fl),
        .checkpointed_list_size(checkpointed_fl_size),
        .allocated_regs(phys_rd),
        .int_stall(fl_stall)
    );
    
    checkpointer CHECKPOINTER(
        .clk, .reset,
        .ext_stall(cp_ext_stall), .ext_flush,
        .validate(branch_validate),
        .validated_id(branch_validated_id),
        .recall_checkpoint(if_recall),
        .recall_id(i_branch_fb[0].al_addr),
        .if_branch,
        .instrs_valid,
        .free_list(broken_up_free_list),
        .fl_size(checkpointed_fl_size),
        .fl_front(checkpointed_front_fl),
        .fl_back(checkpointed_back_fl),
        .al_front(checkpointed_al_idx),
        .al_back(4'b0),
        .al_size(5'b0),
        .RMT_copy(checkpointed_rmt),
        .recalled_data(checkpoint_line),
        .int_stall(checkpoint_stall)
    );
    
    
    
    generate
        for(i = 0; i < 2; i++) begin
            always_ff @(posedge clk) begin
                if(reset) begin
                    o_renamed[i].valid <= 0;
                    o_renamed[i].uses_rd <= 0;
                    o_renamed[i].rd <= 0;
                    o_renamed[i].uses_rs1 <= 0;
                    o_renamed[i].rs1 <= 0;
                    o_renamed[i].uses_rs2 <= 0;
                    o_renamed[i].rs2 <= 0;
                    o_renamed[i].uses_imm <= 0;
                    o_renamed[i].imm <= 0;
                    o_renamed[i].alu_operation <= ALUCTL_ADD;
                    o_renamed[i].is_fp <= 0;
                    o_renamed[i].target <= 0;
                    o_renamed[i].is_branch <= 0;
                    o_renamed[i].is_jump <= 0;
                    o_renamed[i].is_jump_register <= 0;
                    o_renamed[i].branch_op <= BEQ;
                    o_renamed[i].prediction <= TAKEN;
                    o_renamed[i].mem_access_type <= READ;
                    o_renamed[i].is_mem_access <= 0;
                    o_renamed[i].width <= M_B;
                    o_renamed[i].accesses_csr <= 0;
                    o_renamed[i].csr_op <= CSRRW;
                    o_renamed[i].csr_addr <= 0;
                    o_renamed[i].ecall <= 0;
                    o_renamed[i].ebreak <= 0;
                    o_renamed[i].amo_instr <= 0;
                    o_renamed[i].aq <= 0;
                    o_renamed[i].rl <= 0;
                    o_renamed[i].amo_type <= AMO_LR;
                end else if(~ext_stall) begin
                    o_renamed[i].valid <= instrs_valid[i];
                    o_renamed[i].uses_rd <= i_decode[i].uses_rd;
                    o_renamed[i].rd <= phys_rd[i];
                    o_renamed[i].uses_rs1 <= i_decode[i].uses_rs1;
                    o_renamed[i].rs1 <= phys_rs1[i];
                    o_renamed[i].uses_rs2 <= i_decode[i].uses_rs2;
                    o_renamed[i].rs2 <= phys_rs2[i];
                    o_renamed[i].uses_imm <= i_decode[i].uses_imm;
                    o_renamed[i].imm <= i_decode[i].imm;
                    o_renamed[i].alu_operation <= i_decode[i].alu_operation;
                    o_renamed[i].is_fp <= i_decode[i].is_fp;
                    o_renamed[i].target <= i_decode[i].target;
                    o_renamed[i].is_branch <= i_decode[i].is_branch;
                    o_renamed[i].is_jump <= i_decode[i].is_jump;
                    o_renamed[i].is_jump_register <= i_decode[i].is_jump_register;
                    o_renamed[i].branch_op <= i_decode[i].branch_op;
                    o_renamed[i].prediction <= i_decode[i].prediction;
                    o_renamed[i].mem_access_type <= i_decode[i].mem_access_type;
                    o_renamed[i].is_mem_access <= i_decode[i].is_mem_access;
                    o_renamed[i].width <= i_decode[i].width;
                    o_renamed[i].accesses_csr <= i_decode[i].accesses_csr;
                    o_renamed[i].csr_op <= i_decode[i].csr_op;
                    o_renamed[i].csr_addr <= i_decode[i].csr_addr;
                    o_renamed[i].ecall <= i_decode[i].ecall;
                    o_renamed[i].ebreak <= i_decode[i].ebreak;
                    o_renamed[i].amo_instr <= i_decode[i].amo_instr;
                    o_renamed[i].aq <= i_decode[i].aq;
                    o_renamed[i].rl <= i_decode[i].rl;
                    o_renamed[i].amo_type <= i_decode[i].amo_type;
                end
            end
        end
    endgenerate
    
endmodule


