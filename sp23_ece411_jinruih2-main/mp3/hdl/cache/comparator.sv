module comparator #(
    parameter width = 24
)
(
    a,
    b,
    result
);

input logic[width-1:0] a;
input logic[width-1:0] b;
output logic result;

assign result = (a==b) ? 1'b1: 1'b0;

endmodule
