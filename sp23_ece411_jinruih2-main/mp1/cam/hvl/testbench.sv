
module testbench(cam_itf itf);
import cam_types::*;

cam dut (
    .clk_i     ( itf.clk     ),
    .reset_n_i ( itf.reset_n ),
    .rw_n_i    ( itf.rw_n    ),
    .valid_i   ( itf.valid_i ),
    .key_i     ( itf.key     ),
    .val_i     ( itf.val_i   ),
    .val_o     ( itf.val_o   ),
    .valid_o   ( itf.valid_o )
);

default clocking tb_clk @(negedge itf.clk); endclocking

initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars();
end

task reset();
    itf.reset_n <= 1'b0;
    repeat (5) @(tb_clk);
    itf.reset_n <= 1'b1;
    repeat (5) @(tb_clk);
endtask

// DO NOT MODIFY CODE ABOVE THIS LINE

task write(input key_t key, input val_t val);
    @(posedge itf.clk)
    itf.key <= key;
    itf.val_i <= val;
    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk)
    itf.valid_i <= 1'b0;
endtask

task read(input key_t key, output val_t val);
    @(posedge itf.clk)
    itf.key <= key;
    itf.rw_n <= 1'b1;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk)
    itf.valid_i <= 1'b0;
    val <= itf.val_o;
    ##(1);
endtask

key_t key_tb;
val_t val_tb;

initial begin
    $display("Starting CAM Tests");

    reset();
    /************************** Your Code Here ****************************/
    // Feel free to make helper tasks / functions, initial / always blocks, etc.
    // Consider using the task skeltons above
    // To report errors, call itf.tb_report_dut_error in cam/include/cam_itf.sv
    
    // for evict, 0-7 at first, then overwritten by 8-15, so 8-15 is what is left in CAM
    for (int i=0; i<16; i++) begin
        key_tb = i;
        val_tb = i;
        write(key_tb,val_tb);
    end
    
    // for read - hit, now we want to read 8-15 one by one
    for (int j=8; j<16; j++) begin
        key_tb = j;
        read(key_tb,val_tb);
        read_error: assert (val_tb == j) else begin
            itf.tb_report_dut_error(READ_ERROR);
            $error("%0t TB: Read %0d, expected %0d", $time, val_tb, j);
        end
    end
    /**********************************************************************/

    // writes of different values to the same key on consecutive clock cycles
    @(posedge itf.clk);
    itf.key <= 4'b0010;
    itf.val_i <= 4'b0011;
    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk);
    itf.key <= 4'b0010;
    itf.val_i <= 4'b0100;
    itf.rw_n <= 1'b0;
    @(posedge itf.clk);
    itf.valid_i <= 1'b0;

    // write then read to the same key on consecutive clock cycles
    @(posedge itf.clk);
    itf.key <= 4'b0010;
    itf.val_i <= 4'b1001;
    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk);
    itf.key <= 4'b0010;
    itf.rw_n <= 1'b1;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk);
    itf.valid_i <= 1'b0;
    val_tb <= itf.val_o;
    assert(itf.val_o == 4'b1001) else begin
        itf.tb_report_dut_error(READ_ERROR);
        $error("error");
    end
    

    itf.finish();
end

endmodule : testbench
