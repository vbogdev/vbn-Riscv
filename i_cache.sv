`timescale 1ns / 1ps
`include "riscv_core.svh"

/*
In depth module description
*/
module i_cache #(
    //parameter DEPTH = 512,
    parameter LINE_SIZE = 2,
    parameter DEPTH = 1024
    )(
    input clk, reset,
    input [`ADDR_WIDTH-1:0] read_addr [2],
    input read_addr_valid [2],
    input ext_stall, ext_flush,
    input [`ADDR_WIDTH-1:0] fetch_addr,      
    input fetch_addr_valid,
    input [LINE_SIZE*32-1:0] fetched_data,    
    output logic request_valid [2],
    output logic [`ADDR_WIDTH-1:0] request_addr [2],
    output logic [31:0] read_instr [2],
    output logic valid_read [2],
    output logic int_stall,
    output logic [`ADDR_WIDTH-1:0] prev_read_addr [2]
    );
    
    localparam ADDR_OFFSET = 2;
    localparam LINE_OFFSET = $clog2(LINE_SIZE);
    localparam INDEX_SIZE = $clog2(1024);
    localparam TAG_SIZE = `ADDR_WIDTH - INDEX_SIZE - LINE_OFFSET - ADDR_OFFSET;
    localparam TOTAL_LINE_BIT_WIDTH = TAG_SIZE + LINE_SIZE * 32 + 1; //note: the + 1 is for a valid bit which will be place at the end of the line
    localparam NUM_BRAMS = TOTAL_LINE_BIT_WIDTH / 36 + 1;
    localparam LAST_WIDTH = TOTAL_LINE_BIT_WIDTH % 36;
    
    logic [$clog2(1024)-1:0] addr [2];
    logic we [2];
    logic [35:0] din [NUM_BRAMS-1][2];
    logic [LAST_WIDTH-1:0] last_din [2];
    logic [35:0] dout [NUM_BRAMS-1][2];
    logic [LAST_WIDTH-1:0] last_dout [2];
    
    logic [TOTAL_LINE_BIT_WIDTH-1:0] full_din [2];
    logic [TOTAL_LINE_BIT_WIDTH-1:0] full_dout [2];
    
    logic [`ADDR_WIDTH-1:0] already_read_addr_1 [2];
    logic already_read_addr_1_valid [2];
    logic [`ADDR_WIDTH-1:0] already_read_addr_2 [2];
    logic already_read_addr_2_valid [2];
    
    logic [TOTAL_LINE_BIT_WIDTH-1:0] read_line [2];
    logic [TOTAL_LINE_BIT_WIDTH-1:0] read_line_backup [2];
    
    
    genvar i;
    generate
        for(i = 0; i < NUM_BRAMS; i++) begin
            if(i == (NUM_BRAMS-1)) begin
                assign last_din[0] = full_din[0][i*36+:LAST_WIDTH];
                assign last_din[1] = full_din[1][i*36+:LAST_WIDTH];
                assign full_dout[0][i*36+:LAST_WIDTH] = last_dout[0];
                assign full_dout[1][i*36+:LAST_WIDTH] = last_dout[1];
                bram_block #(.WIDTH(LAST_WIDTH), .DEPTH(1024)) BRAM_BLOCK(
                    .clk(clk),
                    .addr(addr),
                    .we(we),
                    .din(last_din),
                    .dout(last_dout)
                );
            end else begin
                assign din[i][0] = full_din[0][i*36+:36];
                assign din[i][1] = full_din[1][i*36+:36];
                assign full_dout[0][i*36+:36] = dout[i][0];
                assign full_dout[1][i*36+:36] = dout[i][1];
                bram_block #(.WIDTH(36), .DEPTH(1024)) BRAM_BLOCK(
                    .clk(clk),
                    .addr(addr),
                    .we(we),
                    .din(din[i]),
                    .dout(dout[i])
                );
            end
            
        end
    endgenerate
    
    function compare_tags(input [`ADDR_WIDTH-1:0] addr, input [TOTAL_LINE_BIT_WIDTH-1:0] line);
        if(line[TOTAL_LINE_BIT_WIDTH-1] && (line[LINE_SIZE*32+:TAG_SIZE] == addr[ADDR_OFFSET + LINE_OFFSET + INDEX_SIZE +: TAG_SIZE])) begin
            compare_tags = 0;
        end else begin
            compare_tags = 1;
        end
    endfunction
    
    function logic [31:0] get_instruction(input [`ADDR_WIDTH-1:0] addr, input [TOTAL_LINE_BIT_WIDTH-1:0] line);
        get_instruction = line[32*addr[2]+:32];
    endfunction
    
    function logic [TAG_SIZE-1:0] get_tag(input logic [`ADDR_WIDTH-1:0] addr);
        get_tag = addr[LINE_OFFSET+ADDR_OFFSET+INDEX_SIZE+:TAG_SIZE];
    endfunction    
    
    function logic [INDEX_SIZE-1:0] get_idx(input logic [`ADDR_WIDTH-1:0] addr);
        get_idx = addr[LINE_OFFSET+ADDR_OFFSET+:INDEX_SIZE];
    endfunction  
    
    enum logic {NO_MISS, MISS} state, next_state;
    
    assign int_stall = (next_state == MISS);
    
    logic [31:0] fetched_instr [2];
    logic [TOTAL_LINE_BIT_WIDTH-1:0] fetched_data_line;
    assign fetched_data_line = {1'b1, get_tag(fetch_addr), fetched_data};
    assign fetched_instr[0] = get_instruction(already_read_addr_2[0], fetched_data_line);
    assign fetched_instr[1] = get_instruction(already_read_addr_2[1], fetched_data_line);
        
    
    //logic to compare the fetched address to the missing addresses
    logic fetch_addr_match [2];
    logic miss [2];
    
    assign fetch_addr_match[0] = (get_tag(fetch_addr) == get_tag(already_read_addr_2[0])) && (get_idx(fetch_addr) == get_idx(already_read_addr_2[0])) 
        && fetched_data_line[TOTAL_LINE_BIT_WIDTH-1];
    assign fetch_addr_match[1] = (get_tag(fetch_addr) == get_tag(already_read_addr_2[1])) && (get_idx(fetch_addr) == get_idx(already_read_addr_2[1])) 
        && fetched_data_line[TOTAL_LINE_BIT_WIDTH-1];
    
    //handle comparing tags
    assign miss[0] = compare_tags(already_read_addr_2[0], read_line[0]);
    assign miss[1] = compare_tags(already_read_addr_2[1], read_line[1]);
    always_comb begin
        request_valid[0] = 0;
        request_valid[1] = 0;
        request_addr[0] = 0;
        request_addr[1] = 0;
    
        if((state == NO_MISS) && ((miss[0] && already_read_addr_2_valid[0]) || (miss[1] && already_read_addr_2_valid[1])) || ext_stall) begin
            next_state = MISS;
            request_valid[0] = miss[0] && already_read_addr_2_valid[0];
            request_valid[1] = miss[1] && already_read_addr_2_valid[1];
            request_addr[0] = already_read_addr_2[0];
            request_addr[1] = already_read_addr_2[1];
        end else if(state == NO_MISS) begin
            next_state = NO_MISS;
        end else if((state == MISS) && ((miss[0] && already_read_addr_2_valid[0]) || (miss[1] && already_read_addr_2_valid[1]))) begin
            next_state = MISS;
        end else if((state == MISS))begin
            next_state = NO_MISS;
        end else begin
            next_state = MISS;
        end
    end
    
    //handle inputs of cache
    always_comb begin
        if(state == MISS) begin
            if(miss[0] && already_read_addr_2_valid[0] && fetch_addr_match[0] && fetch_addr_valid) begin
                we[0] = 1;
                addr[0] = get_idx(already_read_addr_2[0]);
                full_din[0] = fetched_data_line;
            end else if(next_state == NO_MISS) begin
                we[0] = 0;
                addr[0] = get_idx(read_addr[0]);
                full_din[0] = 0;
            end else begin
                we[0] = 0;
                addr[0] = 0;
                full_din[0] = 0;
            end
            
            if(miss[1] && already_read_addr_2_valid[1] && fetch_addr_match[1] && fetch_addr_valid) begin
                we[1] = 1;
                addr[1] = get_idx(already_read_addr_2[1]);
                full_din[1] = fetched_data_line;
            end else if(next_state == NO_MISS) begin
                we[1] = 0;
                addr[1] = get_idx(read_addr[1]);
                full_din[1] = 0;
            end else begin
                we[1] = 0;
                addr[1] = 0;
                full_din[1] = 0;
            end
        end else begin
            we[0] = 0;
            we[1] = 0;
            full_din[0] = 0;
            full_din[1] = 0;
            addr[0] = get_idx(read_addr[0]);
            addr[1] = get_idx(read_addr[1]);
        end
    end
    
    always_ff @(posedge clk) begin
        if(reset || ext_flush) begin
            state <= NO_MISS;
            already_read_addr_1[0] <= 0;
            already_read_addr_1[1] <= 0;
            already_read_addr_2[0] <= 0;
            already_read_addr_2[1] <= 0;
            already_read_addr_1_valid[0] <= 0;
            already_read_addr_1_valid[1] <= 0;
            already_read_addr_2_valid[0] <= 0;
            already_read_addr_2_valid[1] <= 0;
            read_line[0] <= 0;
            read_line[1] <= 0;
            valid_read[0] <= 0;
            valid_read[1] <= 0;
            read_instr[0] <= 0;
            read_instr[1] <= 0;
            prev_read_addr[0] <= 0;
            prev_read_addr[1] <= 0;
            read_line_backup[0] <= 0;
            read_line_backup[1] <= 0;
        end else begin
            state <= next_state;
            
            //case for operation as normal
            if((next_state == NO_MISS) && (state == NO_MISS) && ~ext_stall) begin
                already_read_addr_1[0] <= read_addr[0];
                already_read_addr_1[1] <= read_addr[1];
                already_read_addr_1_valid[0] <= read_addr_valid[0];
                already_read_addr_1_valid[1] <= read_addr_valid[1];
                already_read_addr_2[0] <= already_read_addr_1[0];
                already_read_addr_2[1] <= already_read_addr_1[1];
                already_read_addr_2_valid[0] <= already_read_addr_1_valid[0];
                already_read_addr_2_valid[1] <= already_read_addr_1_valid[1];
                read_line[0] <= full_dout[0];
                read_line[1] <= full_dout[1];
                
                valid_read[0] <= already_read_addr_2_valid[0];
                valid_read[1] <= already_read_addr_2_valid[1];
                prev_read_addr[0] <= already_read_addr_2[0];
                prev_read_addr[1] <= already_read_addr_2[1];
                read_instr[0] <= get_instruction(already_read_addr_2[0], read_line[0]);
                read_instr[1] <= get_instruction(already_read_addr_2[1], read_line[1]);
            //case for when the cache does not contain the data you want
            end else if((state == NO_MISS) && (next_state == MISS)) begin
                //when the new line is placed into the cache, the line that has just been read will be overwritten
                //therefore you need to back it up temporarily
                read_line_backup[0] <= full_dout[0];
                read_line_backup[1] <= full_dout[1];
                valid_read[0] <= 0;
                valid_read[1] <= 0;
                
            //case for when you recieve the cache line you have  been waiting for
            end else if((state == MISS) && (next_state == NO_MISS) && ~ext_stall) begin
                read_line[0] <= read_line_backup[0];
                read_line[1] <= read_line_backup[1];
                valid_read[0] <= already_read_addr_2_valid[0];
                valid_read[1] <= already_read_addr_2_valid[1];
                prev_read_addr[0] <= already_read_addr_2[0];
                prev_read_addr[1] <= already_read_addr_2[1];
                read_instr[0] <= get_instruction(already_read_addr_2[0], read_line[0]);
                read_instr[1] <= get_instruction(already_read_addr_2[1], read_line[1]);
                
                already_read_addr_1[0] <= read_addr[0];
                already_read_addr_1[1] <= read_addr[1];
                already_read_addr_1_valid[0] <= read_addr_valid[0];
                already_read_addr_1_valid[1] <= read_addr_valid[1];
                already_read_addr_2[0] <= already_read_addr_1[0];
                already_read_addr_2[1] <= already_read_addr_1[1];
                already_read_addr_2_valid[0] <= already_read_addr_1_valid[0];
                already_read_addr_2_valid[1] <= already_read_addr_1_valid[1];
            //stalled due to waiting for miss
            end else if((state == MISS) && (next_state == MISS)) begin
                if(miss[0] && fetch_addr_valid && fetch_addr_match[0]) begin
                    read_line[0] <= fetched_data_line;
                end
                if(miss[1] && fetch_addr_valid && fetch_addr_match[1]) begin
                    read_line[1] <= fetched_data_line;
                end

            end
        end
    end
endmodule