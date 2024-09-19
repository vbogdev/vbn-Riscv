`timescale 1ns / 1ps
`include "riscv_core.svh"

/*
------------__FRONT POINTER IS NOT CORRECTLY MOVED AFTER A CHECKPOINT IS RECALLED
*/
module in_order_iq #(
    parameter SIZE=8
    )(
    input clk, reset,
    input ext_stall,
    //incoming instr
    rename_out_ifc.in_ioiq i_ren,
    //done
    wb_ifc.in i_wb [4],
    //recall
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    input [$clog2(`AL_SIZE)-1:0] oldest_branch_al_addr,
    input no_branches,
    //free list
    //outputs
    miq_ifc.out o_miq,
    output int_stall
    );
    
   
    
    logic uses_rs1 [SIZE];
    logic uses_rs2 [SIZE];
    logic [$clog2(`AL_SIZE)-1:0] rs1 [SIZE];
    logic [$clog2(`AL_SIZE)-1:0] rs2 [SIZE];
    logic rs1_ready [SIZE];
    logic rs2_ready [SIZE];
    logic instr_ready [SIZE];
    
    logic [SIZE-1:0] valid, flush_mask;
    logic [$clog2(`AL_SIZE)-1:0] al_addrs [SIZE];
    logic [$clog2(SIZE)-1:0] front_ptr, back_ptr;
    
    
    logic [$clog2(SIZE):0] queue_size;
    assign full = (queue_size == SIZE);
    always_comb begin
        queue_size = 0;
        for(int i = 0; i < SIZE; i++) begin
            if(valid[i]) queue_size = queue_size + 1;
        end 
        
        for(int i = 0; i < SIZE; i++) begin
            instr_ready[i] = ((rs1_ready[i] && uses_rs1[i]) || ~uses_rs1[i]) && ((rs2_ready[i] && uses_rs2[i]) || ~uses_rs2[i]);
        end
    end
    
    undo_checkpoint_module #(
        .DEPTH(SIZE)
    ) UCM (
        .new_front, .old_front, .back,
        .list(al_addrs),
        .i_valid(valid),
        .flush_mask
    );
    
    logic [$clog2(SIZE)-1:0] new_queue_front;
    logic change; 
    
    new_front_ptr_module #(.SIZE(SIZE)) NFPM(
        .valid,
        .flush(flush_mask),
        .front_ptr,
        .back_ptr,
        .new_front_ptr(new_queue_front),
        .change
    );
    
    assign int_stall = (SIZE == queue_size);
    
    logic back_ready;
    always_comb begin
        back_ready = 0;
        if(valid[back_ptr] && no_branches) begin
            back_ready = 1;
        end else if(valid[back_ptr]) begin
            if(back < old_front) begin
                if(al_addrs[back_ptr] < oldest_branch_al_addr) begin
                    back_ready = 1;
                end 
            end else if((back > old_front) && (al_addrs[back_ptr] >= back) && (al_addrs[back_ptr] < oldest_branch_al_addr)) begin
               back_ready = 1;
            end else if((old_front >= oldest_branch_al_addr) && (back > old_front) && (al_addrs[back_ptr] >= back)) begin
                back_ready = 1;
            end else if(((al_addrs[back_ptr] < oldest_branch_al_addr) || (al_addrs[back_ptr] >= back)) && (old_front >= oldest_branch_al_addr)) begin
                back_ready = 1;
            end else if((oldest_branch_al_addr > al_addrs[back_ptr]) && (old_front >= oldest_branch_al_addr) && (back > old_front)) begin
                back_ready = 1;
            end else if(back == old_front) begin
                //shouldn't be able to happen, as this means only 1 instr in pipeline, so either no branches on only 1 branch so IQ is empty
            end
        end
    end  
    
    
    localparam payload_width = `ADDR_WIDTH+$clog2(`NUM_PR)+39;
    logic [payload_width-1:0] din, dout, t_dout;
    assign din[0+:`ADDR_WIDTH] = i_ren.pc;
    assign din[`ADDR_WIDTH+:$clog2(`NUM_PR)] = i_ren.rd;
    assign din[`ADDR_WIDTH+$clog2(`NUM_PR)] = i_ren.uses_rd;
    assign din[`ADDR_WIDTH+$clog2(`NUM_PR)+1+:32] = i_ren.imm;
    assign din[`ADDR_WIDTH+$clog2(`NUM_PR)+33] = i_ren.uses_imm;
    assign din[`ADDR_WIDTH+$clog2(`NUM_PR)+34] = i_ren.is_mem_access;
    assign din[`ADDR_WIDTH+$clog2(`NUM_PR)+35] = i_ren.mem_access_type;
    assign din[`ADDR_WIDTH+$clog2(`NUM_PR)+36+:3] = i_ren.width;
    logic outgoing_instr;
    
    
    logic we;
    assign we = ~int_stall && i_ren.valid && (i_ren.is_mem_access || i_ren.accesses_csr) && ~if_recall;
    
    /*********************IMPORTANT NOTE*************************
    This latch is needed because access addr is in combinational logic, not
    sequential logic. As a result, the synthesis tool makes it so t_dout cannot 
    read dout in time, so a latch will read dout ahead of time, then stop reading
    it, then pass its value to t_dout in a always_ff block
    *************************************************************/
    logic [payload_width-1:0] outgoing_latch;
    always_comb begin
        if(clk) begin
            outgoing_latch = dout;
        end
    end
    
    //if top instruction is ready, prep it to leave
    always_ff @(negedge clk) begin
        if(back_ready && instr_ready[back_ptr] && valid[back_ptr]) begin
            //valid[back_ptr] <= 0;
            //back_ptr <= back_ptr + 1;
            //t_dout <= outgoing_latch;
            t_dout <= dout;
            outgoing_instr <= 1;
        end else begin
            outgoing_instr <= 0;
        end
    end
    
    logic [$clog2(SIZE)-1:0] access_addr;
    assign access_addr = clk ? front_ptr : back_ptr;
    
    
    

    distributed_ram #(
        .WIDTH(payload_width),
        .DEPTH(SIZE)
    )INSTR_PAYLOAD(
        .clk,
        .addr(access_addr),
        .we,
        .din,
        .dout
    );
    
    
    always_ff @(posedge clk) begin
    
        if(reset) begin
            front_ptr <= 0;
            back_ptr <= 0;
            valid <= 0;
            o_miq.valid <= 0;
        end else begin
            //handle moving front pointer (incoming instruction)
            if(if_recall) begin
                front_ptr <= new_queue_front;
                for(int i = 0; i < SIZE; i++) begin
                    if(flush_mask[i]) begin
                        valid[i] <= 0;
                    end
                end
            end else begin
                if(we) begin
                    front_ptr <= front_ptr + 1;
                    rs1[front_ptr] <= i_ren.rs1;
                    rs2[front_ptr] <= i_ren.rs2;
                    uses_rs1[front_ptr] <= i_ren.uses_rs1;
                    uses_rs2[front_ptr] <= i_ren.uses_rs2;
                    valid[front_ptr] <= 1;
                    al_addrs[front_ptr] <= i_ren.al_addr;
                end
            end
            //handle moving back pointer (outgoing instruction)
            if(outgoing_instr && ~flush_mask[back_ptr] && valid[back_ptr]) begin
                back_ptr <= back_ptr + 1;
                valid[back_ptr] <= 0;
                //handle outgoing data stuff
                o_miq.valid <= 1;
                o_miq.pc <= t_dout[0+:`ADDR_WIDTH];
                o_miq.rs1 <= rs1[back_ptr];
                o_miq.rs2 <= rs2[back_ptr];
                o_miq.rd <= t_dout[`ADDR_WIDTH+:$clog2(`NUM_PR)];
                o_miq.uses_rs1 <= uses_rs1[back_ptr];
                o_miq.uses_rs2 <= uses_rs2[back_ptr];
                o_miq.uses_rd <= t_dout[`ADDR_WIDTH+$clog2(`NUM_PR)];
                o_miq.uses_imm <= t_dout[`ADDR_WIDTH+$clog2(`NUM_PR)+33];
                o_miq.imm <= t_dout[`ADDR_WIDTH+$clog2(`NUM_PR)+1+:32];
                o_miq.is_mem_access <= t_dout[`ADDR_WIDTH+$clog2(`NUM_PR)+34];
                o_miq.mem_access_type <= t_dout[`ADDR_WIDTH+$clog2(`NUM_PR)+35];
                o_miq.width <= t_dout[`ADDR_WIDTH+$clog2(`NUM_PR)+36+:3];
                o_miq.al_addr <= al_addrs[back_ptr];
            end else begin
                o_miq.valid <= 0;
                o_miq.pc <= 0;
                o_miq.rs1 <= 0;
                o_miq.rs2 <= 0;
                o_miq.rd <= 0;
                o_miq.uses_rs1 <= 0;
                o_miq.uses_rs2 <= 0;
                o_miq.uses_rd <= 0;
                o_miq.uses_imm <= 0;
                o_miq.imm <= 0;
                o_miq.is_mem_access <= 0;
                o_miq.mem_access_type <= 0;
                o_miq.width <= 0;
                o_miq.al_addr <= 0;
            end
        end
    end
    
    
    
    //GIANT BLOCK OF CODE USED TO STORE WHAT REGISTERS ARE READY
    logic incoming_overwrite_ready [2];
    assign incoming_overwrite_ready[0] = i_ren.uses_rs1 && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == i_ren.rs1)) || (i_wb[1].valid && 
        i_wb[1].uses_rd && (i_wb[1].rd == i_ren.rs1)) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == i_ren.rs1)) || (i_wb[3].valid && 
        i_wb[3].uses_rd && (i_wb[3].rd == i_ren.rs1)));
    assign incoming_overwrite_ready[1] = i_ren.uses_rs2 && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == i_ren.rs2)) || (i_wb[1].valid && 
        i_wb[1].uses_rd && (i_wb[1].rd == i_ren.rs2)) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == i_ren.rs2)) || (i_wb[3].valid && 
        i_wb[3].uses_rd && (i_wb[3].rd == i_ren.rs2)));
    
    genvar j; //handle checking from i_wb[j]
    generate
        //handle rs1
        for(j = 0; j < SIZE; j++) begin
            always_ff @(posedge clk) begin
                if(we && (front_ptr == j)) begin
                    rs1_ready[j] <= i_ren.rs1_ready || incoming_overwrite_ready[0];
                end else if(valid[j] && uses_rs1[j] && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == rs1[j])) || (i_wb[1].valid && i_wb[1].uses_rd 
                    && (i_wb[1].rd == rs1[j])) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == rs1[j])) || (i_wb[3].valid && i_wb[3].uses_rd && 
                    (i_wb[3].rd == rs1[j])))) begin
                    
                    rs1_ready[j] <= 1;
                end
            end
            
            always_ff @(posedge clk) begin
                if(we && (front_ptr == j)) begin
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
