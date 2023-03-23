module cacheline_adaptor
(
    input clk,
    input reset_n,

    // Port to LLC (Lowest Level Cache)
    input logic [255:0] line_i,
    output logic [255:0] line_o,
    input logic [31:0] address_i,
    input read_i,
    input write_i,
    output logic resp_o,

    // Port to memory
    input logic [63:0] burst_i,
    output logic [63:0] burst_o,
    output logic [31:0] address_o,
    output logic read_o,
    output logic write_o,
    input resp_i
);

// load : 1.buffers data from memory until the burst is complete
//        2.responds to the lowest level cache(LLC) with the complete cache line
// store: 1.buffers a cacheline from LLC, 
//        2.segments data into appropriate sized blocks for burst transmission
//        3.transmits blocks to memory

// cacheline size : 256
// burst size: 64 

    logic loading, storing;
      
    enum {idle, r1, r2, r3, r4, done_read, w1, w2, w3, w4, done_write} state;

	always_ff @(posedge clk) begin
		// reset
		if (!reset_n) begin
			state <= idle;
			loading <= 1'b0;
			storing <= 1'b0;
			read_o <= 1'b0;
			write_o <= 1'b0;
		end
        
        // receive signal from LLC, ready to read from memory
		if (read_i && !loading ) begin
            state <= r1;
			loading <= 1'b1;
			read_o <= 1'b1;
			write_o <= 1'b0;
			address_o <= address_i;
		end
        
        // in the processing of reading from memory, burst 64 bits at one time
        if (loading) begin
			case (state)
				r1: begin
					if (resp_i) begin
                        state <= r2;
						line_o [63:0] <= burst_i;
					end
				end
				r2: begin
					if (resp_i) begin
                        state <= r3;
						line_o [127:64] <= burst_i;
					end
				end
				r3: begin
					if (resp_i) begin
                        state <= r4;
						line_o [191:128] <= burst_i;
					end
				end
				r4: begin					
					if (resp_i) begin
                        state <= done_read;
						line_o [255:192] <= burst_i;
						resp_o <= 1'b1;
					end
				end
                // finish reading from memory
				done_read: begin
                    state <= idle;
					loading <= 1'b0;
					resp_o <= 1'b0;
					read_o <= 1'b0;
				end
			endcase
		end

        // receive signal from LLC, ready to write to memory
		if (write_i && !storing) begin
            state <= w1;
			storing <= 1'b1;
			read_o <= 1'b0;
			write_o <= 1'b1;
			address_o <= address_i;
			burst_o <= line_i[63:0];
		end
		
		if (storing) begin
			case (state)
				w1: begin
					if (resp_i) begin
                        state <= w2;
                        burst_o <= line_i [127:64];
					end
				end
				w2: begin
					if (resp_i) begin
                        state <= w3;
						burst_o <= line_i [191:128];
					end
				end
				w3: begin
					if (resp_i) begin
                        state <= w4;
						burst_o <= line_i [255:192];
					end
				end
				w4: begin					
					if (resp_i) begin
                        state <= done_write;
						resp_o <= 1'b1;
					end
				end
				done_write: begin
					state <= idle;
					storing <= 1'b0;
					resp_o <= 1'b0;
					write_o <= 1'b0;
				end
			endcase
		end
	end
endmodule : cacheline_adaptor
