`timescale 1ns / 1ps
`include "riscv_core.svh"

module rename_stage(
    input clk, reset,
    ext_stall, ext_flush,
    decode_out_ifc.in i_decode [2],
    branch_fb_ifc.in i_branch_fb [`NUM_BRANCHES_RESOLVED],
    
    wb_ifc.in i_wb [4],
    rename_out_ifc.out o_renamed [2],
    output logic [$clog2(`AL_SIZE)-1:0] oldest_branch_al_addr,
    output logic int_stall,
    output logic [$clog2(`AL_SIZE)-1:0] al_front_ptr_reg, al_back_ptr_reg
    );
    /*
    Formats for renaming:
    2 non-branch instructions - 1 cycle
    1 branch, 1 non-branch - 1 cycle
    2 branch instructions - 2 cycles
    1 non-branch, 1 branch - 1 cycle
    
    If it takes 2 cycles, it will stall until the instructions are processed, while renaming them one at a time
    */
    
    logic int_stall_fl, int_stall_cp, int_stall_al, int_stall_rmt; //int_stall rmt SHOULD NOT be conncect to overall
    logic int_stall_overall;
    assign int_stall_overall = int_stall_fl || int_stall_cp || int_stall_al;
    
    
    //nets used from decoded instruction
    logic valid_instr [2];
    logic psm_valid_instr [2];
    logic uses_rd [2];
    logic if_branch [2];
    logic [4:0] rd [2];
    logic [4:0] rs1 [2];
    logic [4:0] rs2 [2];
    logic [`ADDR_WIDTH-1:0] pc_al [2];
    assign valid_instr[0] = i_decode[0].valid;
    assign valid_instr[1] = i_decode[1].valid;
    assign uses_rd[0] = i_decode[0].uses_rd;
    assign uses_rd[1] = i_decode[1].uses_rd;
    assign if_branch[0] = i_decode[0].is_branch;
    assign if_branch[1] = i_decode[1].is_branch;
    assign rd[0] = i_decode[0].rd;
    assign rd[1] = i_decode[1].rd;
    assign rs1[0] = i_decode[0].rs1;
    assign rs1[1] = i_decode[1].rs1;
    assign rs2[0] = i_decode[0].rs2;
    assign rs2[1] = i_decode[1].rs2;
    
    //nets outputted from rmt
    logic [$clog2(`NUM_PR)-1:0] phys_rs1 [2];
    logic [$clog2(`NUM_PR)-1:0] phys_rs2 [2];
    logic [$clog2(`NUM_PR)-1:0] old_phys_rd [2];
    logic [$clog2(`NUM_PR)-1:0] checkpointed_rmt [32];
    
    //nets from wb
    logic wb_valid [`NUM_INSTRS_COMPLETED];
    logic [$clog2(`AL_SIZE)-1:0] wb_al_idx [`NUM_INSTRS_COMPLETED];
    genvar i;
    generate
        for(i = 0; i < `NUM_INSTRS_COMPLETED; i++) begin
            assign wb_valid[i] = i_wb[i].valid;
            assign wb_al_idx[i] = i_wb[i].al_idx;
        end
        for(i = 0; i < 2; i++) begin
            assign pc_al[i] = i_decode[i].pc;
        end
    endgenerate
    
    //nets from free list
    logic make_checkpoint [2];
    logic [$clog2(`NUM_PR)-1:0] checkpointed_front_ptr;
    logic [$clog2(`NUM_PR)-1:0] allocated_regs [2];
    
    //nets from active list
    logic [$clog2(`AL_SIZE)-1:0] al_idx [2];
    logic [$clog2(`NUM_PR)-1:0] freed_phys_reg;
    logic freed_phys_reg_valid;
    logic [$clog2(`AL_SIZE)-1:0] al_front_ptr, al_back_ptr;
    
    localparam LINE_SIZE = $clog2(`AL_SIZE) + $clog2(`NUM_PR) + $clog2(`NUM_PR)*32 + 64;
    //nets used from checkpointer
    logic [$clog2(`AL_SIZE)-1:0] to_checkpoint_al_front;
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] recalled_id;
    logic if_recall;
    logic validate [`NUM_BRANCHES_RESOLVED];
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] validated_id [`NUM_BRANCHES_RESOLVED];
    logic [LINE_SIZE-1:0] recalled_line;
    logic [$clog2(`NUM_PR)-1:0] recalled_fl_front;
    logic [$clog2(`AL_SIZE)-1:0] recalled_al_front;
    logic [$clog2(`NUM_PR)-1:0] recalled_RMT_copy [32];
    logic [`NUM_PR-1:0] recalled_bbt;
    logic [$clog2(`AL_SIZE)-1:0] oldest_al;
    logic no_checkpoints;
    logic [$clog2(`NUM_CHECKPOINTS)-1:0] cp_addr;
    assign if_recall = i_branch_fb[0].if_branch && ~i_branch_fb[0].if_prediction_correct;
    assign recalled_id = i_branch_fb[0].cp_addr;
    assign recalled_fl_front = recalled_line[$clog2(`NUM_PR)-1:0];
    assign recalled_al_front = recalled_line[$clog2(`AL_SIZE)-1+$clog2(`NUM_PR):$clog2(`NUM_PR)];
    assign recalled_bbt = recalled_line[$clog2(`AL_SIZE)+$clog2(`NUM_PR)+`NUM_PR-1:$clog2(`AL_SIZE)+$clog2(`NUM_PR)];
    generate
        for(i = 0; i < 32; i++) begin
            assign recalled_RMT_copy[i] = recalled_line[i*$clog2(`NUM_PR)+64+$clog2(`AL_SIZE)+$clog2(`NUM_PR)+:$clog2(`NUM_PR)];
        end
        for(i = 0; i < `NUM_BRANCHES_RESOLVED; i++) begin
            assign validate[i] = i_branch_fb[i].if_branch && i_branch_fb[i].if_prediction_correct;
            assign validated_id[i] = i_branch_fb[i].cp_addr;
        end
    endgenerate
    
    
    //nets used for bbt
    logic busify [2];
    logic done [`NUM_INSTRS_COMPLETED];
    logic [$clog2(`NUM_PR)-1:0] done_addr [`NUM_INSTRS_COMPLETED];
    logic [63:0] expected_bbt;
    generate
        for(i = 0; i < `NUM_INSTRS_COMPLETED; i++) begin
            assign done[i] = i_wb[i].uses_rd && i_wb[i].valid;
            assign done_addr[i] = i_wb[i].rd;
        end
    endgenerate
    
    
    assign int_stall = int_stall_overall || ext_stall;
    assign oldest_branch_al_addr = oldest_al;
    
    
    //--------------------------------------STATE MACHINE TO AVOID DOUBLE BRANCHES-------------------------------------    
    typedef enum logic [1:0] {
        NORMAL=2'b00,
        BRANCH_ONE=2'b01,
        BRANCH_TWO=2'b10
    } state;
    
    state cur_state; 
    always_comb begin
        if(if_branch[0] && if_branch[1] && valid_instr[0] && valid_instr[1] || (cur_state == BRANCH_ONE)) begin
            make_checkpoint[0] = 1;
            make_checkpoint[1] = 0;
            psm_valid_instr[0] = 1;
            psm_valid_instr[1] = 0;
            to_checkpoint_al_front = al_idx[0];
        end else if(cur_state == BRANCH_TWO) begin
            make_checkpoint[0] = 0;
            make_checkpoint[1] = 1;
            psm_valid_instr[0] = 0;
            psm_valid_instr[1] = 1;
            to_checkpoint_al_front = al_idx[1];
        end else begin
            make_checkpoint[0] = if_branch[0];
            make_checkpoint[1] = if_branch[1];
            psm_valid_instr[0] = valid_instr[0];
            psm_valid_instr[1] = valid_instr[1];
            if(if_branch[0]) begin
                to_checkpoint_al_front = al_idx[0];
            end else begin
                to_checkpoint_al_front = al_idx[1];
            end
        end  
    end
    
    always_ff @(posedge clk) begin
        if(~ext_stall && ~int_stall_overall && ~if_recall) begin
            if((cur_state == NORMAL) && (if_branch[0] && if_branch[1] && valid_instr[0] && valid_instr[1])) begin
                cur_state <= BRANCH_ONE;
            end else if(cur_state == BRANCH_ONE) begin
                cur_state <= BRANCH_TWO;
            end else if(cur_state == BRANCH_TWO) begin
                cur_state <= NORMAL;
            end
        end else if(if_recall) begin
            cur_state <= NORMAL;
        end
    end
    
    assign busify[0] = psm_valid_instr[0] && uses_rd[0];
    assign busify[1] = psm_valid_instr[1] && uses_rd[1];
    
    
    //--------------------------------------INSTANCES OF VARIOUS MODULES-------------------------------------    

    active_list ACTIVE_LIST(
        .clk, .reset,
        .i_wb,
        .pc(pc_al),
        .ext_stall(ext_stall || int_stall_overall),
        .valid_instr(psm_valid_instr),
        .uses_rd,
        .phys_rd(allocated_regs),
        .arch_rd(rd),
        .recall_checkpoint(if_recall),
        .new_front(recalled_al_front),
        .completed_valid(wb_valid),
        .completed_idx(wb_al_idx),
        .al_idx(al_idx),
        .int_stall(int_stall_al),
        .free_phys_reg(freed_phys_reg),
        .free_phys_reg_valid(freed_phys_reg_valid),
        .al_front_ptr,
        .al_back_ptr
    );
    
    free_list FREE_LIST(
        .clk, .reset,
        .ext_stall(ext_stall || int_stall_overall),
        .uses_rd,
        .valid(psm_valid_instr),
        .if_recall,
        .recalled_front_ptr(recalled_fl_front),
        .if_freed(freed_phys_reg_valid),
        .freed_reg(freed_phys_reg),
        .make_checkpoint,
        .checkpointed_front_ptr,
        .allocated_regs,
        .int_stall(int_stall_fl)
    );
    
    register_mapping_table RMT(
        .clk, .reset,
        .ext_stall(ext_stall || int_stall_overall),
        .valid_instr(psm_valid_instr),
        .rs1,
        .rs2,
        .valid_new_rd(uses_rd),
        .rd,
        .phys_rd(allocated_regs),
        .if_checkpoint(make_checkpoint),
        .checkpointed_rmt,
        .if_recall,
        .recalled_rmt(recalled_RMT_copy),
        .phys_rs1,
        .phys_rs2,
        .old_rd(old_phys_rd),
        .int_stall(int_stall_rmt)
    );
    
    busy_bit_table BBT(
        .clk, .reset,
        .busify,
        .busy_addr(allocated_regs),
        .ext_stall(ext_stall || int_stall_overall),
        .done,
        .done_addr,
        .if_recall,
        .recalled_list(recalled_bbt),
        .expected_list(expected_bbt)
    );
    
    checkpointer CHECKPOINTER(
        .clk(clk), .reset(reset),
        .ext_stall(ext_stall || int_stall_overall),
        .validate(validate),
        .validated_id(validated_id),
        .recall_checkpoint(if_recall),
        .recall_id(recalled_id),
        .if_branch(make_checkpoint),
        .instrs_valid(psm_valid_instr),
        .fl_front(checkpointed_front_ptr),
        .al_front(to_checkpoint_al_front),
        .RMT_copy(checkpointed_rmt),
        .bbt(expected_bbt),
        .recalled_data(recalled_line),
        .int_stall(int_stall_cp),
        .oldest_al(oldest_al),
        .no_checkpoints(no_checkpoints),
        .cp_addr(cp_addr)
    );
    
        generate
        for(i = 0; i < 2; i++) begin
            always_ff @(posedge clk) begin
                if(reset) begin
                    o_renamed[i].valid <= 0;
                    o_renamed[i].pc <= 0;
                    o_renamed[i].uses_rd <= 0;
                    o_renamed[i].rd <= 0;
                    o_renamed[i].uses_rs1 <= 0;
                    o_renamed[i].rs1 <= 0;
                    o_renamed[i].uses_rs2 <= 0;
                    o_renamed[i].rs2 <= 0;
                    o_renamed[i].uses_imm <= 0;
                    o_renamed[i].rs1_ready <= 0;
                    o_renamed[i].rs2_ready <= 0;
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
                    o_renamed[i].al_addr <= 0;
                    o_renamed[i].cp_addr <= 0;
                end else if(~ext_stall) begin
                    o_renamed[i].valid <= psm_valid_instr[i];
                    o_renamed[i].pc <= i_decode[i].pc;
                    o_renamed[i].uses_rd <= i_decode[i].uses_rd;
                    o_renamed[i].rd <= allocated_regs[i];
                    o_renamed[i].uses_rs1 <= i_decode[i].uses_rs1;
                    o_renamed[i].rs1 <= phys_rs1[i];
                    o_renamed[i].uses_rs2 <= i_decode[i].uses_rs2;
                    o_renamed[i].rs2 <= phys_rs2[i];
                    o_renamed[i].uses_imm <= i_decode[i].uses_imm;
                    o_renamed[i].rs1_ready <= expected_bbt[phys_rs1[i]];
                    o_renamed[i].rs2_ready <= expected_bbt[phys_rs2[i]];
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
                    o_renamed[i].al_addr <= al_idx[i];
                    o_renamed[i].cp_addr <= cp_addr;
                end
            end
        end
    endgenerate
    
    always_ff @(posedge clk) begin
        al_front_ptr_reg <= al_front_ptr;
        al_back_ptr_reg <= al_back_ptr;
    end
endmodule
