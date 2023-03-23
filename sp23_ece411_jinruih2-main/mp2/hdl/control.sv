
module control
import rv32i_types::*; /* Import types defined in rv32i_types.sv */
(
    input clk,
    input rst,
    // newly added begin
    input logic [1:0] shift_sig,
    input mem_resp, 
    // newly added end
    input rv32i_opcode opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic br_en,
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    output pcmux::pcmux_sel_t pcmux_sel,
    output alumux::alumux1_sel_t alumux1_sel,
    output alumux::alumux2_sel_t alumux2_sel,
    output regfilemux::regfilemux_sel_t regfilemux_sel,
    output marmux::marmux_sel_t marmux_sel,
    output cmpmux::cmpmux_sel_t cmpmux_sel,
    output alu_ops aluop,
    output branch_funct3_t cmpop, // newly added
    output logic load_pc,
    output logic load_ir,
    output logic load_regfile,
    output logic load_mar,
    output logic load_mdr,
    output logic load_data_out,
    // newly added
    output logic mem_read,
    output logic mem_write,
    output logic [3:0] mem_byte_enable
);

/***************** USED BY RVFIMON --- ONLY MODIFY WHEN TOLD *****************/
logic trap;
logic [4:0] rs1_addr, rs2_addr;
logic [3:0] rmask, wmask;

branch_funct3_t branch_funct3;
store_funct3_t store_funct3;
load_funct3_t load_funct3;
arith_funct3_t arith_funct3;

assign arith_funct3 = arith_funct3_t'(funct3);
assign branch_funct3 = branch_funct3_t'(funct3);
assign load_funct3 = load_funct3_t'(funct3);
assign store_funct3 = store_funct3_t'(funct3);
assign rs1_addr = rs1;
assign rs2_addr = rs2;

