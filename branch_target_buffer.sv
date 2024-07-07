`include "riscv_core.svh"

module branch_target_buffer #(
    parameter SIZE = 1024
    )(
    input clk, reset,
    branch_fb_ifc.in i_fb [2],
    input [`ADDR_WIDTH-1:0] read_addr [2],
    input valid_read_addr [2],
    output [`ADDR_WIDTH-1:0] guess [2], //expected jump location
    output guess_valid [2],
    output tag_match [2],
    output logic int_stall
    );
    
    localparam IDX_SIZE = $clog2(SIZE);
    localparam LINE_SIZE = `ADDR_WIDTH + (`ADDR_WIDTH - $clog2(SIZE) - 2); //line contains destination + tag
    
    logic [1:0] write_sum, read_sum;
    logic [2:0] port_sum;
    always_comb begin
        read_sum = valid_read_addr[0] + valid_read_addr[1];
        write_sum = i_fb[0].if_branch + i_fb[1].if_branch;
        port_sum = write_sum + read_sum;
        if(port_sum > 'd2) begin
            int_stall = 1;
        end else begin
            int_stall = 0;
        end
    end
    
    logic [IDX_SIZE-1:0] access_addr [2];
    logic access_we [2];
    logic [LINE_SIZE-1:0] access_din [2];
    logic [LINE_SIZE-1:0] access_dout [2];
    
        
    logic [`ADDR_WIDTH-1:0] access_addr_stored [2];
    always_ff @(posedge clk) begin
        access_addr_stored[0] <= access_addr[0];
        access_addr_stored[1] <= access_addr[1]; 
    end
        
        
    always_comb begin
        if(i_fb[0].if_branch && i_fb[1].if_branch) begin
            access_addr[0] = i_fb[0].branch_pc[IDX_SIZE-1:0];
            access_din[0] = {i_fb[0].branch_pc[`ADDR_WIDTH-1:$clog2(SIZE) + 2], i_fb[0].new_pc};
            access_we[0] = 1;
            
            access_addr[1] = i_fb[1].branch_pc[IDX_SIZE-1:0];
            access_din[1] = {i_fb[1].branch_pc[`ADDR_WIDTH-1:$clog2(SIZE) + 2], i_fb[1].new_pc};
            access_we[1] = 1;
        end else if ((i_fb[0].if_branch || i_fb[1].if_branch) && valid_read_addr[0]) begin
            if(i_fb[0].if_branch) begin
                access_addr[0] = i_fb[0].branch_pc[IDX_SIZE-1:0];
                access_din[0] = {i_fb[0].branch_pc[`ADDR_WIDTH-1:$clog2(SIZE) + 2], i_fb[0].new_pc};
            end else  begin
                access_addr[0] = i_fb[1].branch_pc[IDX_SIZE-1:0];
                access_din[0] = {i_fb[1].branch_pc[`ADDR_WIDTH-1:$clog2(SIZE) + 2], i_fb[1].new_pc};
            end
            access_we[0] = 1;
            
            access_addr[1] = read_addr[0][IDX_SIZE-1:0];
            access_din[1] = 0;
            access_we[1] = 0;
        end else if ((i_fb[0].if_branch || i_fb[1].if_branch) && valid_read_addr[1]) begin
            if(i_fb[0].if_branch) begin
                access_addr[0] = i_fb[0].branch_pc[IDX_SIZE-1:0];
                access_din[0] = {i_fb[0].branch_pc[`ADDR_WIDTH-1:$clog2(SIZE) + 2], i_fb[0].new_pc};
            end else  begin
                access_addr[0] = i_fb[1].branch_pc[IDX_SIZE-1:0];
                access_din[0] = {i_fb[1].branch_pc[`ADDR_WIDTH-1:$clog2(SIZE) + 2], i_fb[1].new_pc};
            end
            access_we[0] = 1;
            
            access_addr[1] = read_addr[1][IDX_SIZE-1:0];
            access_din[1] = 0;
            access_we[1] = 0;
        end else begin
            access_addr[0] = read_addr[0][IDX_SIZE-1:0];
            access_din[0] = 0;
            access_we[0] = 0;
            
            access_addr[1] = read_addr[1][IDX_SIZE-1:0];
            access_din[1] = 0;
            access_we[1] = 0;
        end
    end
    
    
    
    bram_block #(
        .WIDTH(LINE_SIZE),
        .DEPTH(SIZE)
    ) BTB_RAM (
        .clk,
        .reset,
        .addr(access_addr),
        .we(access_we),
        .din(access_din),
        .dout(access_dout)
    );
    
    assign guess_valid[0] = access_dout[0][`ADDR_WIDTH];
    assign guess_valid[1] = access_dout[1][`ADDR_WIDTH];
    assign guess[0] = access_dout[0][`ADDR_WIDTH-1:0];
    assign guess[1] = access_dout[1][`ADDR_WIDTH-1:0];
    assign tag_match[0] = access_addr_stored[0][`ADDR_WIDTH-1:2+$clog2(SIZE)] == access_dout[0][LINE_SIZE-1:`ADDR_WIDTH];
    assign tag_match[1] = access_addr_stored[1][`ADDR_WIDTH-1:2+$clog2(SIZE)] == access_dout[1][LINE_SIZE-1:`ADDR_WIDTH];
    
endmodule

