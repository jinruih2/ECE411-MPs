module cmp
import rv32i_types::*;
(
    input rv32i_word rs1_out,
    input rv32i_word cmpmux_out,
    input branch_funct3_t cmpop,
    output logic cmp_out
);

always_comb
begin
    unique case (cmpop)
        beq: begin
            if(rs1_out == cmpmux_out)
                cmp_out = 1'b1;
            else
                cmp_out = 1'b0;
        end
        bne: begin
            if(rs1_out != cmpmux_out)
                cmp_out = 1'b1;
            else
                cmp_out = 1'b0;
        end
        blt: begin
            if($signed(rs1_out) < $signed(cmpmux_out))
                cmp_out = 1'b1;
            else
                cmp_out = 1'b0;
        end
        bge: begin
            if($signed(rs1_out) >= $signed(cmpmux_out))
                cmp_out = 1'b1;
            else
                cmp_out = 1'b0;
        end
        bltu: begin
            if((rs1_out) < (cmpmux_out))
                cmp_out = 1'b1;
            else
                cmp_out = 1'b0;
        end
        bgeu: begin
            if((rs1_out) >= (cmpmux_out))
                cmp_out = 1'b1;
            else
                cmp_out = 1'b0;
        end
        default: cmp_out = 1'bx;
    endcase
end

endmodule : cmp
