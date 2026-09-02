module tb_alu;

    parameter NB_DATA    = 8;
    parameter NB_OP_CODE = 6;

    reg  [NB_DATA-1:0]    data_a;
    reg  [NB_DATA-1:0]    data_b;
    reg  [NB_OP_CODE-1:0] op_code;

    wire [NB_DATA-1:0]    result;
    reg  [NB_DATA-1:0]    expected;

    reg [NB_OP_CODE-1:0] valid_ops [0:7];

    integer i;
    integer error_count;

    alu #(
        .NB_DATA    (NB_DATA),
        .NB_OP_CODE (NB_OP_CODE)
    )
    dut
    (
        .o_result  (result),
        .i_data_a  (data_a),
        .i_data_b  (data_b),
        .i_op_code (op_code)
    );

    initial begin
        valid_ops[0] = 6'b100000; // ADD
        valid_ops[1] = 6'b100010; // SUB
        valid_ops[2] = 6'b100100; // AND
        valid_ops[3] = 6'b100101; // OR
        valid_ops[4] = 6'b100110; // XOR
        valid_ops[5] = 6'b100111; // NOR
        valid_ops[6] = 6'b000010; // SRL
        valid_ops[7] = 6'b000011; // SRA

        error_count = 0;

        for (i = 0; i < 200; i = i + 1)
        begin
            data_a  = $random;
            data_b  = $random;
            op_code = valid_ops[$unsigned($random) % 8];

            #10;

            case (op_code)
                6'b100000: expected = data_a + data_b;
                6'b100010: expected = data_a - data_b;
                6'b100100: expected = data_a & data_b;
                6'b100101: expected = data_a | data_b;
                6'b100110: expected = data_a ^ data_b;
                6'b100111: expected = ~(data_a | data_b);
                6'b000010: expected = data_b >> data_a[2:0];
                6'b000011: expected = $signed(data_b) >>> data_a[2:0];
                default:   expected = {NB_DATA{1'b0}};
            endcase

            if (result !== expected)
            begin
                error_count = error_count + 1;
                $display("ERROR en t=%0t: op=%b a=%d b=%d -> result=%d, esperado=%d",
                          $time, op_code, data_a, data_b, result, expected);
            end
        end

        if (error_count == 0)
            $display("TODOS LOS TESTS PASARON (200/200)");
        else
            $display("FALLARON %0d de 200 tests", error_count);

        $finish;
    end

endmodule
