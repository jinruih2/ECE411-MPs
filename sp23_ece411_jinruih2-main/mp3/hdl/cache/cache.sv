module cache #(
    parameter s_offset = 5,
    parameter s_index  = 3,
    parameter s_tag    = 32 - s_offset - s_index,  // 24 bits for tag
    parameter s_mask   = 2**s_offset,              // 32 for 32 bytes in cacheline
    parameter s_line   = 8*s_mask,                 // 8 * 32 = 256 bits
    parameter num_sets = 2**s_index                // 8
)
(
    input clk,
    input rst,

    /* CPU memory signals */
    input   logic [31:0]    mem_address,
    output  logic [31:0]    mem_rdata,
    input   logic [31:0]    mem_wdata,
    input   logic           mem_read,
    input   logic           mem_write,
    input   logic [3:0]     mem_byte_enable,
    output  logic           mem_resp,

    /* Physical memory signals */
    output  logic [31:0]    pmem_address,
    input   logic [255:0]   pmem_rdata,
    output  logic [255:0]   pmem_wdata,
    output  logic           pmem_read,
    output  logic           pmem_write,
    input   logic           pmem_resp
);
logic [255:0] dataout;
// datapath to control
logic hit0, hit1, dirty0, dirty1, dirty, lru_dataout;
logic [s_tag-1:0] tag_dataout_0, tag_dataout_1;

// control to datapath
logic load_lru, load_valid0, load_valid1, load_tag0, load_tag1, load_dirty0, load_dirty1;
logic lru_datain, valid_datain0, valid_datain1, dirty_datain0, dirty_datain1;
logic datain_mux_sel, dataout_mux_sel;
logic [1:0] write_en_sel_0, write_en_sel_1;

// wires needed for connecting bus adaptor
logic [255:0] mem_wdata256, mem_rdata256;
logic [31:0] mem_byte_enable256;
assign pmem_wdata = dataout;
assign mem_rdata256 = dataout;
cache_control control
(.*);

cache_datapath datapath
(.*);

bus_adapter bus_adapter
(
   .mem_wdata256(mem_wdata256),
   .mem_rdata256(mem_rdata256), 
   .mem_wdata(mem_wdata),                    // 32-bit data written to memory
   .mem_rdata(mem_rdata),                    // 32-bit data read from memory
   .mem_byte_enable(mem_byte_enable),
   .mem_byte_enable256(mem_byte_enable256),
   .address(mem_address) 
);

endmodule : cache