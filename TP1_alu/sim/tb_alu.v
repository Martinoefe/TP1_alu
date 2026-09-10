`timescale 1ns / 1ps

//=============================================================================
// Testbench de la ALU
//
// Cumple los dos requisitos explicitos del enunciado:
//   - generacion de entradas ALEATORIAS
//   - codigo de CHEQUEO AUTOMATICO (self-checking: no hay que mirar las
//     formas de onda a ojo para saber si paso o fallo)
//
// Y agrega cobertura que el enunciado no pide pero conviene tener:
//   - casos borde dirigidos (no dependen del azar)
//   - opcodes INVALIDOS, para ejercitar la rama default del DUT
//   - verificacion de las banderas carry y zero, no solo del resultado
//=============================================================================
module tb_alu;

    localparam NB_DATA    = 8;
    localparam NB_OP_CODE = 6;
    localparam NB_SHIFT   = $clog2(NB_DATA);
    localparam N_RANDOM   = 500;

    localparam [NB_OP_CODE-1:0] OP_ADD = 6'b100000;
    localparam [NB_OP_CODE-1:0] OP_SUB = 6'b100010;
    localparam [NB_OP_CODE-1:0] OP_AND = 6'b100100;
    localparam [NB_OP_CODE-1:0] OP_OR  = 6'b100101;
    localparam [NB_OP_CODE-1:0] OP_XOR = 6'b100110;
    localparam [NB_OP_CODE-1:0] OP_NOR = 6'b100111;
    localparam [NB_OP_CODE-1:0] OP_SRL = 6'b000010;
    localparam [NB_OP_CODE-1:0] OP_SRA = 6'b000011;

    reg  [NB_DATA-1:0]    data_a;
    reg  [NB_DATA-1:0]    data_b;
    reg  [NB_OP_CODE-1:0] op_code;

    wire [NB_DATA-1:0]    result;
    wire                  carry;
    wire                  zero;

    reg  [NB_DATA-1:0]    exp_result;
    reg                   exp_carry;
    reg                   exp_zero;

    reg [NB_OP_CODE-1:0] valid_ops [0:7];

    integer i;
    integer error_count;
    integer check_count;

    //-------------------------------------------------------------------------
    // Dispositivo bajo prueba
    //-------------------------------------------------------------------------
    alu #(
        .NB_DATA    (NB_DATA),
        .NB_OP_CODE (NB_OP_CODE)
    ) dut (
        .o_result  (result),
        .o_carry   (carry),
        .o_zero    (zero),
        .i_data_a  (data_a),
        .i_data_b  (data_b),
        .i_op_code (op_code)
    );

    //-------------------------------------------------------------------------
    // Modelo de referencia
    //
    // Calcula el resultado esperado de forma INDEPENDIENTE del DUT. Este es
    // el punto central del chequeo automatico: si el modelo fuera una copia
    // literal del codigo del DUT, un error de concepto se replicaria
    // identico en ambos lados y el test pasaria igual sin detectar nada.
    // El modelo expresa QUE se espera que haga la operacion, no COMO la
    // implementa el diseno.
    //-------------------------------------------------------------------------
    task automatic reference_model;
        input  [NB_DATA-1:0]    a;
        input  [NB_DATA-1:0]    b;
        input  [NB_OP_CODE-1:0] op;
        output [NB_DATA-1:0]    r;
        output                  c;
        reg    [NB_DATA:0]      ext;
        begin
            c = 1'b0;
            case (op)
                OP_ADD:  begin ext = {1'b0,a} + {1'b0,b}; r = ext[NB_DATA-1:0]; c = ext[NB_DATA]; end
                OP_SUB:  begin ext = {1'b0,a} - {1'b0,b}; r = ext[NB_DATA-1:0]; c = ext[NB_DATA]; end
                OP_AND:  r = a & b;
                OP_OR:   r = a | b;
                OP_XOR:  r = a ^ b;
                OP_NOR:  r = ~(a | b);
                OP_SRL:  r = b >> a[NB_SHIFT-1:0];
                OP_SRA:  r = $signed(b) >>> a[NB_SHIFT-1:0];
                default: r = {NB_DATA{1'b0}};
            endcase
        end
    endtask

    //-------------------------------------------------------------------------
    // Aplica un estimulo, espera la propagacion y verifica las tres salidas
    //-------------------------------------------------------------------------
    task automatic check;
        input [NB_DATA-1:0]    a;
        input [NB_DATA-1:0]    b;
        input [NB_OP_CODE-1:0] op;
        input [255:0]          etiqueta;
        begin
            data_a  = a;
            data_b  = b;
            op_code = op;

            #10;   // margen para la propagacion de la logica combinacional

            reference_model(a, b, op, exp_result, exp_carry);
            exp_zero = (exp_result == {NB_DATA{1'b0}});

            check_count = check_count + 1;

            if (result !== exp_result || carry !== exp_carry || zero !== exp_zero)
            begin
                error_count = error_count + 1;
                $display("[ERROR] t=%0t  %0s", $time, etiqueta);
                $display("        entradas: op=%b a=%h b=%h", op, a, b);
                $display("        obtenido: result=%h carry=%b zero=%b", result, carry, zero);
                $display("        esperado: result=%h carry=%b zero=%b", exp_result, exp_carry, exp_zero);
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Programa de test
    //-------------------------------------------------------------------------
    initial begin
        valid_ops[0] = OP_ADD;
        valid_ops[1] = OP_SUB;
        valid_ops[2] = OP_AND;
        valid_ops[3] = OP_OR;
        valid_ops[4] = OP_XOR;
        valid_ops[5] = OP_NOR;
        valid_ops[6] = OP_SRL;
        valid_ops[7] = OP_SRA;

        error_count = 0;
        check_count = 0;

        $display("============================================================");
        $display(" TP1 - Testbench ALU   (NB_DATA=%0d, NB_OP_CODE=%0d)",
                 NB_DATA, NB_OP_CODE);
        $display("============================================================");

        //---------------------------------------------------------------------
        // FASE 1: casos borde dirigidos.
        // Son los valores donde aparecen los errores tipicos (signo, acarreo,
        // desplazamiento maximo). Dejarlos librados al azar seria apostar a
        // que el generador aleatorio justo los produzca.
        //---------------------------------------------------------------------
        $display("\n-- Fase 1: casos borde dirigidos --");

        check(8'hFF, 8'h01, OP_ADD, "ADD con carry out");
        check(8'h7F, 8'h01, OP_ADD, "ADD con overflow con signo");
        check(8'h00, 8'h00, OP_ADD, "ADD cero + cero (flag zero)");
        check(8'h00, 8'h01, OP_SUB, "SUB con borrow (A < B)");
        check(8'h05, 8'h05, OP_SUB, "SUB resultado cero");
        check(8'h01, 8'h80, OP_SRA, "SRA de negativo (0x80 >>> 1)");
        check(8'h07, 8'h80, OP_SRA, "SRA maximo (0x80 >>> 7)");
        check(8'h01, 8'h7F, OP_SRA, "SRA de positivo (0x7F >>> 1)");
        check(8'h01, 8'h80, OP_SRL, "SRL de 0x80 (rellena con cero)");
        check(8'h07, 8'hFF, OP_SRL, "SRL maximo (0xFF >> 7)");
        check(8'h00, 8'hAA, OP_SRL, "SRL con desplazamiento cero");
        check(8'h0F, 8'hF0, OP_NOR, "NOR de complementarios -> 0x00");
        check(8'h00, 8'h00, OP_NOR, "NOR de ceros -> 0xFF");
        check(8'hFF, 8'hFF, OP_AND, "AND de todos unos");
        check(8'hAA, 8'h55, OP_AND, "AND de patrones alternados -> 0x00");
        check(8'hAA, 8'h55, OP_OR,  "OR de patrones alternados -> 0xFF");
        check(8'hFF, 8'hFF, OP_XOR, "XOR de iguales -> 0x00");

        //---------------------------------------------------------------------
        // FASE 2: opcodes invalidos -> deben caer en la rama default.
        // Sin esta fase, esa rama del case nunca se ejecutaria en todo el
        // testbench, y podria tener un error sin que nadie se entere.
        //---------------------------------------------------------------------
        $display("\n-- Fase 2: opcodes invalidos (rama default) --");

        check(8'hAB, 8'hCD, 6'b111111, "opcode invalido 111111");
        check(8'hAB, 8'hCD, 6'b000000, "opcode invalido 000000");
        check(8'hAB, 8'hCD, 6'b010101, "opcode invalido 010101");
        check(8'hAB, 8'hCD, 6'b100001, "opcode invalido 100001 (cercano a ADD)");
        check(8'hAB, 8'hCD, 6'b000001, "opcode invalido 000001 (cercano a SRL)");

        //---------------------------------------------------------------------
        // FASE 3: estimulos aleatorios (requisito del enunciado)
        //---------------------------------------------------------------------
        $display("\n-- Fase 3: %0d estimulos aleatorios --", N_RANDOM);

        for (i = 0; i < N_RANDOM; i = i + 1)
        begin
            check($random, $random, valid_ops[$unsigned($random) % 8], "aleatorio");
        end

        //---------------------------------------------------------------------
        // Resumen final
        //---------------------------------------------------------------------
        $display("\n============================================================");
        if (error_count == 0)
            $display(" RESULTADO: OK - pasaron %0d de %0d verificaciones",
                     check_count, check_count);
        else
            $display(" RESULTADO: FALLO - %0d de %0d verificaciones con error",
                     error_count, check_count);
        $display("============================================================");

        $finish;
    end

endmodule
