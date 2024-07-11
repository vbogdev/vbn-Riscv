`timescale 1ns / 1ps
`include "riscv_core.svh"

module arithmetic_iq #(
    parameter SIZE = 8
    )(
    input clk, reset,
    input ext_flush, ext_stall,
    //incoming instr
    rename_out_ifc.in i_ren [2],
    //recall
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    //free list
    input [63:0] bbt,
    //outputs
    aiq_ifc.out o_iq [`NUM_ARITH_CORE],
    output int_stall
    );
    
    logic valid [SIZE];
    logic rs1_ready [SIZE];
    logic rs2_ready [SIZE];
    logic [5:0] rs1 [SIZE];
    logic [5:0] rs2 [SIZE];
    logic [5:0] rd [SIZE];
    logic uses_rs1 [SIZE];
    logic uses_rs2 [SIZE];
    logic uses_imm [SIZE]; 
    logic uses_rd [SIZE];
    logic [31:0] imm [SIZE];
    riscv_pkg::AluCtl alu_operation [SIZE];
    logic [`ADDR_WIDTH-1:0] target [SIZE];
    logic is_branch [SIZE];
    logic is_jump [SIZE];
    logic is_jump_register [SIZE];
    riscv_pkg::funct3_branch branch_op [SIZE];
    riscv_pkg::BranchOutcome prediction [SIZE];
    
    logic instr_ready [SIZE];
    logic [$clog2(`AL_SIZE)-1:0] al_addr [SIZE];
    logic flush_mask [SIZE];
    
    
    logic [$clog2(SIZE):0] queue_size;
    always_comb begin
        for(int i = 0; i < SIZE; i++) begin
            queue_size = queue_size + valid[i]; 
        end
        
        for(int i = 0; i < SIZE; i++) begin
            rs1_ready[i] = ~uses_rs1[i] || ~bbt[rs1[i]];
            rs2_ready[i] = ~uses_rs2[i] || ~bbt[rs2[i]];
            instr_ready[i] = rs1_ready[i] && rs2_ready[i];
        end
    end
        
    
    //SELECT LOGIC
    logic [$clog2(SIZE)-1:0] selected [`NUM_ARITH_CORE];
    logic selected_valid [`NUM_ARITH_CORE];
    
    
    logic [$clog2(SIZE)-1:0] new_store_loc [`NUM_ARITH_CORE];
    logic new_store_loc_valid [`NUM_ARITH_CORE];
    
    
    //SELECT OUTGOING
    logic valid_and_ready [SIZE];
    always_comb begin
        for(int i = 0; i < SIZE; i++) begin
            valid_and_ready[i] = valid[i] && instr_ready[i];
        end
    end
    logic [$clog2(SIZE)-1:0] first_index;
    select_left_most #(.SIZE(SIZE)) select_first(
        .input_mask(valid_and_ready),
        .o_idx(selected[0])
    );
    
    logic second_ready [SIZE];
    always_comb begin
        for(int i = 0; i < SIZE; i++) begin
            if(i == first_index) begin
                second_ready[i] = valid_and_ready[i];
            end else begin
                second_ready[i] = 0;
            end
        end 
    end
    logic [$clog2(SIZE)-1:0] second_index;
    select_left_most #(.SIZE(SIZE)) select_second(
        .input_mask(second_ready),
        .o_idx(selected[1])
    );  
    
    logic [SIZE-1:0] valid_and_ready_bus, second_ready_bus;
    always_comb begin
        for(int i = 0; i < SIZE; i++) begin
            valid_and_ready_bus[i] = valid_and_ready[i];
            second_ready_bus[i] = second_ready[i];
        end
        selected_valid[0] = |valid_and_ready_bus;
        selected_valid[1] = |second_ready_bus;
    end
    
    
    //SELECT FREE FOR INCOMING
    logic [$clog2(SIZE)-1:0] first_free, second_free;
    logic free_mask1 [SIZE];
    logic free_mask2 [SIZE];
    always_comb begin
        for(int i = 0; i < SIZE; i++) begin
            free_mask1[i] = ~instr_ready[i] & valid[i];
            if(i == first_free) begin
                free_mask2[i] = 0;
            end else begin
                free_mask2[i] = ~instr_ready[i] & valid[i];
            end
        end
    end
    select_left_most #(.SIZE(SIZE)) free_select_first(
        .input_mask(free_mask1),
        .o_idx(new_store_loc[0])
    );
    select_left_most #(.SIZE(SIZE)) free_select_second(
        .input_mask(free_mask2),
        .o_idx(new_store_loc[1])
    );
    
    logic [SIZE-1:0] free_mask_bus, free_mask_bus2;
    always_comb begin
        for(int i = 0; i < SIZE; i++) begin
            free_mask_bus[i] = free_mask1[i];
            free_mask_bus2[i] = free_mask2[i];
        end
        new_store_loc_valid[0] = |free_mask_bus && ~i_ren[0].is_mem_access && ~i_ren[0].is_fp && ~i_ren[0].accesses_csr && i_ren[0].valid;
        new_store_loc_valid[1] = |free_mask_bus2 && ~i_ren[1].is_mem_access && ~i_ren[1].is_fp && ~i_ren[1].accesses_csr && i_ren[1].valid;
    end
    
    undo_checkpoint_module #(
        .DEPTH(SIZE)
        )UDM(
        .new_front,
        .old_front,
        .back,
        .list(al_addr),
        .i_valid(valid),
        .flush_mask(flush_mask)
    );
    
    
    logic stall;
    assign stall = ~ext_stall || ((queue_size + i_ren[0].valid && ~i_ren[0].is_mem_access && ~i_ren[0].accesses_csr && ~i_ren[0].is_fp + 
        i_ren[1].valid && ~i_ren[1].is_mem_access && ~i_ren[1].accesses_csr && ~i_ren[1].is_fp) >= SIZE);
    assign int_stall = ((queue_size + i_ren[0].valid && ~i_ren[0].is_mem_access && ~i_ren[0].accesses_csr && ~i_ren[0].is_fp + 
        i_ren[1].valid && ~i_ren[1].is_mem_access && ~i_ren[1].accesses_csr && ~i_ren[1].is_fp) >= SIZE);
    
    genvar i;
    generate
        for(i = 0; i < 2; i++) begin
            always_comb begin
                o_iq[i].rs1 = rs1[selected[i]];
                o_iq[i].rs2 = rs2[selected[i]];
                o_iq[i].rd = rd[selected[i]];
                o_iq[i].uses_rs1 = uses_rs1[selected[i]];
                o_iq[i].uses_rs2 = uses_rs2[selected[i]];
                o_iq[i].uses_rd = uses_rd[selected[i]];
                o_iq[i].uses_imm = uses_imm[selected[i]];
                o_iq[i].imm = imm[selected[i]];
                o_iq[i].alu_operation = alu_operation[selected[i]];
                o_iq[i].target = target[selected[i]];
                o_iq[i].is_branch = is_branch[selected[i]];
                o_iq[i].is_jump = is_jump[selected[i]];
                o_iq[i].is_jump_register = is_jump_register[selected[i]];
                o_iq[i].branch_op = branch_op[selected[i]];
                o_iq[i].prediction = prediction[selected[i]];
                if(~stall && selected_valid[i] && (~flush_mask[selected_valid[i]] || ~if_recall)) begin
                    o_iq[i].valid = 1;
                end else begin
                    o_iq[i].valid = 0;
                end
            end
        end
        
        for(i = 0; i < SIZE; i++) begin
            always_comb begin
                rs1_ready[i] = ~uses_rs1[i] || ~bbt[rs1[i]];
                rs2_ready[i] = ~uses_rs2[i] || ~bbt[rs2[i]];
            end
        end
        
    endgenerate
    


    always_ff @(posedge clk) begin
        
        if(reset) begin
            for(int i = 0; i < SIZE; i++) begin
                valid[i] <= 0;
            end
        end else if(if_recall) begin
            for(int i = 0; i < SIZE; i++) begin
                valid[i] <= ~flush_mask[i];
            end
        end else if(~stall) begin
            if(new_store_loc_valid[0] && i_ren[0].valid) begin
                valid[new_store_loc[0]] <= 1;
                rs1[new_store_loc[0]] <= i_ren[0].rs1;
                rs2[new_store_loc[0]] <= i_ren[0].rs2;
                rd[new_store_loc[0]] <= i_ren[0].rd;
                uses_rs1[new_store_loc[0]] <= i_ren[0].uses_rs1;
                uses_rs2[new_store_loc[0]] <= i_ren[0].uses_rs2;
                uses_rd[new_store_loc[0]] <= i_ren[0].uses_rd;
                uses_imm[new_store_loc[0]] <= i_ren[0].uses_imm;
                imm[new_store_loc[0]] <= i_ren[0].imm;
                alu_operation[new_store_loc[0]] <= i_ren[0].alu_operation;
                target[new_store_loc[0]] <= i_ren[0].target;
                is_branch[new_store_loc[0]] <= i_ren[0].is_branch;
                is_jump[new_store_loc[0]] <= i_ren[0].is_jump;
                is_jump_register[new_store_loc[0]] <= i_ren[0].is_jump_register;
                branch_op[new_store_loc[0]] <= i_ren[0].branch_op;
                prediction[new_store_loc[0]] <= i_ren[0].prediction;
            end
            if(new_store_loc_valid[1] && i_ren[1].valid) begin
                valid[new_store_loc[1]] <= 1;
                rs1[new_store_loc[1]] <= i_ren[1].rs1;
                rs2[new_store_loc[1]] <= i_ren[1].rs2;
                rd[new_store_loc[1]] <= i_ren[1].rd;
                uses_rs1[new_store_loc[1]] <= i_ren[1].uses_rs1;
                uses_rs2[new_store_loc[1]] <= i_ren[1].uses_rs2;
                uses_rd[new_store_loc[1]] <= i_ren[1].uses_rd;
                uses_imm[new_store_loc[1]] <= i_ren[1].uses_imm;
                imm[new_store_loc[1]] <= i_ren[1].imm;
                alu_operation[new_store_loc[1]] <= i_ren[1].alu_operation;
                target[new_store_loc[1]] <= i_ren[1].target;
                is_branch[new_store_loc[1]] <= i_ren[1].is_branch;
                is_jump[new_store_loc[1]] <= i_ren[1].is_jump;
                is_jump_register[new_store_loc[1]] <= i_ren[1].is_jump_register;
                branch_op[new_store_loc[1]] <= i_ren[1].branch_op;
                prediction[new_store_loc[1]] <= i_ren[1].prediction;
            end
        
            if(selected_valid[0]) begin
                valid[selected[0]] <= 0;
            end 
            if(selected_valid[1]) begin
                valid[selected[1]] <= 0;
            end 
            
        end
    end
endmodule
