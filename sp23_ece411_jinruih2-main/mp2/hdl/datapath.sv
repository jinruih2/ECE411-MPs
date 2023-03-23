module datapath
import rv32i_types::*;
(
    input clk,
    input rst,
    input load_mdr,
    input rv32i_word mem_rdata,
    output rv32i_word mem_wdata, // signal used by RVFI Monitor

    /* You will need to connect more signals to your datapath module*/
    input load_pc,
    input load_ir,
    input load_regfile,
    input load_mar,
    input load_data_out,
    input pcmux::pcmux_sel_t pcmux_sel,
    input alumux::alumux1_sel_t alumux1_sel,
    input alumux::alumux2_sel_t alumux2_sel,
    input regfilemux::regfilemux_sel_t regfilemux_sel,
    input marmux::marmux_sel_t marmux_sel,
    input cmpmux::cmpmux_sel_t cmpmux_sel,
    input alu_ops aluop,
    input branch_funct3_t cmpop,
    output rv32i_reg rs1,
    output rv32i_reg rs2,
    output rv32i_word mem_address,
    output rv32i_opcode opcode,
    output logic[2:0] funct3,
    output logic[6:0] funct7,
    output logic br_en,
    /*newly added for cp2*/
    output logic [1:0] shift_sig
);

/******************* Signals Needed for RVFI Monitor *************************/
rv32i_word pcmux_out;
rv32i_word mdrreg_out;
/*****************************************************************************/
rv32i_word marreg_out;
assign mem_address = {marreg_out[31:2], 2'b0}; 
rv32i_reg rs1_from_ir;
rv32i_reg rs2_from_ir;
assign rs1 = rs1_from_ir;
assign rs2 = rs2_from_ir;
rv32i_reg rd;
rv32i_word rs1_out;
rv32i_word rs2_out;
rv32i_word i_imm;
rv32i_word u_imm;
rv32i_word b_imm;
rv32i_word s_imm;
rv32i_word j_imm;
rv32i_word alumux1_out;
rv32i_word alumux2_out;
rv32i_word regfilemux_out;
rv32i_word marmux_out;
rv32i_word cmpmux_out;
rv32i_word alu_out;
rv32i_word pc_out;
rv32i_word pc_plus4_out;   
logic br_en_from_cmp;
assign br_en = br_en_from_cmp;
rv32i_word mem_wdata_from_mem_data_out;

assign shift_sig = marreg_out[1:0];

always_comb begin
    unique case (funct3)
        sb: mem_wdata = (mem_wdata_from_mem_data_out << {marreg_out[1:0],3'b0});
        sh: mem_wdata = (mem_wdata_from_mem_data_out << {marreg_out[1:0],3'b0});
        sw: mem_wdata = mem_wdata_from_mem_data_out;
        default:
            mem_wdata = mem_wdata_from_mem_data_out;
    endcase
end
/***************************** Registers *************************************/
// Keep Instruction register named `IR` for RVFI Monitor
ir IR(
    .clk (clk),
    .rst (rst),
    .load (load_ir),
    .in (mdrreg_out),
    .funct3(funct3),
    .funct7(funct7),
    .opcode(opcode),
    .i_imm(i_imm),
    .s_imm(s_imm),
    .b_imm(b_imm),
    .u_imm(u_imm),
    .j_imm(j_imm),
    .rs1(rs1_from_ir),
    .rs2(rs2_from_ir),
    .rd (rd)
);

register MDR(
    .clk (clk),
    .rst (rst),
    .load (load_mdr),
    .in   (mem_rdata),
    .out  (mdrreg_out)
);

register MAR(
    .clk (clk),
    .rst (rst),
    .load(load_mar),
    .in(marmux_out),
    .out (marreg_out)
);

pc_register PC(
    .clk (clk),
    .rst (rst),
    .load(load_pc),
    .in(pcmux_out),
    .out(pc_out)
);

regfile regfile(
    .clk(clk),
    .rst(rst),
    .load(load_regfile),
    .in(regfilemux_out),
    .src_a(rs1_from_ir),
    .src_b(rs2_from_ir),
    .dest(rd),
    .reg_a(rs1_out),
    .reg_b(rs2_out)
);

register mem_data_out(
    .clk (clk),
    .rst (rst),
    .load(load_data_out),
    .in(rs2_out),
    .out (mem_wdata_from_mem_data_out)
);



/*****************************************************************************/

/******************************* ALU and CMP *********************************/
alu ALU(
    .aluop(aluop),
    .a(alumux1_out),
    .b(alumux2_out),
    .f(alu_out)
);

cmp CMP(
    .rs1_out (rs1_out),
    .cmpmux_out (cmpmux_out),
    .cmpop (cmpop),
    .cmp_out(br_en_from_cmp)
);
/*****************************************************************************/

/******************************** Muxes **************************************/
always_comb begin : MUXES
    // We provide one (incomplete) example of a mux instantiated using
    // a case statement.  Using enumerated types rather than bit vectors
    // provides compile time type safety.  Defensive programming is extremely
    // useful in SystemVerilog. 
    unique case (pcmux_sel)
        pcmux::pc_plus4: pcmux_out = pc_out + 4;
        pcmux::alu_out: pcmux_out = alu_out;
        pcmux::alu_mod2: pcmux_out = {alu_out[31:1], 1'b0};    
    endcase

    unique case(marmux_sel)
        marmux::pc_out: marmux_out = pc_out;
        marmux::alu_out: marmux_out = alu_out;
    endcase

    unique case(regfilemux_sel)
        regfilemux::alu_out: regfilemux_out = alu_out;
        regfilemux::br_en: regfilemux_out = {31'b0, br_en_from_cmp};   
        regfilemux::u_imm: regfilemux_out = u_imm;
        regfilemux::lw: regfilemux_out = mdrreg_out;
        regfilemux::pc_plus4: regfilemux_out = pc_out+4;
        regfilemux::lb: begin
            unique case(marreg_out[1:0])
                2'b00: regfilemux_out = {{24{mdrreg_out[7]}},mdrreg_out[7:0]};
                2'b01: regfilemux_out = {{24{mdrreg_out[15]}},mdrreg_out[15:8]};
                2'b10: regfilemux_out = {{24{mdrreg_out[23]}},mdrreg_out[23:16]};
                2'b11: regfilemux_out = {{24{mdrreg_out[31]}},mdrreg_out[31:24]};
            endcase
        end
        regfilemux::lbu: begin
            unique case(marreg_out[1:0])
                2'b00: regfilemux_out = {24'b0,mdrreg_out[7:0]};
                2'b01: regfilemux_out = {24'b0,mdrreg_out[15:8]};
                2'b10: regfilemux_out = {24'b0,mdrreg_out[23:16]};
                2'b11: regfilemux_out = {24'b0,mdrreg_out[31:24]};
            endcase 
        end
        regfilemux::lh: begin
            if(marreg_out[1])
                regfilemux_out = {{16{mdrreg_out[31]}},mdrreg_out[31:16]};
            else
                regfilemux_out = {{16{mdrreg_out[15]}},mdrreg_out[15:0]};
        end
        regfilemux::lhu: begin
            if(marreg_out[1])
                regfilemux_out = {16'b0,mdrreg_out[31:16]};
            else
                regfilemux_out = {16'b0,mdrreg_out[15:0]};
        end
    endcase

    unique case(cmpmux_sel)
        cmpmux::rs2_out: cmpmux_out = rs2_out;
        cmpmux::i_imm: cmpmux_out = i_imm;
    endcase

    unique case(alumux1_sel)
        alumux::rs1_out: alumux1_out = rs1_out;
        alumux::pc_out: alumux1_out = pc_out;
    endcase

    unique case(alumux2_sel)
        alumux::i_imm: alumux2_out = i_imm;
        alumux::u_imm: alumux2_out = u_imm;
        alumux::b_imm: alumux2_out = b_imm;
        alumux::s_imm: alumux2_out = s_imm;
        alumux::j_imm: alumux2_out = j_imm;
        alumux::rs2_out: alumux2_out = rs2_out;
    endcase
end
/*****************************************************************************/
endmodule : datapath
