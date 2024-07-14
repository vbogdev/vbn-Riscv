`timescale 1ns / 1ps


module top(
    input reset,
    input sys_clk_pin,
    input [3:0] switches,
    input set,
    input [9:0] inputs,
    output logic [3:0] r1
    );
    
    logic clk, locked;
    /*clk_100_mhz CLK_MANAGER(
        .clk_out1(clk), 
        .reset(reset), // input reset
        .locked(locked),       // output locked
        .clk_in(sys_clk_pin)      // input clk_in
    );*/
    assign clk = sys_clk_pin;
    
    logic [159:0] reg_inputs, direct_inputs;
    always_ff @(posedge clk) begin
        if(set) begin
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
    branch_fb_decode_ifc branch_fb_dec();
    logic ext_stall_fetch, ext_flush_fetch;
    assign ext_flush_fetch = 0;
    fetch_out_ifc fetch_out[2]();
    logic [31:0] fetch_addr;
    logic fetch_addr_valid;
    logic [63:0] fetched_data;
    
    assign fetch_addr = direct_inputs[31:0];
    assign fetch_addr_valid = direct_inputs[32];
    assign fetched_data = direct_inputs[96:33];
    
    //decode ifcs and vars
    logic ext_stall_dec, ext_flush_dec;
    assign ext_flush_dec = 0;
    decode_out_ifc dec_out[2]();
    
    //rename ifcs and vars
    logic ext_stall_ren, ext_flush_ren;
    //assign ext_stall_ren = 0;
    assign ext_flush_ren = 0;
    wb_ifc wb[2]();
    rename_out_ifc ren_out[2]();
    logic int_stall_ren;
    logic [63:0] bbt;
    assign ext_stall_dec = int_stall_ren;
    assign ext_stall_fetch = int_stall_ren;
    
    
    logic [$clog2(`AL_SIZE)-1:0] new_front, old_front, back;
    logic if_recall;
    assign if_recall = 0;
    assign new_front = 0;
    assign old_front = 0;
    assign back = 0;

    
    //issue ifcs and vars
    logic ext_stall_iss;
    aiq_ifc issue_out[2]();
    
    //reg read ifcs and vars
    logic ext_stall_reg;
    aiq_ifc reg_out[2]();
    reg_out_ifc reg_out_data[2]();
    
    
    
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
        .bbt(bbt),
        .int_stall(int_stall_ren)
    );
    
    issue_stage ISSUE_STAGE(
        .clk, .reset,
        .ext_stall(1'b0),
        .i_ren(ren_out),
        .if_recall,
        .new_front,
        .old_front,
        .back,
        .bbt,
        .o_iq(issue_out),
        .int_stall(ext_stall_ren)
    );
    
    reg_read_stage REG_READ_STAGE(
        .clk, .reset,
        .ext_stall(1'b0),
        .if_recall,
        .new_front,
        .old_front,
        .back,
        .i_arith(issue_out),
        .i_wb(wb),
        .o_arith(reg_out),
        .o_regs(reg_out_data)
    );
    
    arith_ex_stage ARITH_EX_STAGE(
        .clk, .if_recall, .new_front, .old_front, .back,
        .i_aiq(reg_out),
        .i_regs(reg_out_data),
        .o_wb(wb),
        .o_fb(branch_fb)
    );
    
    always_comb begin
        case(switches) 
            4'b0000: begin
                 r1 = wb[0].data[3:0];
            end
            4'b0001: begin
                 r1 = wb[0].data[7:4];
            end
            4'b0010: begin
                 r1 = wb[0].data[11:8];
            end
            4'b0011: begin
                 r1 = wb[0].data[15:12];
            end
            4'b0100: begin
                 r1 = wb[0].data[19:16];
            end
            4'b0101: begin
                 r1 = wb[0].data[23:20];
            end
            4'b0110: begin
                 r1 = wb[0].data[27:24];
            end
            4'b0111: begin
                 r1 = wb[0].data[31:28];
            end
            4'b1000: begin
                r1 = wb[1].data[3:0];
            end
            4'b1001: begin
                r1 = wb[1].data[7:4];
            end
            4'b1010: begin
                r1 = wb[1].data[11:8];
            end
            4'b1011: begin
                r1 = wb[1].data[15:12];
            end
            4'b1100: begin
                r1 = wb[1].data[19:16];
            end
            4'b1101: begin
                r1 = wb[1].data[23:20];
            end
            4'b1110: begin
                r1 = wb[1].data[27:24];
            end
            4'b1111: begin
                r1 = wb[1].data[31:28];
            end
        endcase
    end
    
endmodule
