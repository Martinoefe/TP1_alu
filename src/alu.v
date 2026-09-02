module alu #(
    parameter NB_DATA    = 8,
    parameter NB_OP_CODE = 6
)
(
    output reg  [NB_DATA-1:0]    o_result,
    input  wire [NB_DATA-1:0]    i_data_a,
    input  wire [NB_DATA-1:0]    i_data_b,
    input  wire [NB_OP_CODE-1:0] i_op_code
);

    always @(*)
    begin
        case (i_op_code)
            6'b100000: o_result = i_data_a + i_data_b;                    // ADD
            6'b100010: o_result = i_data_a - i_data_b;                    // SUB
            6'b100100: o_result = i_data_a & i_data_b;                    // AND
            6'b100101: o_result = i_data_a | i_data_b;                    // OR
            6'b100110: o_result = i_data_a ^ i_data_b;                    // XOR
            6'b100111: o_result = ~(i_data_a | i_data_b);                 // NOR
            6'b000010: o_result = i_data_b >> i_data_a[2:0];              // SRL
            6'b000011: o_result = $signed(i_data_b) >>> i_data_a[2:0];    // SRA
            default:   o_result = {NB_DATA{1'b0}};
        endcase
    end

endmodule
