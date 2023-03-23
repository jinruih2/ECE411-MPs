/* MODIFY. The cache datapath. It contains the data,
valid, dirty, tag, and LRU arrays, comparators, muxes,
logic gates and other supporting logic. */

module cache_datapath #(
    parameter s_offset = 5,
    parameter s_index  = 3,
    parameter s_tag    = 32 - s_offset - s_index,   // 24 bits for tag
    parameter s_mask   = 2**s_offset,               // 32 for 32 bytes in cacheline
    parameter s_line   = 8*s_mask,                  // 256 bits for one cacheline
    parameter num_sets = 2**s_index                 // 8 sets
)
(
    input clk,
    input rst,

    // ports to CPU
    input logic [31:0] mem_address,                 // the adddress CPU wants to read from or write to memory system

    // ports to bus adaptor
    input logic [255:0] mem_wdata256,               // the data write to memory system (256 bits)
    input logic [31:0] mem_byte_enable256,          // the byte location in 32 bytes line (8bits /256 bits)
    //output logic [255:0] mem_rdata256,              // requested read data, Cache sent to CPU
    output logic [255:0] dataout,

    // ports to cacheline adaptor
    input logic [255:0] pmem_rdata,                 // 256-bit data read from physical memory
    

    //datapath to control 
    output logic hit0,
    output logic hit1,
    output logic dirty0,
    output logic dirty1,
    output logic dirty,
    output logic lru_dataout,
    output logic [s_tag-1:0] tag_dataout_0, tag_dataout_1,

    //control to datapath
    input logic load_lru, load_valid0, load_valid1, load_tag0, load_tag1, load_dirty0, load_dirty1,
    input logic lru_datain, valid_datain0, valid_datain1, dirty_datain0, dirty_datain1,
    input logic datain_mux_sel,
    input logic dataout_mux_sel,
    input logic [1:0] write_en_sel_0,
    input logic [1:0] write_en_sel_1
);

logic [31:0] write_en_0, write_en_1;
logic [255:0] data0_in, data1_in, data0_out, data1_out;
logic valid_dataout_0, valid_dataout_1, dirty_dataout_0, dirty_dataout_1;
logic tag0_cmp_result, tag1_cmp_result;
assign hit0 = valid_dataout_0 & tag0_cmp_result;
assign hit1 = valid_dataout_1 & tag1_cmp_result;
assign dirty = dirty_dataout_0 || dirty_dataout_1;
assign dirty0 = dirty_dataout_0;
assign dirty1 = dirty_dataout_1;

array valid_array0
(
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(load_valid0),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(valid_datain0),
    .dataout(valid_dataout_0)
);

array valid_array1
(
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(load_valid1),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(valid_datain1),
    .dataout(valid_dataout_1)
);

array dirty_array0
(
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(load_dirty0),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(dirty_datain0),
    .dataout(dirty_dataout_0)
);

array dirty_array1
(
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(load_dirty1),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(dirty_datain1),
    .dataout(dirty_dataout_1)
);

array #(.width(s_tag)) tag_array0
(
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(load_tag0),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(mem_address[31:8]),
    .dataout(tag_dataout_0)
);

array #(.width(s_tag)) tag_array1
(
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(load_tag1),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(mem_address[31:8]),
    .dataout(tag_dataout_1)
);

array lru_array
(
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(load_lru),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(lru_datain),
    .dataout(lru_dataout)
);

data_array data_array0
(
    .clk(clk),
    .read(1'b1),
    .write_en(write_en_0),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(data0_in),
    .dataout(data0_out)
);

data_array data_array1
(
    .clk(clk),
    .read(1'b1),
    .write_en(write_en_1),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(data1_in),
    .dataout(data1_out)
);

comparator tag0_cmp
(
    .a(mem_address[31:8]),
    .b(tag_dataout_0),
    .result(tag0_cmp_result)
);

comparator tag1_cmp
(
    .a(mem_address[31:8]),
    .b(tag_dataout_1),
    .result(tag1_cmp_result)
);

always_comb begin: mux_select
    unique case (datain_mux_sel)
        1'b1: begin
            data0_in = pmem_rdata;
            data1_in = pmem_rdata;
        end
        1'b0: begin
            data0_in = mem_wdata256;
            data1_in = mem_wdata256;
        end
        default: ;
    endcase

    unique case(dataout_mux_sel)
        1'b0: dataout = data0_out;
        1'b1: dataout = data1_out;
        default: dataout = data0_out;
    endcase

    unique case(write_en_sel_0)
        2'b00:all_0_for0: write_en_0 = 32'b0;
        2'b01:mem_byte_enable256_for0: write_en_0 = mem_byte_enable256;
        2'b11:all_1_for0: write_en_0 = 32'hffffffff;
        default: write_en_0 = 32'b0;
    endcase

    unique case(write_en_sel_1)
        2'b00:all_0_for1: write_en_1 = 32'b0;
        2'b01:mem_byte_enable256_for1: write_en_1 = mem_byte_enable256;
        2'b11:all_1_for1: write_en_1 = 32'hffffffff;
    default: write_en_1 = 32'b0;
    endcase
end

endmodule : cache_datapath
