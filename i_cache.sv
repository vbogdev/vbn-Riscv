`timescale 1ns / 1ps
`include "riscv_core.svh"

module i_cache #(
    parameter DEPTH = 512,
    parameter LINE_SIZE = 2
    )(
    input clk, reset,
    input [`ADDR_WIDTH-1:0] read_addr [2],
    input read_addr_valid [2],
    input [`ADDR_WIDTH-1:0] fetch_addr,
    input fetch_addr_valid,
    input [32*LINE_SIZE-1:0] fetched_data,
    input ext_stall, ext_flush,
    output logic [31:0] read_instr [2],
    output logic valid_read [2],
    output logic miss [2],
    output logic int_stall,
    output logic [`ADDR_WIDTH-1:0] prev_read_addr [2]
    );
    
    localparam TAG_SIZE = `ADDR_WIDTH - 2 - $clog2(LINE_SIZE) - $clog2(DEPTH);
    localparam TOTAL_LINE_SIZE = LINE_SIZE * 32 + TAG_SIZE + 1; //line + tag + valid bit
    localparam IDX_SIZE = $clog2(DEPTH);
    
    //pipeline registers
    logic [`ADDR_WIDTH-1:0] already_read_addr [2];
    logic compare_tags_s2 [2]; //register if data read from bram on miss needs to send a request
    
    //wires to connect to bram
    logic [IDX_SIZE-1:0] access_idx [2];
    logic [TOTAL_LINE_SIZE-1:0] access_data [2];
    logic [TOTAL_LINE_SIZE-1:0] access_din [2];
    logic access_we [2];
    logic compare_tags_s1 [2]; //wire if incoming instruction will need to send request on miss
    
    logic [`ADDR_WIDTH-1:0] s1_pcs [2];
    
    logic [1:0] num_reads, num_writes;
    logic [2:0] num_ports_needed;
    always_comb begin
        num_reads = read_addr_valid[0] + read_addr_valid[1];
        num_writes = fetch_addr_valid;
        num_ports_needed = num_reads + num_writes;
        if((num_ports_needed > 2) || miss[0] || miss[1]) begin
            int_stall = 1;
        end else begin
            int_stall = 0;
        end 
    end
     
    
    function [IDX_SIZE-1:0] getIdx(input [`ADDR_WIDTH-1:0] addr);
       getIdx = addr[`ADDR_WIDTH-TAG_SIZE-1:2+$clog2(LINE_SIZE)];
    endfunction
    
    function [TAG_SIZE-1:0] getTag(input [`ADDR_WIDTH-1:0] addr);
       getTag = addr[`ADDR_WIDTH-1:`ADDR_WIDTH-TAG_SIZE];
    endfunction
    
    function [$clog2(LINE_SIZE)-1:0] getOffSet(input [`ADDR_WIDTH-1:0] addr);
        getOffSet = addr[$clog2(LINE_SIZE)-1+LINE_SIZE:LINE_SIZE];
    endfunction
    
    logic fetch_forwarding_valid;
    logic [`ADDR_WIDTH-1:0] fetch_forwarding_addr;
    logic [LINE_SIZE*32-1:0] fetch_forwarding_line;
    
    
    always_comb begin
        //default values for not changing the cache state
        access_we[0] = 0;
        access_we[1] = 0; 
        compare_tags_s1[0] = 0;
        compare_tags_s1[1] = 0;
        access_din[0] = 0;
        access_din[1] = 0;
        s1_pcs[0] = 0;
        s1_pcs[1] = 0;
        access_idx[0] = 0;
        access_idx[1] = 0;
        
        if(ext_stall) begin
            
        end else if (ext_flush) begin
            
        end else begin
            //huge if statement which selects what the ports are used for
            if(fetch_addr_valid) begin
                
                access_we[0] = 1;
                access_din[0] = {1'd1, getTag(fetch_addr), fetched_data};
                access_idx[0] = getIdx(fetch_addr);
                s1_pcs[0] = fetch_addr;
                
                if(read_addr_valid[0]) begin
                    compare_tags_s1[1] = 1;
                    access_idx[1] = getIdx(read_addr[0]);
                    s1_pcs[1] = read_addr[0];
                end else if(read_addr_valid[1]) begin
                    compare_tags_s1[1] = 1;
                    access_idx[1] = getIdx(read_addr[1]);
                    s1_pcs[1] = read_addr[1];
                end else begin

                end
            end else begin
                if(read_addr_valid[0] && read_addr_valid[1]) begin
                    compare_tags_s1[0] = 1;
                    access_idx[0] = getIdx(read_addr[0]);
                    s1_pcs[0] = read_addr[0];
                    compare_tags_s1[1] = 1;
                    access_idx[1] = getIdx(read_addr[1]);
                    s1_pcs[1] = read_addr[1];
                end else if(read_addr_valid[0] && ~read_addr_valid[1]) begin
                    compare_tags_s1[0] = 1;
                    access_idx[0] = getIdx(read_addr[0]);
                    s1_pcs[0] = read_addr[0];
                end else if(~read_addr_valid[0] && read_addr_valid[1]) begin
                    compare_tags_s1[0] = 1;
                    access_idx[0] = getIdx(read_addr[1]);
                    s1_pcs[0] = read_addr[1];
                end else begin
                
                end
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if(~ext_flush && ~ext_stall) begin
            for(int i = 0; i < 2; i++) begin
                already_read_addr[i] <= s1_pcs[i];
                compare_tags_s2[i] <= compare_tags_s1[i];
            end
        end
        
        fetch_forwarding_valid <= fetch_addr_valid;
        fetch_forwarding_addr <= fetch_addr;
        fetch_forwarding_line <= fetched_data;
    end
    
    bram_block #(
        .WIDTH(TOTAL_LINE_SIZE),
        .DEPTH(DEPTH)
    ) CACHE_MEM (
        .clk, .reset,
        .addr(access_idx),
        .we(access_we),
        .din(access_din),
        .dout(access_data)
    );
    
    
    logic [TAG_SIZE-1:0] s2_tags [2];
    logic [IDX_SIZE-1:0] s2_idxs [2];
    logic [TAG_SIZE-1:0] data_tags [2];
    logic [TAG_SIZE-1:0] forward_tag;
    logic [IDX_SIZE-1:0] forward_idx;
    
    logic [31:0] forward_line_broken [LINE_SIZE];
    logic [31:0] line1 [LINE_SIZE];
    logic [31:0] line2 [LINE_SIZE];
    always_comb begin 
        for(int i = 0; i < LINE_SIZE; i++) begin
            forward_line_broken[i] = fetch_forwarding_line[i * 32 +: 32];
            line1[i] = access_data[0][i*32 +: 32];
            line2[i] = access_data[1][i*32 +: 32];
        end
    end
    
    
    
     
    always_ff @(posedge clk) begin
        if(reset) begin
            miss[0] <= 0;
            read_instr[0] <= 'h23;
            prev_read_addr[0] <= 0;
        end else if(compare_tags_s2[0] && fetch_forwarding_valid && (forward_tag == s2_tags[0]) && (s2_idxs[0] == forward_idx)) begin
            miss[0] <= 0;
            read_instr[0] <= forward_line_broken[getOffSet(fetch_forwarding_addr)];
            prev_read_addr[0] <= fetch_forwarding_addr;
        end else if(compare_tags_s2[0] && (access_data[0][TOTAL_LINE_SIZE-1] && (data_tags[0] == s2_tags[0])) && (s2_idxs[0] == getIdx(already_read_addr[0]))) begin
            miss[0] <= 0;
            read_instr[0] <= line1[getOffSet(already_read_addr[0])];
            prev_read_addr[0] <= already_read_addr[0];
        end else if (~compare_tags_s2[0]) begin
            miss[0] <= 0;
            read_instr[0] <= 0;
            prev_read_addr[0] <= 0;
        end else begin
            miss[0] <= 1;
            read_instr[0] <= 0;
            prev_read_addr[0] <= 0;
        end
        
        if(reset) begin
            miss[1] <= 0;
            read_instr[1] <= 'h23;
            prev_read_addr[1] <= 'h23;
        end else if(compare_tags_s2[1] && fetch_forwarding_valid && (forward_tag == s2_tags[1]) && (s2_idxs[1] == forward_idx)) begin
            miss[1] <= 0;
            read_instr[1] <= forward_line_broken[getOffSet(fetch_forwarding_addr)];
            prev_read_addr[1] <= fetch_forwarding_addr;
        end else if(compare_tags_s2[1] && (access_data[1][TOTAL_LINE_SIZE-1] && (data_tags[1] == s2_tags[1])) && (s2_idxs[1] == getIdx(already_read_addr[1]))) begin
            miss[1] <= 0;
            read_instr[1] <= line2[getOffSet(already_read_addr[1])];
            prev_read_addr[1] <= already_read_addr[1];
        end else if(~compare_tags_s2[1]) begin
            miss[1] <= 0;
            read_instr[1] <= 0;
            prev_read_addr[1] <= 0;
        end else begin
            miss[1] <= 1;
            read_instr[1] <= 0;
            prev_read_addr[1] <= 0;
        end
    end
    
    always_comb begin
        forward_tag = getTag(fetch_forwarding_addr);
        forward_idx = getIdx(fetch_forwarding_addr);
        
        valid_read[0] = (compare_tags_s2[0] && ~ext_flush) || reset;
    
        s2_tags[0] = getTag(already_read_addr[0]);
        s2_idxs[0] = getIdx(already_read_addr[0]);
        data_tags[0] = access_data[0][TOTAL_LINE_SIZE-2:TOTAL_LINE_SIZE-1-TAG_SIZE];
        
        
        valid_read[1] = (compare_tags_s2[1] && ~ext_flush) || reset;
        s2_tags[1] = getTag(already_read_addr[1]);
        s2_idxs[1] = getIdx(already_read_addr[1]);
        data_tags[1] = access_data[1][TOTAL_LINE_SIZE-2:TOTAL_LINE_SIZE-1-TAG_SIZE];
        
        
    end
    
    
    
    
    
endmodule
