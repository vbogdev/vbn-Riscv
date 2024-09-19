`timescale 1ns / 1ps
`include "riscv_core.svh"

module aiq_bank #(
    parameter SIZE=8
    )(
    input clk, reset,
    input ext_stall,
    //incoming instr
    rename_out_ifc.in_aiq i_ren,
    //recall
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    //free list
    wb_ifc.in i_wb [4],
    //outputs
    aiq_ifc.out o_iq,
    output int_stall
    );
    
    
    logic full;
    
    logic [SIZE-1:0] valid;
    logic uses_rs1 [SIZE];
    logic uses_rs2 [SIZE];
    logic [$clog2(`NUM_PR)-1:0] rs1 [SIZE];
    logic [$clog2(`NUM_PR)-1:0] rs2 [SIZE];
    
    logic rs1_ready [SIZE];
    logic rs2_ready [SIZE];
    logic instr_ready [SIZE];
    logic [$clog2(`AL_SIZE)-1:0] al_addr [SIZE];
    
    
    logic [$clog2(SIZE):0] queue_size;
    assign full = (queue_size == SIZE);
    always_comb begin
        queue_size = 0;
        for(int i = 0; i < SIZE; i++) begin
            if(valid[i]) queue_size = queue_size + 1;
        end
        
        //**************SELECT READY LOGIC*******************
        for(int i = 0; i < SIZE; i++) begin
            if(valid[i] && (rs1_ready[i] || ~uses_rs1[i]) && (rs2_ready[i] || ~uses_rs2[i])) begin
                instr_ready[i] = 1;
            end else begin
                instr_ready[i] = 0;
            end
        end
    end
    
    //**************FLUSH LOGIC**************
    logic [SIZE-1:0] flush_mask;
    undo_checkpoint_module #(.DEPTH(SIZE)) UCM (
        .new_front, .old_front, .back,
        .list(al_addr),
        .i_valid(valid),
        .flush_mask
    );
    
    
    //**************select outgoing logic**************
    
    //select first ready
    logic [SIZE-1:0] valid_and_ready;
    always_comb begin
        for(int i = 0; i < SIZE; i++) begin
            valid_and_ready[i] = valid[i] && instr_ready[i];
        end
    end
    logic [$clog2(SIZE)-1:0] first_ready;
    logic first_ready_valid;
    assign first_ready_valid = |valid_and_ready;
    select_left_most #(.SIZE(SIZE)) select_first_ready(
        .input_mask(valid_and_ready),
        .o_idx(first_ready)
    );
 
    
    //**************select incoming logic**************
    
    //select first empty
    logic [SIZE-1:0] invalid;
    assign invalid = ~valid;
    logic [$clog2(SIZE)-1:0] first_empty;
    logic first_empty_valid;
    select_left_most #(.SIZE(SIZE)) select_first_empty(
        .input_mask(invalid),
        .o_idx(first_empty)
    );
    assign first_empty_valid = |invalid;
    
    logic [$clog2(SIZE)-1:0] addr, last_addr;
    assign addr = (ext_stall) ? last_addr : ((first_ready_valid) ? first_ready : first_empty);
    always_ff @(posedge clk) last_addr <= addr;

    
    
    //**************handle inputs to ram**************
    logic is_arith, we;
    assign is_arith = i_ren.valid && ~i_ren.is_mem_access && ~i_ren.is_fp && ~i_ren.accesses_csr;
    assign int_stall = (is_arith && ~first_empty_valid) || ext_stall;
    assign we = ~int_stall && is_arith && ~ext_stall && (first_ready_valid || (~first_ready_valid && first_empty_valid && ~full)) 
        && ~if_recall;
    
    
    localparam payload_width = `ADDR_WIDTH + 1 + 1 + $clog2(`NUM_PR) + 32 + 5 + `ADDR_WIDTH + 1 + 1 + 1 + 3 + 1 + `ADDR_WIDTH;
//    payload is in order:
//        uses_rd
//        rd
//        uses_imm
//        imm
//        alu_operation
//        target
//        is_branch
//        is_jump
//        is_jump_register
//        branch_op
//        prediction
//        cp_addr
//        pc

    
    logic [payload_width-1:0] din, dout;
    assign din[0] = i_ren.uses_rd;
    assign din[$clog2(`NUM_PR):1] = i_ren.rd;
    assign din[$clog2(`NUM_PR)+1] = i_ren.uses_imm;
    assign din[($clog2(`NUM_PR)+2)+:32] = i_ren.imm;
    assign din[($clog2(`NUM_PR)+34)+:5] = i_ren.alu_operation;
    assign din[($clog2(`NUM_PR)+39)+:`ADDR_WIDTH] = i_ren.target;
    assign din[($clog2(`NUM_PR)+39+`ADDR_WIDTH)] = i_ren.is_branch;
    assign din[($clog2(`NUM_PR)+40+`ADDR_WIDTH)] = i_ren.is_jump;
    assign din[($clog2(`NUM_PR)+41+`ADDR_WIDTH)] = i_ren.is_jump_register;
    assign din[($clog2(`NUM_PR)+42+`ADDR_WIDTH)+:3] = i_ren.branch_op;
    assign din[($clog2(`NUM_PR)+45+`ADDR_WIDTH)] = i_ren.prediction;
    assign din[($clog2(`NUM_PR)+46+`ADDR_WIDTH)+:$clog2(`NUM_CHECKPOINTS)] = i_ren.cp_addr;
    assign din[($clog2(`NUM_PR)+46+`ADDR_WIDTH+$clog2(`NUM_CHECKPOINTS))+:`ADDR_WIDTH] = i_ren.pc;
    
    
    always_ff @(posedge clk) begin
        if(reset || ~first_ready_valid) begin
            o_iq.valid <= 0;
            o_iq.uses_rs1 <= 0;
            o_iq.uses_rs2 <= 0;
            o_iq.rs1 <= 0;
            o_iq.rs2 <= 0;
            o_iq.al_addr <= 0;
            o_iq.uses_rd <= 0;
            o_iq.rd <= 0;
            o_iq.uses_imm <= 0;
            o_iq.imm <= 0;
            o_iq.alu_operation <= ALUCTL_ADD;
            o_iq.target <= 0;
            o_iq.is_branch <= 0;
            o_iq.is_jump <= 0;
            o_iq.is_jump_register <= 0;
            o_iq.branch_op <= 0;
            o_iq.prediction <= 0;
            o_iq.cp_addr <= 0;
            o_iq.pc <= 0;
        end else if(~ext_stall) begin
            o_iq.valid <= valid[addr] && ((~flush_mask[addr] && if_recall) || ~if_recall) && first_ready_valid;
            o_iq.uses_rs1 <= uses_rs1[addr];
            o_iq.uses_rs2 <= uses_rs2[addr];
            o_iq.rs1 <= rs1[addr];
            o_iq.rs2 <= rs2[addr];
            o_iq.al_addr <= al_addr[addr];
            o_iq.uses_rd <= dout[0];
            o_iq.rd <= dout[$clog2(`NUM_PR):1];
            o_iq.uses_imm <= dout[$clog2(`NUM_PR)+1];
            o_iq.imm <= dout[($clog2(`NUM_PR)+2)+:32];
            o_iq.alu_operation <= dout[($clog2(`NUM_PR)+34)+:5];
            o_iq.target <= dout[($clog2(`NUM_PR)+39)+:`ADDR_WIDTH];
            o_iq.is_branch <= dout[($clog2(`NUM_PR)+39+`ADDR_WIDTH)];
            o_iq.is_jump <= dout[($clog2(`NUM_PR)+40+`ADDR_WIDTH)];
            o_iq.is_jump_register <= dout[($clog2(`NUM_PR)+41+`ADDR_WIDTH)];
            o_iq.branch_op <= dout[($clog2(`NUM_PR)+42+`ADDR_WIDTH)+:3];
            o_iq.prediction <= dout[($clog2(`NUM_PR)+45+`ADDR_WIDTH)];
            o_iq.cp_addr <= dout[($clog2(`NUM_PR)+46+`ADDR_WIDTH)+:$clog2(`NUM_CHECKPOINTS)];
            o_iq.pc <= dout[($clog2(`NUM_PR)+46+`ADDR_WIDTH+$clog2(`NUM_CHECKPOINTS))+:`ADDR_WIDTH];
         end
    end
    
    
    distributed_ram #(
        .WIDTH(payload_width),
        .DEPTH(SIZE)
    )INSTR_PAYLOAD(
        .clk,
        .addr,
        .we,
        .din,
        .dout
    );
    
    
    /*
        HANDLE CASE WHERE INCOMING INSTRS REG'S ARE NOT READY, BUT AS IT IS PLACED IN QUEUE,     
        THE REGS ARE AVAILABLE
    */
    logic incoming_overwrite_ready [2];
    assign incoming_overwrite_ready[0] = i_ren.uses_rs1 && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == i_ren.rs1)) || (i_wb[1].valid && 
        i_wb[1].uses_rd && (i_wb[1].rd == i_ren.rs1)) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == i_ren.rs1)) || (i_wb[3].valid && 
        i_wb[3].uses_rd && (i_wb[3].rd == i_ren.rs1)));
    assign incoming_overwrite_ready[1] = i_ren.uses_rs2 && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == i_ren.rs2)) || (i_wb[1].valid && 
        i_wb[1].uses_rd && (i_wb[1].rd == i_ren.rs2)) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == i_ren.rs2)) || (i_wb[3].valid && 
        i_wb[3].uses_rd && (i_wb[3].rd == i_ren.rs2)));
    
    //**************handle data not stored in ram**************
    always_ff @(posedge clk) begin
        if(reset) begin
            valid <= 0;
        end else begin
            //flush mispeculated instructions
            if(if_recall) begin
                for(int i = 0; i < SIZE; i++) begin
                    if(flush_mask[i]) begin
                        valid[i] <= 0;
                    end
                end
            end
            //allocate new enty
            if(we) begin
                valid[addr] <= 1;
                uses_rs1[addr] <= i_ren.uses_rs1;
                uses_rs2[addr] <= i_ren.uses_rs2;
                //rs1_ready[addr] <= i_ren.rs1_ready || incoming_overwrite_ready[0];
                //rs2_ready[addr] <= i_ren.rs2_ready || incoming_overwrite_ready[1];
                rs1[addr] <= i_ren.rs1;
                rs2[addr] <= i_ren.rs2;
                al_addr[addr] <= i_ren.al_addr;
            end
            
            if(valid_and_ready && ~we) begin
                valid[first_ready] <= 0;
            end
            
         end
    end
    
    //***********handle updating rsx_ready bits from i_wb    
    genvar j; //handle checking from i_wb[j]
    generate
        //handle rs1
        for(j = 0; j < SIZE; j++) begin
            always_ff @(posedge clk) begin
                if(we && (addr == j)) begin
                    rs1_ready[j] <= i_ren.rs1_ready || incoming_overwrite_ready[0];
                end else if(valid[j] && uses_rs1[j] && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == rs1[j])) || (i_wb[1].valid && i_wb[1].uses_rd 
                    && (i_wb[1].rd == rs1[j])) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == rs1[j])) || (i_wb[3].valid && i_wb[3].uses_rd && 
                    (i_wb[3].rd == rs1[j])))) begin
                    
                    rs1_ready[j] <= 1;
                end
            end
            
            always_ff @(posedge clk) begin
                if(we && (addr == j)) begin
                    rs2_ready[j] <= i_ren.rs2_ready || incoming_overwrite_ready[1];
                end else if(valid[j] && uses_rs2[j] && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == rs2[j])) || (i_wb[1].valid && i_wb[1].uses_rd 
                    && (i_wb[1].rd == rs2[j])) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == rs2[j])) ||  (i_wb[3].valid && i_wb[3].uses_rd && 
                    (i_wb[3].rd == rs2[j])))) begin
                    
                    rs2_ready[j] <= 1;
                end
            end
        end
    endgenerate
    
    
    
    
    
    
    
    
    
    
    
    
endmodule
