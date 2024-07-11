`timescale 1ns / 1ps


module top(
    input reset,
    input sys_clk_pin,
    input set,
    input run,
    input [3:0] switches,
    input [12:0] inputs,
    output logic [14:0] outputs
    );
    
    logic clk, locked;
    clk_100_mhz CLK_MANAGER(
        .clk_out1(clk), 
        .reset(reset), // input reset
        .locked(locked),       // output locked
        .clk_in(sys_clk_pin)      // input clk_in
    );
    
    logic [207:0] input_bus, setup_bus;
    logic [239:0] output_bus;
    
    always_ff @(posedge clk) begin
        if(run) begin
            input_bus <= setup_bus;
        end
        if(set) begin
            case(switches) 
                4'b0000: setup_bus[12:0] <= inputs;
                4'b0001: setup_bus[25:13] <= inputs;
                4'b0010: setup_bus[38:26] <= inputs;
                4'b0011: setup_bus[51:39] <= inputs;
                4'b0100: setup_bus[64:52] <= inputs;
                4'b0101: setup_bus[77:65] <= inputs;
                4'b0110: setup_bus[90:78] <= inputs;
                4'b0111: setup_bus[103:91] <= inputs;
                4'b1000: setup_bus[116:104] <= inputs;
                4'b1001: setup_bus[129:117] <= inputs;
                4'b1010: setup_bus[142:130] <= inputs;
                4'b1011: setup_bus[155:143] <= inputs;
                4'b1100: setup_bus[168:156] <= inputs;
                4'b1101: setup_bus[181:169] <= inputs;
                4'b1110: setup_bus[194:182] <= inputs;
                default: setup_bus[207:195] <= inputs;
            endcase
        end
    end
    
    always_comb begin
        outputs = 10'b0;
        case(switches) 
            4'b0000: outputs = output_bus[14:0];
            4'b0001: outputs = output_bus[29:15];
            4'b0010: outputs = output_bus[44:30];
            4'b0011: outputs = output_bus[59:45];
            4'b0100: outputs = output_bus[74:60];
            4'b0101: outputs = output_bus[89:75];
            4'b0110: outputs = output_bus[104:90];
            4'b0111: outputs = output_bus[119:105];
            4'b1000: outputs = output_bus[134:120];
            4'b1001: outputs = output_bus[149:135];
            4'b1010: outputs = output_bus[164:150];
            4'b1011: outputs = output_bus[179:165];
            4'b1100: outputs = output_bus[194:180];
            4'b1101: outputs = output_bus[209:195];
            4'b1110: outputs = output_bus[224:210];
            4'b1111: outputs = {{10{1'b0}}, output_bus[229:225]};
        endcase
    end
    
    
    
    branch_fb_ifc branch_fb[2]();
    branch_fb_decode_ifc decode_fb();
    logic ext_stall, ext_flush;
    logic stall_decode, stall_fetch, stall_rename;
    assign stall_decode = stall_rename;
    assign stall_fetch = stall_decode;
    fetch_out_ifc instr[2]();
    decode_out_ifc dec_out[2]();
    rename_out_ifc ren_out[2]();
    wb_ifc wb [4]();
    
    assign branch_fb[0].if_branch = input_bus[0];
    assign branch_fb[0].if_prediction_correct = input_bus[1];
    assign branch_fb[0].outcome = input_bus[2] ? TAKEN : NOT_TAKEN;
    assign branch_fb[0].branch_pc = input_bus[34:3];
    assign branch_fb[0].new_pc = input_bus[66:35];
    assign branch_fb[1].if_branch = input_bus[67];
    assign branch_fb[1].if_prediction_correct = input_bus[68];
    assign branch_fb[1].outcome = input_bus[69] ? TAKEN : NOT_TAKEN;
    assign branch_fb[1].branch_pc = input_bus[101:70];
    assign branch_fb[1].new_pc = input_bus[133:102];
    assign ext_stall = input_bus[134];
    assign ext_flush = input_bus[135];
    assign wb[0].valid = input_bus[136];
    assign wb[0].al_idx = input_bus[142:137];
    assign wb[0].rd = input_bus[148:143];
    assign wb[0].uses_rd = input_bus[149];
    assign wb[1].valid = input_bus[150];
    assign wb[1].al_idx = input_bus[156:151];
    assign wb[1].rd = input_bus[162:157];
    assign wb[1].uses_rd = input_bus[163];
    assign wb[2].valid = input_bus[164];
    assign wb[2].al_idx = input_bus[170:165];
    assign wb[2].rd = input_bus[176:171];
    assign wb[2].uses_rd = input_bus[177];
    assign wb[3].valid = input_bus[178];
    assign wb[3].al_idx = input_bus[184:179];
    assign wb[3].rd = input_bus[190:185];
    assign wb[3].uses_rd = input_bus[191];
    assign branch_fb[0].cp_addr = input_bus[197:192];
    assign branch_fb[1].cp_addr = input_bus[203:198];
    
    assign output_bus[0] = ren_out[0].valid;
    assign output_bus[1] = ren_out[0].uses_rd;
    assign output_bus[2] = ren_out[0].uses_rs1;
    assign output_bus[3] = ren_out[0].uses_rs2;
    assign output_bus[4] = ren_out[0].uses_imm;
    assign output_bus[10:5] = ren_out[0].rd;
    assign output_bus[16:11] = ren_out[0].rs1;
    assign output_bus[22:17] = ren_out[0].rs2;
    assign output_bus[54:23] = ren_out[0].imm;
    assign output_bus[86:55] = ren_out[0].target;
    assign output_bus[87] = ren_out[0].is_branch;
    assign output_bus[88] = ren_out[0].is_jump;
    assign output_bus[89] = ren_out[0].is_jump_register;
    assign output_bus[90] = ren_out[0].is_mem_access;
    assign output_bus[91] = ren_out[0].accesses_csr;
    assign output_bus[103:92] = ren_out[0].csr_addr;
    assign output_bus[104] = ren_out[0].ecall;
    assign output_bus[105] = ren_out[0].ebreak;
    assign output_bus[106] = ren_out[0].amo_instr;
    assign output_bus[107] = ren_out[0].aq;
    assign output_bus[108] = ren_out[0].rl;
    assign output_bus[0+109] = ren_out[1].valid;
    assign output_bus[1+109] = ren_out[1].uses_rd;
    assign output_bus[2+109] = ren_out[1].uses_rs1;
    assign output_bus[3+109] = ren_out[1].uses_rs2;
    assign output_bus[4+109] = ren_out[1].uses_imm;
    assign output_bus[10+109:5+109] = ren_out[1].rd;
    assign output_bus[16+109:11+109] = ren_out[1].rs1;
    assign output_bus[22+109:17+109] = ren_out[1].rs2;
    assign output_bus[54+109:23+109] = ren_out[1].imm;
    assign output_bus[86+109:55+109] = ren_out[1].target;
    assign output_bus[87+109] = ren_out[1].is_branch;
    assign output_bus[88+109] = ren_out[1].is_jump;
    assign output_bus[89+109] = ren_out[1].is_jump_register;
    assign output_bus[90+109] = ren_out[1].is_mem_access;
    assign output_bus[91+109] = ren_out[1].accesses_csr;
    assign output_bus[103+109:92+109] = ren_out[1].csr_addr;
    assign output_bus[104+109] = ren_out[1].ecall;
    assign output_bus[105+109] = ren_out[1].ebreak;
    assign output_bus[106+109] = ren_out[1].amo_instr;
    assign output_bus[107+109] = ren_out[1].aq;
    assign output_bus[108+109] = ren_out[1].rl;
    assign output_bus[223:218] = ren_out[0].al_addr;
    assign output_bus[229:224] = ren_out[1].al_addr;
    
    
    fetch_stage FETCH(
        .clk, .reset,
        .branch_fb,
        .decode_fb,
        .ext_stall(stall_fetch), .ext_flush,
        .o_instr(instr)
    );
    
    decode_stage DECODE(
        .clk, .reset,
        .i_fetch(instr),
        .ext_stall(stall_decode), .ext_flush,
        .o_decode(dec_out),
        .o_fb(decode_fb)
    );
    
    rename_stage RENAME(
        .clk, .reset,
        .ext_stall, .ext_flush,
        .i_decode(dec_out),
        .i_branch_fb(branch_fb),
        .i_wb(wb),
        .o_renamed(ren_out),
        .int_stall(stall_rename)
    );
    
endmodule
