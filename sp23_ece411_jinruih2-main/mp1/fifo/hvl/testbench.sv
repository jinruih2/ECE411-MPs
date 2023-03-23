`ifndef testbench
`define testbench


module testbench(fifo_itf itf);
import fifo_types::*;

fifo_synch_1r1w dut (
    .clk_i     ( itf.clk     ),
    .reset_n_i ( itf.reset_n ),

    // valid-ready enqueue protocol
    .data_i    ( itf.data_i  ),
    .valid_i   ( itf.valid_i ),
    .ready_o   ( itf.rdy     ),

    // valid-yumi deqeueue protocol
    .valid_o   ( itf.valid_o ),
    .data_o    ( itf.data_o  ),
    .yumi_i    ( itf.yumi    )
);

initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars();
end

// Clock Synchronizer for Student Use
default clocking tb_clk @(negedge itf.clk); endclocking

task reset();
    itf.reset_n <= 1'b0;
    ##(10);
    itf.reset_n <= 1'b1;
    ##(1);
endtask : reset

function automatic void report_error(error_e err); 
    itf.tb_report_dut_error(err);
endfunction : report_error

// DO NOT MODIFY CODE ABOVE THIS LINE
word_t data_tb;

task enqueue();
    @(posedge itf.clk)
    itf.valid_i <= 1'b1;
    itf.data_i <= data_tb;
    @(posedge itf.clk)
    itf.valid_i <= 1'b0;
endtask : enqueue

task dequeue();
    @(posedge itf.clk)
    itf.yumi <= 1'b1;
    @(posedge itf.clk)
    itf.yumi <= 1'b0;
endtask : dequeue

task simul_enqueue_dequeue();
    @(posedge itf.clk)
    itf.valid_i <= 1'b1;
    itf.yumi <= 1'b1;
    @(posedge itf.clk)
    itf.valid_i <= 1'b0;
    itf.yumi <= 1'b0;
endtask : simul_enqueue_dequeue


initial begin
    reset();
    /************************ Your Code Here ***********************/
    // Feel free to make helper tasks / functions, initial / always blocks, etc.
    
    // enqueue words while the FIFO has size in [0,255]
    for (int i = 0; i < 256; i++) begin
    data_tb = 8'h11;
    enqueue();
    end
    
    // dequeue words while the FIFO has size in [1,256]
    for (int i = 0; i < 256; i++) begin
    dequeue();
    wrong_val: assert(itf.data_o == 8'h11)
        else begin
            $error("dequeue wrong value");
            report_error(INCORRECT_DATA_O_ON_YUMI_I);
        end
    
    end
    
    // simultaneously enqueue and dequeue while FIFO has size in [1,255]
    data_tb = 8'b00000001;
    for (int i = 0; i < 255; i++) begin
    enqueue();
    data_tb = 8'b0;
    simul_enqueue_dequeue();
    end

    @(tb_clk);
    reset();
    ready_error: assert(itf.rdy == 1'b1)
        else begin
            $error ("ready_o not correct");
            report_error(RESET_DOES_NOT_CAUSE_READY_O);
        end

    /***************************************************************/
    // Make sure your test bench exits by calling itf.finish();
    itf.finish();
    $error("TB: Illegal Exit ocurred");
end

endmodule : testbench
`endif

