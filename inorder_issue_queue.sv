`timescale 1ns / 1ps
`include "riscv_core.svh"
module inorder_issue_queue #(
    parameter SIZE=16
    )(
    input clk, reset, 
    input ext_stall,
    rename_out_ifc.in_ioiq i_ren [2],
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    input [$clog2(`AL_SIZE)-1:0] oldest_branch_al_addr,
    input no_branches,
    //free list
    wb_ifc.in i_wb [4],
    //outputs
    miq_ifc.out o_miq [2],
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
    
    logic incoming_in_order [2];
    always_comb begin
        incoming_in_order[0] = i_ren[0].valid && (i_ren[0].is_mem_access || i_ren[0].accesses_csr);
        incoming_in_order[1] = i_ren[1].valid && (i_ren[1].is_mem_access || i_ren[1].accesses_csr);
    end
    
    
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
    
    assign int_stall = (queue_size + incoming_in_order[0] + incoming_in_order[1]) >= SIZE;
    logic back_nonspeculative [2];
    always_comb begin
        back_nonspeculative[0] = 0;
        back_nonspeculative[1] = 0;
        if(valid[back_ptr] && no_branches) begin
            back_nonspeculative[0] = 1;
        end else if(valid[back_ptr]) begin
            if(back < old_front) begin
                if(al_addrs[back_ptr] < oldest_branch_al_addr) begin
                    back_nonspeculative[0] = 1;
                end 
            end else if((back > old_front) && (al_addrs[back_ptr] >= back) && (al_addrs[back_ptr] < oldest_branch_al_addr)) begin
                back_nonspeculative[0] = 1;
            end else if((old_front >= oldest_branch_al_addr) && (back > old_front) && (al_addrs[back_ptr] >= back)) begin
                back_nonspeculative[0] = 1;
            end else if(((al_addrs[back_ptr] < oldest_branch_al_addr) || (al_addrs[back_ptr] >= back)) && (old_front >= oldest_branch_al_addr)) begin
                back_nonspeculative[0] = 1;
            end else if((oldest_branch_al_addr > al_addrs[back_ptr]) && (old_front >= oldest_branch_al_addr) && (back > old_front)) begin
                back_nonspeculative[0] = 1;
            end else if(back == old_front) begin
                //shouldn't be able to happen, as this means only 1 instr in pipeline, so either no branches on only 1 branch so IQ is empty
            end
        end
        
        if(valid[back_ptr+1] && no_branches) begin
            back_nonspeculative[1] = 1;
        end else if(valid[back_ptr+1]) begin
            if(back < old_front) begin
                if(al_addrs[back_ptr+1] < oldest_branch_al_addr) begin
                    back_nonspeculative[1] = 1;
                end 
            end else if((back > old_front) && (al_addrs[back_ptr+1] >= back) && (al_addrs[back_ptr+1] < oldest_branch_al_addr)) begin
                back_nonspeculative[1] = 1;
            end else if((old_front >= oldest_branch_al_addr) && (back > old_front) && (al_addrs[back_ptr+1] >= back)) begin
                back_nonspeculative[1] = 1;
            end else if(((al_addrs[back_ptr+1] < oldest_branch_al_addr) || (al_addrs[back_ptr+1] >= back)) && (old_front >= oldest_branch_al_addr)) begin
                back_nonspeculative[1] = 1;
            end else if((oldest_branch_al_addr > al_addrs[back_ptr+1]) && (old_front >= oldest_branch_al_addr) && (back > old_front)) begin
                back_nonspeculative[1] = 1;
            end else if(back == old_front) begin
                //shouldn't be able to happen, as this means only 1 instr in pipeline, so either no branches on only 1 branch so IQ is empty
            end
        end
    end  
    
    
    //to avoid having expensive multiport ram, most data will be stored in a pair of banked distributed rams
    //Addressing works as followed:
    //IQ[0] = bank0[0]
    //IQ[1] = bank1[0]
    //IQ[2] = bank0[1]
    //IQ[3] = bank1[1]
    //this should allow up to 2 reads and writes per cycle, while using inexpensive distributed ram
    
    logic read_bank_offset;
    logic write_bank_offset;
    logic next_write_bank_offset;
    
    /*always_comb begin
        if(incoming_in_order[0] && incoming_in_order[1]) begin
            next_write_bank_offset = write_bank_offset;
        end else if(incoming_in_order[0] || incoming_in_order[1]) begin
            next_write_bank_offset = ~write_bank_offset;
        end else begin
            next_write_bank_offset = write_bank_offset;
        end
    end
    
    always_ff @(posedge clk) begin
        if(reset) begin
            write_bank_offset <= 0;
        end else begin
            write_bank_offset <= next_write_bank_offset;
        end
    end*/
    assign write_bank_offset = front_ptr[0]; //offset for if you write to the odd bank first
    
    logic we [2];
    always_comb begin
        if(int_stall && ~if_recall) begin
            we[0] = 0;
            we[1] = 0;
        end else if(incoming_in_order[0] && incoming_in_order[1]) begin
            we[0] = 1;
            we[1] = 1;
        end else if(incoming_in_order[0] || incoming_in_order[1]) begin
            we[write_bank_offset] = 1;
            we[~write_bank_offset] = 0; 
        end else begin
            we[0] = 0;
            we[1] = 0;
        end
    end
    
    
    //some very stupid ass code, but idk want to rewrite it as it is really slow to do that
    logic [$clog2(SIZE/2)-1:0] write_addr [2]; //write_addr[0] should be the addr of bank 0 always
    localparam payload_width = `ADDR_WIDTH+$clog2(`NUM_PR)+39;
    logic [payload_width-1:0] din [2];
    logic [payload_width-1:0] dout [2];
    logic [payload_width-1:0] t_dout [2];
    task setup_din0_ren0;
        din[0][0+:`ADDR_WIDTH] = i_ren[0].pc;                              
        din[0][`ADDR_WIDTH+:$clog2(`NUM_PR)] = i_ren[0].rd;                
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)] = i_ren[0].uses_rd;            
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+1+:32] = i_ren[0].imm;          
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+33] = i_ren[0].uses_imm;        
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+34] = i_ren[0].is_mem_access;   
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+35] = i_ren[0].mem_access_type; 
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+36+:3] = i_ren[0].width;        
    endtask
    
    task setup_din1_ren0;
        din[1][0+:`ADDR_WIDTH] = i_ren[0].pc;                              
        din[1][`ADDR_WIDTH+:$clog2(`NUM_PR)] = i_ren[0].rd;                
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)] = i_ren[0].uses_rd;            
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+1+:32] = i_ren[0].imm;          
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+33] = i_ren[0].uses_imm;        
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+34] = i_ren[0].is_mem_access;   
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+35] = i_ren[0].mem_access_type; 
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+36+:3] = i_ren[0].width;        
    endtask
    
    task setup_din0_ren1;
        din[0][0+:`ADDR_WIDTH] = i_ren[1].pc;                              
        din[0][`ADDR_WIDTH+:$clog2(`NUM_PR)] = i_ren[1].rd;                
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)] = i_ren[1].uses_rd;            
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+1+:32] = i_ren[1].imm;          
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+33] = i_ren[1].uses_imm;        
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+34] = i_ren[1].is_mem_access;   
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+35] = i_ren[1].mem_access_type; 
        din[0][`ADDR_WIDTH+$clog2(`NUM_PR)+36+:3] = i_ren[1].width;        
    endtask
    
    task setup_din1_ren1;
        din[1][0+:`ADDR_WIDTH] = i_ren[1].pc;                              
        din[1][`ADDR_WIDTH+:$clog2(`NUM_PR)] = i_ren[1].rd;                
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)] = i_ren[1].uses_rd;            
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+1+:32] = i_ren[1].imm;          
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+33] = i_ren[1].uses_imm;        
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+34] = i_ren[1].is_mem_access;   
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+35] = i_ren[1].mem_access_type; 
        din[1][`ADDR_WIDTH+$clog2(`NUM_PR)+36+:3] = i_ren[1].width;        
    endtask
    
    logic outgoing_instr [2];
    
    //handle addressing an making sure everything is in the right din slot
    always_comb begin
        if(incoming_in_order[0] && incoming_in_order[1]) begin
            if(write_bank_offset) begin
                setup_din1_ren0();
                setup_din0_ren1();
                write_addr[0] = (front_ptr+1) >> 1;
                write_addr[1] = front_ptr >> 1;
            end else begin
                setup_din0_ren0();
                setup_din1_ren1();
                write_addr[0] = front_ptr >> 1;
                write_addr[1] = front_ptr >> 1;
            end
        end else if(incoming_in_order[0]) begin
            if(write_bank_offset) begin
                setup_din1_ren0();
                write_addr[0] = 0;
                write_addr[1] = front_ptr >> 1;
            end else begin
                setup_din0_ren0();
                write_addr[0] = front_ptr >> 1;
                write_addr[1] = 0;
            end
        end else if(incoming_in_order[1]) begin
            if(write_bank_offset) begin
                setup_din1_ren1();
                write_addr[0] = 0;
                write_addr[1] = front_ptr >> 1;
            end else begin
                setup_din0_ren1();
                write_addr[0] = front_ptr >> 1;
                write_addr[1] = 0;
            end
        end else begin
            write_addr[0] = 0;
            write_addr[1] = 0;
        end
    end
    
    logic [payload_width-1:0] outgoing_latch [2];
    always_comb begin
        if(clk) begin
            outgoing_latch[0] = dout[0];
            outgoing_latch[1] = dout[1];
        end
    end
    
    //if top instruction is ready, prep it to leave
    always_ff @(negedge clk) begin
        if(back_nonspeculative[0] && instr_ready[back_ptr] && valid[back_ptr]) begin
            //valid[back_ptr] <= 0;
            //back_ptr <= back_ptr + 1;
            //t_dout <= outgoing_latch;
            t_dout[0] <= ((back_ptr % 2) == 0) ? dout[0] : dout[1];
            outgoing_instr[0] <= 1;
        end else begin
            outgoing_instr[0] <= 0;
        end
        
        if(back_nonspeculative[1] && instr_ready[back_ptr+1] && valid[back_ptr+1]) begin
            //valid[back_ptr] <= 0;
            //back_ptr <= back_ptr + 1;
            //t_dout <= outgoing_latch;
            t_dout[1] <= (((back_ptr+1) % 2) == 0) ? dout[0] : dout[1];
            outgoing_instr[1] <= 1;
        end else begin
            outgoing_instr[1] <= 0;
        end
    end
    
    logic [$clog2(SIZE/2)-1:0] read_addr [2];
    always_comb begin
        if((back_ptr % 2) == 0) begin
            read_addr[0] = back_ptr >> 1;
            read_addr[1] = back_ptr >> 1;
        end else if((back_ptr % 2) == 1) begin
            read_addr[0] = (back_ptr + 1) >> 1;
            read_addr[1] = back_ptr >> 1;
        end
    end
    
    logic [$clog2(SIZE)-1:0] access_addr [2];
    assign access_addr[0] = clk ? write_addr[0] : read_addr[0];
    assign access_addr[1] = clk ? write_addr[1] : read_addr[1];
    
    distributed_ram #(
        .WIDTH(payload_width),
        .DEPTH(SIZE)
    )BANK0(
        .clk,
        .addr(access_addr[0]),
        .we(we[0]),
        .din(din[0]),
        .dout(dout[0])
    );
    
    distributed_ram #(
        .WIDTH(payload_width),
        .DEPTH(SIZE)
    )BANK1(
        .clk,
        .addr(access_addr[1]),
        .we(we[1]),
        .din(din[1]),
        .dout(dout[1])
    );
    
    always_ff @(posedge clk) begin
        if(reset) begin
            front_ptr <= 0;
            back_ptr <= 0;
            valid <= 0;
            o_miq[0].valid <= 0;
            o_miq[1].valid <= 0;
        end else begin
            if(if_recall) begin
                front_ptr <= new_queue_front;
                for(int i = 0; i < SIZE; i++) begin
                    if(flush_mask[i] && if_recall) begin
                        valid[i] <= 0;
                    end
                end
            end else begin
                if(incoming_in_order[0] && incoming_in_order[1] && ~int_stall && ~if_recall) begin
                    front_ptr <= front_ptr + 2;
                        
                    rs1[front_ptr] <= i_ren[0].rs1;
                    rs2[front_ptr] <= i_ren[0].rs2;
                    uses_rs1[front_ptr] <= i_ren[0].uses_rs1;
                    uses_rs2[front_ptr] <= i_ren[0].uses_rs2;
                    valid[front_ptr] <= 1;
                    al_addrs[front_ptr] <= i_ren[0].al_addr;
                    
                    rs1[front_ptr+1] <= i_ren[1].rs1;
                    rs2[front_ptr+1] <= i_ren[1].rs2;
                    uses_rs1[front_ptr+1] <= i_ren[1].uses_rs1;
                    uses_rs2[front_ptr+1] <= i_ren[1].uses_rs2;
                    valid[front_ptr+1] <= 1;
                    al_addrs[front_ptr+1] <= i_ren[1].al_addr;
                end else if(incoming_in_order[0] && ~int_stall) begin
                    front_ptr <= front_ptr + 1;
                    rs1[front_ptr] <= i_ren[0].rs1;
                    rs2[front_ptr] <= i_ren[0].rs2;
                    uses_rs1[front_ptr] <= i_ren[0].uses_rs1;
                    uses_rs2[front_ptr] <= i_ren[0].uses_rs2;
                    valid[front_ptr] <= 1;
                    al_addrs[front_ptr] <= i_ren[0].al_addr;
                end else if(incoming_in_order[1] && ~int_stall) begin
                    front_ptr <= front_ptr + 1;
                    rs1[front_ptr] <= i_ren[1].rs1;
                    rs2[front_ptr] <= i_ren[1].rs2;
                    uses_rs1[front_ptr] <= i_ren[1].uses_rs1;
                    uses_rs2[front_ptr] <= i_ren[1].uses_rs2;
                    valid[front_ptr] <= 1;
                    al_addrs[front_ptr] <= i_ren[1].al_addr;
                end
            end
            
            if(outgoing_instr[0] && ((~flush_mask[back_ptr] && if_recall) || ~if_recall) && valid[back_ptr] && outgoing_instr[1] && 
                ((~flush_mask[back_ptr+1] && if_recall) || ~if_recall) && valid[back_ptr+1]) begin
                back_ptr <= back_ptr + 2;
                valid[back_ptr] <= 0;
                valid[back_ptr+1] <= 0;
                
                o_miq[0].valid <= 1;
                o_miq[0].pc <= t_dout[0][0+:`ADDR_WIDTH];
                o_miq[0].rs1 <= rs1[back_ptr];
                o_miq[0].rs2 <= rs2[back_ptr];
                o_miq[0].rd <= t_dout[0][`ADDR_WIDTH+:$clog2(`NUM_PR)];
                o_miq[0].uses_rs1 <= uses_rs1[back_ptr];
                o_miq[0].uses_rs2 <= uses_rs2[back_ptr];
                o_miq[0].uses_rd <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)];
                o_miq[0].uses_imm <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+33];
                o_miq[0].imm <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+1+:32];
                o_miq[0].is_mem_access <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+34];
                o_miq[0].mem_access_type <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+35];
                o_miq[0].width <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+36+:3];
                o_miq[0].al_addr <= al_addrs[back_ptr];
                
                o_miq[1].valid <= 1;
                o_miq[1].pc <= t_dout[1][0+:`ADDR_WIDTH];
                o_miq[1].rs1 <= rs1[back_ptr+1];
                o_miq[1].rs2 <= rs2[back_ptr+1];
                o_miq[1].rd <= t_dout[1][`ADDR_WIDTH+:$clog2(`NUM_PR)];
                o_miq[1].uses_rs1 <= uses_rs1[back_ptr+1];
                o_miq[1].uses_rs2 <= uses_rs2[back_ptr+1];
                o_miq[1].uses_rd <= t_dout[1][`ADDR_WIDTH+$clog2(`NUM_PR)];
                o_miq[1].uses_imm <= t_dout[1][`ADDR_WIDTH+$clog2(`NUM_PR)+33];
                o_miq[1].imm <= t_dout[1][`ADDR_WIDTH+$clog2(`NUM_PR)+1+:32];
                o_miq[1].is_mem_access <= t_dout[1][`ADDR_WIDTH+$clog2(`NUM_PR)+34];
                o_miq[1].mem_access_type <= t_dout[1][`ADDR_WIDTH+$clog2(`NUM_PR)+35];
                o_miq[1].width <= t_dout[1][`ADDR_WIDTH+$clog2(`NUM_PR)+36+:3];
                o_miq[1].al_addr <= al_addrs[back_ptr+1];
            end else if(outgoing_instr[0] && ((~flush_mask[back_ptr] && if_recall) || ~if_recall) && valid[back_ptr]) begin
                back_ptr <= back_ptr + 1;
                valid[back_ptr] <= 0;
                
                o_miq[0].valid <= 1;
                o_miq[0].pc <= t_dout[0][0+:`ADDR_WIDTH];
                o_miq[0].rs1 <= rs1[back_ptr];
                o_miq[0].rs2 <= rs2[back_ptr];
                o_miq[0].rd <= t_dout[0][`ADDR_WIDTH+:$clog2(`NUM_PR)];
                o_miq[0].uses_rs1 <= uses_rs1[back_ptr];
                o_miq[0].uses_rs2 <= uses_rs2[back_ptr];
                o_miq[0].uses_rd <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)];
                o_miq[0].uses_imm <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+33];
                o_miq[0].imm <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+1+:32];
                o_miq[0].is_mem_access <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+34];
                o_miq[0].mem_access_type <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+35];
                o_miq[0].width <= t_dout[0][`ADDR_WIDTH+$clog2(`NUM_PR)+36+:3];
                o_miq[0].al_addr <= al_addrs[back_ptr];
                
                o_miq[1].valid <= 0;
                o_miq[1].pc <= 0;
                o_miq[1].rs1 <= 0;
                o_miq[1].rs2 <= 0;
                o_miq[1].rd <= 0;
                o_miq[1].uses_rs1 <= 0;
                o_miq[1].uses_rs2 <= 0;
                o_miq[1].uses_rd <= 0;
                o_miq[1].uses_imm <= 0;
                o_miq[1].imm <= 0;
                o_miq[1].is_mem_access <= 0;
                o_miq[1].mem_access_type <= READ;
                o_miq[1].width <= 0;
                o_miq[1].al_addr <= 0;
            end else begin
                o_miq[0].valid <= 0;
                o_miq[0].pc <= 0;
                o_miq[0].rs1 <= 0;
                o_miq[0].rs2 <= 0;
                o_miq[0].rd <= 0;
                o_miq[0].uses_rs1 <= 0;
                o_miq[0].uses_rs2 <= 0;
                o_miq[0].uses_rd <= 0;
                o_miq[0].uses_imm <= 0;
                o_miq[0].imm <= 0;
                o_miq[0].is_mem_access <= 0;
                o_miq[0].mem_access_type <= READ;
                o_miq[0].width <= 0;
                o_miq[0].al_addr <= 0;
                
                o_miq[1].valid <= 0;
                o_miq[1].pc <= 0;
                o_miq[1].rs1 <= 0;
                o_miq[1].rs2 <= 0;
                o_miq[1].rd <= 0;
                o_miq[1].uses_rs1 <= 0;
                o_miq[1].uses_rs2 <= 0;
                o_miq[1].uses_rd <= 0;
                o_miq[1].uses_imm <= 0;
                o_miq[1].imm <= 0;
                o_miq[1].is_mem_access <= 0;
                o_miq[1].mem_access_type <= READ;
                o_miq[1].width <= 0;
                o_miq[1].al_addr <= 0;
            end
        end 
    end
    
    
    //in the case that the write back for one of the registers occurs before it is in the issue queue, but after
    //the busy bit table has been read, you need to overwrite the value that you read from the bbt
    logic incoming_overwrite_rs1 [2];
    logic incoming_overwrite_rs2 [2];
    
    assign incoming_overwrite_rs1[0] = i_ren[0].uses_rs1 && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == i_ren[0].rs1)) || (i_wb[1].valid && 
        i_wb[1].uses_rd && (i_wb[1].rd == i_ren[0].rs1)) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == i_ren[0].rs1)) || (i_wb[3].valid && 
        i_wb[3].uses_rd && (i_wb[3].rd == i_ren[0].rs1)));
    assign incoming_overwrite_rs1[1] = i_ren[1].uses_rs1 && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == i_ren[1].rs1)) || (i_wb[1].valid && 
        i_wb[1].uses_rd && (i_wb[1].rd == i_ren[1].rs1)) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == i_ren[1].rs1)) || (i_wb[3].valid && 
        i_wb[3].uses_rd && (i_wb[3].rd == i_ren[1].rs1)));
        
    assign incoming_overwrite_rs2[0] = i_ren[0].uses_rs2 && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == i_ren[0].rs2)) || (i_wb[1].valid && 
        i_wb[1].uses_rd && (i_wb[1].rd == i_ren[0].rs2)) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == i_ren[0].rs2)) || (i_wb[3].valid && 
        i_wb[3].uses_rd && (i_wb[3].rd == i_ren[0].rs2))); 
    assign incoming_overwrite_rs2[1] = i_ren[1].uses_rs2 && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == i_ren[1].rs2)) || (i_wb[1].valid && 
        i_wb[1].uses_rd && (i_wb[1].rd == i_ren[1].rs2)) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == i_ren[1].rs2)) || (i_wb[3].valid && 
        i_wb[3].uses_rd && (i_wb[3].rd == i_ren[1].rs2)));
    
    genvar j;
    generate
        //loop for incoming[0] for rs1
        for(j = 0; j < SIZE; j++) begin
            always_ff @(posedge clk) begin
                //you dont need to check incoming_in_order[1] as this will always go at front_ptr if incoming_in_order[0] is valid
                if(incoming_in_order[0] && (front_ptr == j)) begin
                    rs1_ready[j] <= i_ren[0].rs1_ready || incoming_overwrite_rs1[0];
                end else if(valid[j] && uses_rs1[j] && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == rs1[j])) || (i_wb[1].valid && i_wb[1].uses_rd 
                    && (i_wb[1].rd == rs1[j])) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == rs1[j])) || (i_wb[3].valid && i_wb[3].uses_rd && 
                    (i_wb[3].rd == rs1[j])))) begin //snoop the wb interface to check if the reg is ready
                    
                    rs1_ready[j] <= 1;
                end
            end
        end
        
        //loop for incoming[0] for rs2
        for(j = 0; j < SIZE; j++) begin
            always_ff @(posedge clk) begin
                if(incoming_in_order[0] && (front_ptr == j)) begin
                    rs2_ready[j] <= i_ren[0].rs2_ready || incoming_overwrite_rs2[0];
                end else if(valid[j] && uses_rs2[j] && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == rs2[j])) || (i_wb[1].valid && i_wb[1].uses_rd 
                    && (i_wb[1].rd == rs2[j])) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == rs2[j])) ||  (i_wb[3].valid && i_wb[3].uses_rd && 
                    (i_wb[3].rd == rs2[j])))) begin
                    
                    rs2_ready[j] <= 1;
                end
            end
        end
        
        //loop for incoming[1] for rs1
        for(j = 0; j < SIZE; j++) begin
            always_ff @(posedge clk) begin
                //you need to check incoming_in_order[0] as incoming[1] can go at front_ptr or front_ptr + 1
                if(incoming_in_order[0] && incoming_in_order[1] && ((front_ptr+1) == j)) begin
                    rs1_ready[j] <= i_ren[1].rs1_ready || incoming_overwrite_rs1[1];
                end else if(~incoming_in_order[0] && incoming_in_order[1] && (front_ptr == j)) begin
                    rs1_ready[j] <= i_ren[1].rs1_ready || incoming_overwrite_rs1[1];
                end else if(valid[j] && uses_rs1[j] && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == rs1[j])) || (i_wb[1].valid && i_wb[1].uses_rd 
                    && (i_wb[1].rd == rs1[j])) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == rs1[j])) || (i_wb[3].valid && i_wb[3].uses_rd && 
                    (i_wb[3].rd == rs1[j])))) begin //snoop the wb interface to check if the reg is ready
                    
                    rs1_ready[j] <= 1;
                end
            end
        end
        
        //loop for incoming[1] for rs2
        for(j = 0; j < SIZE; j++) begin
            always_ff @(posedge clk) begin
                if(incoming_in_order[0] && incoming_in_order[1] && ((front_ptr+1) == j)) begin
                    rs2_ready[j] <= i_ren[1].rs2_ready || incoming_overwrite_rs2[1];
                end else if(~incoming_in_order[0] && incoming_in_order[1] && (front_ptr == j)) begin
                    rs2_ready[j] <= i_ren[1].rs2_ready || incoming_overwrite_rs2[1];
                end else if(valid[j] && uses_rs2[j] && ((i_wb[0].valid && i_wb[0].uses_rd && (i_wb[0].rd == rs2[j])) || (i_wb[1].valid && i_wb[1].uses_rd 
                    && (i_wb[1].rd == rs2[j])) || (i_wb[2].valid && i_wb[2].uses_rd && (i_wb[2].rd == rs2[j])) ||  (i_wb[3].valid && i_wb[3].uses_rd && 
                    (i_wb[3].rd == rs2[j])))) begin
                    
                    rs2_ready[j] <= 1;
                end
            end
        end
    endgenerate
endmodule
