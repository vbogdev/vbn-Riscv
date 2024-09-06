`timescale 1ns / 1ps
`include "riscv_core.svh"

module write_back_stage(
    input clk,
    input if_recall,
    input [$clog2(`AL_SIZE)-1:0] new_front, old_front, back,
    wb_ifc.in i_wb [4],
    wb_ifc.out o_wb_s1 [4],
    wb_ifc.out o_wb_s2 [4]
    );
    
    assign o_wb_s1[0].valid = i_wb[0].valid;
    assign o_wb_s1[0].al_idx = i_wb[0].al_idx;
    assign o_wb_s1[0].data = i_wb[0].data;
    assign o_wb_s1[0].rd = i_wb[0].rd;
    assign o_wb_s1[0].uses_rd = i_wb[0].uses_rd;
    assign o_wb_s1[1].valid = i_wb[1].valid;
    assign o_wb_s1[1].al_idx = i_wb[1].al_idx;
    assign o_wb_s1[1].data = i_wb[1].data;
    assign o_wb_s1[1].rd = i_wb[1].rd;
    assign o_wb_s1[1].uses_rd = i_wb[1].uses_rd;
    assign o_wb_s1[2].valid = i_wb[2].valid;
    assign o_wb_s1[2].al_idx = i_wb[2].al_idx;
    assign o_wb_s1[2].data = i_wb[2].data;
    assign o_wb_s1[2].rd = i_wb[2].rd;
    assign o_wb_s1[2].uses_rd = i_wb[2].uses_rd;
    assign o_wb_s1[3].valid = i_wb[3].valid;
    assign o_wb_s1[3].al_idx = i_wb[3].al_idx;
    assign o_wb_s1[3].data = i_wb[3].data;
    assign o_wb_s1[3].rd = i_wb[3].rd;
    assign o_wb_s1[3].uses_rd = i_wb[3].uses_rd;
    
    logic [3:0] valid_mask, flush_mask;
    logic [$clog2(`AL_SIZE)-1:0] al_idx_mask [4];
    genvar i;
    generate
        for(i = 0; i < 4; i++) begin
            assign valid_mask[i] = i_wb[i].valid;
            assign al_idx_mask[i] = i_wb[i].al_idx;
        end
    endgenerate
    
    undo_checkpoint_module #(.DEPTH(4)) UCM (
        .new_front, .old_front, .back,
        .list(al_idx_mask),
        .i_valid(valid_mask),
        .flush_mask
    );
    
    always_ff @(posedge clk) begin
        o_wb_s2[0].valid <= i_wb[0].valid && ~flush_mask[0];
        o_wb_s2[0].al_idx <= i_wb[0].al_idx;
        o_wb_s2[0].data <= i_wb[0].data;
        o_wb_s2[0].rd <= i_wb[0].rd;
        o_wb_s2[0].uses_rd <= i_wb[0].uses_rd;
        o_wb_s2[1].valid <= i_wb[1].valid && ~flush_mask[1];
        o_wb_s2[1].al_idx <= i_wb[1].al_idx;
        o_wb_s2[1].data <= i_wb[1].data;
        o_wb_s2[1].rd <= i_wb[1].rd;
        o_wb_s2[1].uses_rd <= i_wb[1].uses_rd;
        o_wb_s2[2].valid <= i_wb[2].valid && ~flush_mask[2];
        o_wb_s2[2].al_idx <= i_wb[2].al_idx;
        o_wb_s2[2].data <= i_wb[2].data;
        o_wb_s2[2].rd <= i_wb[2].rd;
        o_wb_s2[2].uses_rd <= i_wb[2].uses_rd;
        o_wb_s2[3].valid <= i_wb[3].valid && ~flush_mask[3];
        o_wb_s2[3].al_idx <= i_wb[3].al_idx;
        o_wb_s2[3].data <= i_wb[3].data;
        o_wb_s2[3].rd <= i_wb[3].rd;
        o_wb_s2[3].uses_rd <= i_wb[3].uses_rd;
    end

endmodule