always_comb
begin : trap_check
    trap = '0;
    rmask = '0;
    wmask = '0;

    case (opcode)
        op_lui, op_auipc, op_imm, op_reg, op_jal, op_jalr:;

        op_br: begin
            case (branch_funct3)
                beq, bne, blt, bge, bltu, bgeu:;
                default: trap = '1;
            endcase
        end

        op_load: begin
            case (load_funct3)
                lw: rmask = 4'b1111;
                lh, lhu: rmask = (4'b0011 << {shift_sig[1],1'b0})/* Modify for MP1 Final */ ;
                lb, lbu: rmask = (4'b0001 << shift_sig) /* Modify for MP1 Final */ ;
                default: trap = '1;
            endcase
        end

        op_store: begin
            case (store_funct3)
                sw: wmask = 4'b1111;
                sh: wmask = (4'b0011 << {shift_sig[1],1'b0}) /* Modify for MP1 Final */ ;
                sb: wmask = (4'b0001 << shift_sig) /* Modify for MP1 Final */ ;
                default: trap = '1;
            endcase
        end

        default: trap = '1;
    endcase
end
/*****************************************************************************/

enum int unsigned {
    /* List of states */
    fetch1       = 0,
    fetch2       = 1,
    fetch3       = 2,
    decode       = 3,
    imm          = 4,
    lui          = 5,
    calc_addr_ld = 6,
    calc_addr_st = 7,
    ld1          = 8,
    ld2          = 9,
    st1          = 10,
    st2          = 11,
    auipc        = 12,
    br           = 13,
    reg_reg      = 14,
    jal          = 15,   
    jalr         = 16

} state, next_state;

/************************* Function Definitions *******************************/
/**
 *  You do not need to use these functions, but it can be nice to encapsulate
 *  behavior in such a way.  For example, if you use the `loadRegfile`
 *  function, then you only need to ensure that you set the load_regfile bit
 *  to 1'b1 in one place, rather than in many.
 *
 *  SystemVerilog functions must take zero "simulation time" (as opposed to 
 *  tasks).  Thus, they are generally synthesizable, and appropraite
 *  for design code.  Arguments to functions are, by default, input.  But
 *  may be passed as outputs, inouts, or by reference using the `ref` keyword.
**/

/**
 *  Rather than filling up an always_block with a whole bunch of default values,
 *  set the default values for controller output signals in this function,
 *   and then call it at the beginning of your always_comb block.
**/
function void set_defaults();
    pcmux_sel = pcmux::pc_plus4;
    alumux1_sel = alumux::rs1_out;
    alumux2_sel = alumux::i_imm;
    regfilemux_sel = regfilemux::alu_out;
    marmux_sel = marmux::pc_out;
    cmpmux_sel = cmpmux::rs2_out;
    aluop = rv32i_types::alu_ops'(funct3);
    cmpop = rv32i_types::branch_funct3_t'(funct3);
    load_pc = 1'b0;
    load_ir = 1'b0;
    load_regfile = 1'b0;
    load_mar = 1'b0;
    load_mdr = 1'b0;
    load_data_out = 1'b0;
    mem_read = 1'b0;
    mem_write = 1'b0;
    mem_byte_enable = 4'b1111;
endfunction

/**
 *  Use the next several functions to set the signals needed to
 *  load various registers
**/
function void loadPC(pcmux::pcmux_sel_t sel);
    load_pc = 1'b1;
    pcmux_sel = sel;
endfunction

function void loadRegfile(regfilemux::regfilemux_sel_t sel);
endfunction

function void loadMAR(marmux::marmux_sel_t sel);
endfunction

function void loadMDR();
endfunction

function void setALU(alumux::alumux1_sel_t sel1, alumux::alumux2_sel_t sel2, logic setop , alu_ops op);
    /* Student code here */


    if (setop)
        aluop = op; // else default value
endfunction

function automatic void setCMP(cmpmux::cmpmux_sel_t sel, branch_funct3_t op);
endfunction

/*****************************************************************************/

    /* Remember to deal with rst signal */

always_comb
begin : state_actions
    /* Default output assignments */
    set_defaults();
    /* Actions for each state */
    unique case (state)
        fetch1: begin
            load_mar = 1'b1;
        end
        fetch2:begin
            load_mdr = 1'b1;
            mem_read = 1'b1;
        end
        fetch3: begin
            load_ir = 1'b1;
        end
        decode: ;
        imm: begin
            unique case (funct3)
                slt: begin
                    load_regfile = 1'b1;
                    load_pc = 1'b1;
                    cmpop = blt;
                    regfilemux_sel = regfilemux::br_en;
                    cmpmux_sel = cmpmux::i_imm;
                end
                sltu: begin
                    load_regfile = 1'b1;
                    load_pc = 1'b1;
                    cmpop = bltu;
                    regfilemux_sel = regfilemux::br_en;
                    cmpmux_sel = cmpmux::i_imm;
                end
                sr: begin
                    load_regfile = 1'b1;
                    load_pc = 1'b1;
                    if(funct7[5])                 
                        aluop = alu_sra; 
                    else
                        aluop = alu_srl;
                end
                default: begin
                    load_regfile = 1'b1;
                    load_pc = 1'b1;
                    aluop = alu_ops'(funct3);
                end  
            endcase
        end
        lui: begin
            load_regfile = 1'b1;
            load_pc = 1'b1;
            regfilemux_sel = regfilemux::u_imm;
        end
        calc_addr_ld: begin
            aluop = alu_add;
            load_mar = 1'b1;
            marmux_sel = marmux::alu_out;
        end
        ld1:begin
            load_mdr = 1'b1;
            mem_read = 1'b1;
        end
        ld2:begin
            unique case(funct3)
                lb: regfilemux_sel = regfilemux::lb;
                lh: regfilemux_sel = regfilemux::lh;
                lw: regfilemux_sel = regfilemux::lw;
                lbu:regfilemux_sel = regfilemux::lbu;
                lhu:regfilemux_sel = regfilemux::lhu;
                default: regfilemux_sel = regfilemux::lw;
            endcase
            load_regfile = 1'b1;
            load_pc = 1'b1;
        end
        calc_addr_st: begin
            alumux2_sel = alumux::s_imm;
            aluop = alu_add;
            load_mar = 1'b1;
            load_data_out = 1'b1;
            marmux_sel = marmux::alu_out;
        end
        st1: begin
            mem_write = 1'b1;
            mem_byte_enable = wmask;
        end
        st2: begin
            load_pc = 1'b1;
        end
        auipc: begin
            alumux1_sel = alumux::pc_out;
            alumux2_sel = alumux::u_imm;
            load_regfile = 1'b1;
            load_pc = 1'b1;
            aluop = alu_add;
        end
        br: begin
            pcmux_sel = pcmux::pcmux_sel_t'(br_en);
            load_pc = 1'b1;
            alumux1_sel = alumux::pc_out;
            alumux2_sel = alumux::b_imm;
            aluop = alu_add;
        end
        
        reg_reg: begin
            unique case (funct3)
                slt: begin
                    load_regfile = 1'b1;
                    load_pc = 1'b1;
                    cmpop = blt;
                    regfilemux_sel = regfilemux::br_en;
                    cmpmux_sel = cmpmux::rs2_out;
                    alumux2_sel = alumux::rs2_out;
                end
                sltu: begin
                    load_regfile = 1'b1;
                    load_pc = 1'b1;
                    cmpop = bltu;
                    regfilemux_sel = regfilemux::br_en;
                    cmpmux_sel = cmpmux::rs2_out;
                    alumux2_sel = alumux::rs2_out;
                end
                sr: begin
                    load_regfile = 1'b1;
                    load_pc = 1'b1;
                    if(funct7[5])
                        aluop = alu_sra; 
                    else
                        aluop = alu_srl;
                    alumux2_sel = alumux::rs2_out;
                end
                default: begin
                    load_regfile = 1'b1;
                    load_pc = 1'b1;
                    aluop = alu_ops'(funct3);
                    alumux2_sel = alumux::rs2_out;
                    // case for sub
                    if(!funct3 && funct7[5])
                        aluop = alu_sub;
                end
            endcase
        end

        // jal && jalr for cp2
        jal: begin
            load_regfile = 1'b1;
            load_pc = 1'b1;
            pcmux_sel = pcmux::alu_mod2; //why?
            regfilemux_sel = regfilemux::pc_plus4;
            aluop = alu_add;
            alumux1_sel = alumux::pc_out;
            alumux2_sel = alumux::j_imm;
        end

        jalr: begin
            load_regfile = 1'b1;
            load_pc = 1'b1;
            pcmux_sel = pcmux::alu_mod2; //why?
            regfilemux_sel = regfilemux::pc_plus4;
            alumux1_sel = alumux::rs1_out;
            alumux2_sel = alumux::i_imm;
        end
        
    endcase 
end

always_comb
begin : next_state_logic
    /* Next state information and conditions (if any)
     * for transitioning between states */
     if(rst) begin
        next_state = fetch1;
     end
     else begin
        unique case (state)
            fetch1: begin
                next_state = fetch2;
            end
            fetch2: begin
                if(mem_resp)
                    next_state = fetch3;
                else
                    next_state = fetch2;
            end
            fetch3: begin
                next_state = decode;
            end  
            decode: begin
                unique case(opcode)
                    op_imm:
                        next_state = imm;
                    op_lui:
                        next_state = lui;
                    op_load:
                        next_state = calc_addr_ld;
                    op_store:
                        next_state = calc_addr_st;
                    op_auipc:
                        next_state = auipc;
                    op_br:
                        next_state = br;
                    op_reg:
                        next_state = reg_reg;
                    op_jal:
                        next_state = jal;
                    op_jalr:
                        next_state = jalr;
                    default:
                        next_state = fetch1;
                endcase
            end 
            calc_addr_ld:
                next_state = ld1;
            ld1: begin
                if(mem_resp)
                    next_state = ld2;
                else
                    next_state = ld1;
            end
            ld2:
                next_state = fetch1;
            calc_addr_st:
                next_state = st1;
            st1: begin
                if(mem_resp)
                    next_state = st2;
                else    
                    next_state = st1;
            end
            st2:
                next_state = fetch1;  

            // imm:
            //     next_state = fetch1;
            // lui:
            //     next_state = fetch1; 
            // auipc:
            //     next_state = fetch1;
            // br:
            //     next_state = fetch1;
            // reg_reg:
            //     next_state = fetch1;
            // jal:
            //     next_state = fetch1;
            // jalr:
            //     next_state = fetch1;
            default:
                next_state = fetch1;
        endcase
     end
end

always_ff @(posedge clk)
begin: next_state_assignment
    /* Assignment of next state on clock edge */
    state <= next_state;
end

endmodule : control
