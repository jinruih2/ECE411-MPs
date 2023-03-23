/* MODIFY. The cache controller. It is a state machine
that controls the behavior of the cache. */

module cache_control (
    input clk,
    input rst,

    //port to CPU
    input logic [31:0] mem_address,
    input logic mem_read, mem_write,
    output logic mem_resp,

    //port to physical memory
    output logic pmem_read, pmem_write,
    output logic [31:0] pmem_address,
    input logic pmem_resp,

    //datapath to control
    input logic hit0, hit1, dirty0, dirty1, dirty, lru_dataout,
    input logic [23:0] tag_dataout_0, tag_dataout_1,

    // control to datapath
    output logic load_lru, load_valid0, load_valid1, load_tag0, load_tag1, load_dirty0, load_dirty1,
    output logic lru_datain, valid_datain0, valid_datain1, dirty_datain0, dirty_datain1,
    output logic datain_mux_sel, dataout_mux_sel,
    output logic [1:0] write_en_sel_0,write_en_sel_1
    
);

enum int unsigned{
    /* List of states */
    idle          = 0,
    hit_check     = 1,
    write_back    = 2,
    read_allocate = 3
}state, next_state;

function void set_defaults();
    mem_resp = 1'b0;
    pmem_read = 1'b0;
    pmem_write = 1'b0;
    pmem_address = {mem_address[31:5],5'b0};
    load_lru = 1'b0;
    load_valid0 = 1'b0;
    load_valid1 = 1'b0;
    load_tag0 = 1'b0;
    load_tag1 = 1'b0;
    load_dirty0 = 1'b0;
    load_dirty1 = 1'b0;
    lru_datain = 1'b0;
    valid_datain0 = 1'b0;
    valid_datain1 = 1'b0;
    dirty_datain0 = 1'b0;
    dirty_datain1 = 1'b0;
    datain_mux_sel = 1'b0;
    dataout_mux_sel = 1'b0;
    write_en_sel_0 = 2'b0;
    write_en_sel_1 = 2'b0;
endfunction

always_comb
begin: state_actions
    set_defaults();
    unique case (state)
        idle: ;

        hit_check: begin
            if(hit0) begin
                if(mem_read) begin
                    dataout_mux_sel = 1'b0;
                    load_lru = 1'b1;
                    lru_datain = 1'b0;
                    dirty_datain0 = dirty0;
                end
                else begin
                    datain_mux_sel = 1'b0;
                    write_en_sel_0 = 2'b01;
                    load_dirty0 = 1'b1;
                    dirty_datain0 = 1'b1;
                    load_lru = 1'b1;
                    lru_datain = 1'b0;
                end
                mem_resp = 1'b1;
            end
            if(hit1) begin
                if(mem_read) begin
                    dataout_mux_sel = 1'b1;
                    load_lru = 1'b1;
                    lru_datain = 1'b1;
                    dirty_datain1 = dirty1;
                end
                else begin
                    datain_mux_sel = 1'b0;
                    write_en_sel_1 = 2'b01;
                    load_dirty1 = 1'b1;
                    dirty_datain1 = 1'b1;
                    load_lru = 1'b1;
                    lru_datain = 1'b1;
                end
                mem_resp = 1'b1;
            end
            // miss, do nothing
        end

        write_back: begin
            dataout_mux_sel = ~lru_dataout;
            pmem_address = lru_dataout ? {tag_dataout_0,mem_address[7:5],5'b0}:{tag_dataout_1,mem_address[7:5],5'b0};
            pmem_write = 1'b1;
        end

        read_allocate: begin
            datain_mux_sel = 1'b1;
            dataout_mux_sel = ~lru_dataout;
            pmem_read = 1'b1;
            if(lru_dataout) begin
                write_en_sel_0 = 2'b11;
                load_valid0 = 1'b1;
                valid_datain0 = 1'b1;
                load_dirty0 = 1'b1;
                dirty_datain0 = 1'b0;
                load_tag0 = 1'b1;
            end
            else begin
                write_en_sel_1 = 2'b11;
                load_valid1 = 1'b1;
                valid_datain1 = 1'b1;
                load_dirty1 = 1'b1;
                dirty_datain1 = 1'b0;
                load_tag1 = 1'b1;
            end
        end
        default: ;
    endcase 
end

always_comb
begin: next_state_logic
    if(rst) begin
        next_state = idle;
    end
    else begin
        unique case (state)
            idle: begin
                if(mem_read || mem_write) next_state = hit_check;
                else next_state = idle;
            end
            hit_check: begin
                if(hit0 || hit1) next_state = idle;
                else if(!hit0 && !hit1 && dirty) next_state = write_back;
                else next_state = read_allocate;
            end
            write_back: begin
                if(pmem_resp) next_state = read_allocate;
                else next_state = write_back;
            end
            read_allocate: begin
                if(pmem_resp) next_state = hit_check;
                else next_state = read_allocate;
            end
            default: next_state = idle;
        endcase
    end
end

always_ff @(posedge clk)
begin: next_state_assignment
    state <= next_state;
end
endmodule : cache_control
