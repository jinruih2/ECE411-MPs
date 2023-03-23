module cache_dut_tb;

timeunit 1ns;
timeprecision 1ns;

/****************************** Generate Clock *******************************/
bit clk;
always #5 clk = clk === 1'b0;


/****************************** Dump Signals *******************************/
initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, cache_dut_tb, "+all");
    $display("Compilation Successful");
end


/****************************** Generate Reset ******************************/


/*************************** Instantiate DUT HERE ***************************/



endmodule : cache_dut_tb