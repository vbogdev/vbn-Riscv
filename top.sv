`timescale 1ns / 1ps


module top(
    input reset,
    input sys_clk_pin,
    input sys_clk_2,
    input [3:0] switches,
    input set,
    input [9:0] inputs,
    output logic [15:0] r1
    );

    
    logic clk, f_clk;

    
    /*main_clock CLK_MANAGER(
        .s_clk(clk),
        .f_clk,
        .reset,
        .clk_in1(sys_clk_pin)
    );*/
    
    //for testing
    assign clk = sys_clk_2;
    assign f_clk = sys_clk_pin;
    
    
    //assign clk = sys_clk_pin;
    
    logic [159:0] reg_inputs, direct_inputs;
    always_ff @(posedge clk) begin
        if(reset) begin
            direct_inputs <= 0;
        end else if(set) begin
            direct_inputs <= reg_inputs;
        end 
        
        case(switches) 
            4'b0000: reg_inputs[9:0] <= inputs;
            4'b0001: reg_inputs[19:10] <= inputs;
            4'b0010: reg_inputs[29:20] <= inputs;
            4'b0011: reg_inputs[39:30] <= inputs;
            4'b0100: reg_inputs[49:40] <= inputs;
            4'b0101: reg_inputs[59:50] <= inputs;
            4'b0110: reg_inputs[69:60] <= inputs;
            4'b0111: reg_inputs[79:70] <= inputs;
            4'b1000: reg_inputs[89:80] <= inputs;
            4'b1001: reg_inputs[99:90] <= inputs;
            4'b1010: reg_inputs[109:100] <= inputs;
            4'b1011: reg_inputs[119:110] <= inputs;
            4'b1100: reg_inputs[129:120] <= inputs;
            4'b1101: reg_inputs[139:130] <= inputs;
            4'b1110: reg_inputs[149:140] <= inputs;
            4'b1111: reg_inputs[159:150] <= inputs;
        endcase
    end
    
    //fetch ifcs and vars
    branch_fb_ifc branch_fb[2]();
    assign branch_fb[0].if_branch = 0;
    assign branch_fb[0].if_prediction_correct = 1;
    assign branch_fb[0].outcome = NOT_TAKEN;
    assign branch_fb[0].cp_addr = 0;
    assign branch_fb[0].branch_pc = 0;
    assign branch_fb[0].new_pc = 0;
    assign branch_fb[1].if_branch = 0;
    assign branch_fb[1].if_prediction_correct = 1;
    assign branch_fb[1].outcome = NOT_TAKEN;
    assign branch_fb[1].cp_addr = 0;
    assign branch_fb[1].branch_pc = 0;
    assign branch_fb[1].new_pc = 0;
    
    branch_fb_decode_ifc branch_fb_dec();
    logic ext_stall_fetch, ext_flush_fetch;
    assign ext_flush_fetch = if_recall;
    fetch_out_ifc fetch_out[2]();
    logic [31:0] fetch_addr;
    logic fetch_addr_valid;
    logic [63:0] fetched_data;
    
    assign fetch_addr = direct_inputs[31:0];
    assign fetch_addr_valid = direct_inputs[32];
    assign fetched_data = direct_inputs[96:33];
    
    //decode ifcs and vars
    logic ext_stall_dec, ext_flush_dec;
    assign ext_flush_dec = if_recall;
    decode_out_ifc dec_out[2]();
    
    //rename ifcs and vars
    logic ext_stall_ren, ext_flush_ren;
    //assign ext_stall_ren = 0;
    assign ext_flush_ren = if_recall;
    wb_ifc wb[4]();
    wb_ifc wb_s1[4]();
    wb_ifc wb_s2[4]();
    rename_out_ifc ren_out[2]();
    logic int_stall_ren;
    logic [$clog2(`AL_SIZE)-1:0] al_front_ptr, al_back_ptr;
    logic [$clog2(`AL_SIZE)-1:0] oldest_branch_al_addr;
    logic no_checkpoints;
    assign ext_stall_dec = int_stall_ren;
    assign ext_stall_fetch = int_stall_ren;
    
    
    logic [$clog2(`AL_SIZE)-1:0] new_front, old_front, back;
    logic if_recall;
    assign if_recall = branch_fb[0].if_branch && ~branch_fb[0].if_prediction_correct;
    assign new_front = branch_fb[0].al_addr;
    assign old_front = al_front_ptr;
    assign back = al_back_ptr;

    
    //issue ifcs and vars
    logic ext_stall_iss;
    aiq_ifc aiq_issue_out[2]();
    miq_ifc miq_issue_out[2]();
    
    
    //reg file ifcs and vars
    logic ext_stall_reg;
    aiq_ifc aiq_reg_out[2]();
    miq_ifc miq_reg_out[2]();
    logic [31:0] reg_out [8];
    
    
    //execute stage vars
    logic [31:0] reg_in_arith [4];
    logic [31:0] reg_in_mem [4];
    wb_ifc arith_wb[2]();
    wb_ifc mem_wb[2]();
    
    assign wb[0].valid = arith_wb[0].valid;
    assign wb[0].al_idx = arith_wb[0].al_idx;
    assign wb[0].data = arith_wb[0].data;
    assign wb[0].rd = arith_wb[0].rd;
    assign wb[0].uses_rd = arith_wb[0].uses_rd;
    assign wb[1].valid = arith_wb[1].valid;
    assign wb[1].al_idx = arith_wb[1].al_idx;
    assign wb[1].data = arith_wb[1].data;
    assign wb[1].rd = arith_wb[1].rd;
    assign wb[1].uses_rd = arith_wb[1].uses_rd;
    assign wb[2].valid = mem_wb[0].valid;
    assign wb[2].al_idx = mem_wb[0].al_idx;
    assign wb[2].data = mem_wb[0].data;
    assign wb[2].rd = mem_wb[0].rd;
    assign wb[2].uses_rd = mem_wb[0].uses_rd;
    assign wb[3].valid = mem_wb[1].valid;
    assign wb[3].al_idx = mem_wb[1].al_idx;
    assign wb[3].data = mem_wb[1].data;
    assign wb[3].rd = mem_wb[1].rd;
    assign wb[3].uses_rd = mem_wb[1].uses_rd;
    assign reg_in_arith[0] = reg_out[0];
    assign reg_in_arith[1] = reg_out[1];
    assign reg_in_arith[2] = reg_out[2];
    assign reg_in_arith[3] = reg_out[3];
    assign reg_in_mem[0] = reg_out[4];
    assign reg_in_mem[1] = reg_out[5];
    assign reg_in_mem[2] = reg_out[6];
    assign reg_in_mem[3] = reg_out[7];
    
    
    
    fetch_stage FETCH_STAGE(
        .clk, .reset,
        .branch_fb,
        .decode_fb(branch_fb_dec),
        .ext_stall(ext_stall_fetch),
        .ext_flush(ext_flush_fetch),
        .o_instr(fetch_out),
        .fetch_addr,
        .fetch_addr_valid,
        .fetched_data
    );
    
    decode_stage DECODE_STAGE(
        .clk, .reset,
        .ext_stall(ext_stall_dec),
        .ext_flush(ext_flush_dec),
        .i_fetch(fetch_out),
        .o_decode(dec_out),
        .o_fb(branch_fb_dec)
    );
    
    rename_stage RENAME_STAGE(
        .clk, .reset,
        .ext_stall(ext_stall_ren),
        .ext_flush(ext_flush_ren),
        .i_decode(dec_out),
        .i_branch_fb(branch_fb),
        .i_wb(wb),
        .o_renamed(ren_out),
        .oldest_branch_al_addr,
        .no_checkpoints,
        .int_stall(int_stall_ren),
        .al_front_ptr_reg(al_front_ptr),
        .al_back_ptr_reg(al_back_ptr)
    );
    
    
    issue_stage ISSUE_STAGE(
        .clk, .reset,
        .ext_stall(ext_stall_reg),
        .i_ren(ren_out),
        .if_recall,
        .new_front,
        .old_front,
        .back,
        .i_wb(wb),
        //.bbt,
        .o_iq(aiq_issue_out),
        .o_miq(miq_issue_out),
        .oldest_branch_al_addr,
        .no_checkpoints,
        .int_stall(ext_stall_ren)
    );

    fast_reg_file FRF(
        .clk, .f_clk, .reset, .ext_stall(1'b0),
        .if_recall, .new_front, .old_front, .back,
        .i_wb(wb),
        .i_aiq(aiq_issue_out),
        .i_miq(miq_issue_out),
        .o_regs(reg_out),
        .o_aiq(aiq_reg_out),
        .o_miq(miq_reg_out),
        .int_stall(ext_stall_reg)
    );
    
    
    arith_ex_stage ARITH_EX_STAGE(
        .clk, .if_recall, .new_front, .old_front, .back,
        .i_aiq(aiq_reg_out),
        .i_regs(reg_in_arith),
        .o_wb(arith_wb),
        .o_fb(branch_fb)
    );
    
    t_mem_stage MEM_STAGE(
        .clk, .if_recall, .new_front, .old_front, .back,
        .i_miq(miq_reg_out),
        .i_regs(reg_in_mem),
        .o_wb(mem_wb)
    );
    
    /*write_back_stage WRITE_BACK_STAGE(
        .clk, .if_recall, .new_front, .old_front, .back,
        .i_wb(wb),
        .o_wb_s1(wb_s1),
        .o_wb_s2(wb_s2)
    );*/
    
    always_comb begin
        case(switches) 
            4'b0000: r1 = wb[0].data[15:0];
            4'b0000: r1 = wb[0].data[31:16];
            4'b0000: r1 = wb[1].data[15:0];
            4'b0000: r1 = wb[1].data[31:16];
            4'b0000: r1 = wb[2].data[15:0];
            4'b0000: r1 = wb[2].data[31:16];
            4'b0000: r1 = wb[3].data[15:0];
            4'b0000: r1 = wb[3].data[31:16];
            4'b0000: r1 = wb[0].data[15:0];
            4'b0000: r1 = wb[0].data[31:16];
            4'b0000: r1 = wb[0].data[15:0];
            4'b0000: r1 = wb[0].data[31:16];
            4'b0000: r1 = wb[0].data[15:0];
            4'b0000: r1 = wb[0].data[31:16];
            4'b0000: r1 = wb[0].data[15:0];
            4'b0000: r1 = wb[0].data[31:16];
        endcase
    end
    
endmodule
