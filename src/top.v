module top #(
    parameter NB_DATA    = 8,
    parameter NB_OP_CODE = 6
)
(
    input  wire                   i_clock,
    input  wire [NB_DATA-1:0]     i_switches,
    input  wire                   i_btn_a,
    input  wire                   i_btn_b,
    input  wire                   i_btn_op,
    output wire [NB_DATA-1:0]     o_leds
);

    reg [NB_DATA-1:0]    reg_a;
    reg [NB_DATA-1:0]    reg_b;
    reg [NB_OP_CODE-1:0] reg_op;

    always @(posedge i_clock)
    begin
        if (i_btn_a == 1'b1)
            reg_a <= i_switches;
    end

    always @(posedge i_clock)
    begin
        if (i_btn_b == 1'b1)
            reg_b <= i_switches;
    end

    always @(posedge i_clock)
    begin
        if (i_btn_op == 1'b1)
            reg_op <= i_switches[NB_OP_CODE-1:0];
    end

    alu #(
        .NB_DATA    (NB_DATA),
        .NB_OP_CODE (NB_OP_CODE)
    )
    u_alu
    (
        .o_result  (o_leds),
        .i_data_a  (reg_a),
        .i_data_b  (reg_b),
        .i_op_code (reg_op)
    );

endmodule
