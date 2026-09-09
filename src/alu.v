`timescale 1ns / 1ps

//=============================================================================
// ALU parametrizable
//
//   NB_DATA    : ancho del bus de datos. Parametrizable (requisito del TP)
//                para poder reutilizar este mismo modulo en el trabajo final
//                con un bus mas ancho, sin tocar una sola linea de codigo.
//   NB_OP_CODE : ancho del codigo de operacion (6 bits segun el enunciado).
//
// Bloque PURAMENTE COMBINACIONAL: no tiene reloj ni estado interno.
// No conoce switches, botones ni LEDs: eso es responsabilidad de top.v
//=============================================================================
module alu
#(
    parameter NB_DATA    = 8,
    parameter NB_OP_CODE = 6
)
(
    output reg  [NB_DATA-1:0]    o_result,
    output reg                   o_carry,    // acarreo (ADD) / borrow (SUB)
    output wire                  o_zero,     // 1 si el resultado es cero
    input  wire [NB_DATA-1:0]    i_data_a,
    input  wire [NB_DATA-1:0]    i_data_b,
    input  wire [NB_OP_CODE-1:0] i_op_code
);

    //-------------------------------------------------------------------------
    // Codigos de operacion (tabla del enunciado).
    // Se declaran como localparam en vez de escribir los binarios sueltos
    // dentro del case: si manana cambia un codigo, se toca en un solo lugar.
    //-------------------------------------------------------------------------
    localparam [NB_OP_CODE-1:0] OP_ADD = 6'b100000;
    localparam [NB_OP_CODE-1:0] OP_SUB = 6'b100010;
    localparam [NB_OP_CODE-1:0] OP_AND = 6'b100100;
    localparam [NB_OP_CODE-1:0] OP_OR  = 6'b100101;
    localparam [NB_OP_CODE-1:0] OP_XOR = 6'b100110;
    localparam [NB_OP_CODE-1:0] OP_NOR = 6'b100111;
    localparam [NB_OP_CODE-1:0] OP_SRL = 6'b000010;
    localparam [NB_OP_CODE-1:0] OP_SRA = 6'b000011;

    //-------------------------------------------------------------------------
    // Cantidad de bits necesaria para expresar el desplazamiento:
    //     NB_DATA=8  -> 3 bits (shift de 0 a 7)
    //     NB_DATA=32 -> 5 bits (shift de 0 a 31)
    //
    // Escribir "i_data_a[2:0]" a mano funcionaria con 8 bits pero romperia
    // en silencio con cualquier ancho mayor. $clog2 mantiene la
    // parametrizacion REAL, que es lo que pide el enunciado.
    //-------------------------------------------------------------------------
    localparam NB_SHIFT = $clog2(NB_DATA);

    wire [NB_SHIFT-1:0] shamt = i_data_a[NB_SHIFT-1:0];

    //-------------------------------------------------------------------------
    // Suma y resta extendidas un bit: ese bit extra captura el acarreo que
    // de otro modo se perderia al truncar el resultado a NB_DATA bits.
    //-------------------------------------------------------------------------
    wire [NB_DATA:0] sum_ext = {1'b0, i_data_a} + {1'b0, i_data_b};
    wire [NB_DATA:0] sub_ext = {1'b0, i_data_a} - {1'b0, i_data_b};

    always @(*)
    begin
        // Valores por defecto ANTES del case: garantizan que toda salida
        // quede asignada en todos los caminos posibles y evitan que la
        // sintesis infiera latches en un bloque que debe ser combinacional.
        o_result = {NB_DATA{1'b0}};
        o_carry  = 1'b0;

        case (i_op_code)
            OP_ADD: begin
                o_result = sum_ext[NB_DATA-1:0];
                o_carry  = sum_ext[NB_DATA];      // carry out
            end

            OP_SUB: begin
                o_result = sub_ext[NB_DATA-1:0];
                o_carry  = sub_ext[NB_DATA];      // borrow: se activa si A < B
            end

            OP_AND: o_result = i_data_a & i_data_b;
            OP_OR:  o_result = i_data_a | i_data_b;
            OP_XOR: o_result = i_data_a ^ i_data_b;
            OP_NOR: o_result = ~(i_data_a | i_data_b);

            // Shift LOGICO: rellena por izquierda con ceros.
            OP_SRL: o_result = i_data_b >> shamt;

            // Shift ARITMETICO: replica el bit de signo.
            // $signed() es imprescindible: el operador >>> solo hace shift
            // aritmetico si su operando izquierdo es signado. Sin el,
            // se comportaria identico a >> y el bug solo se notaria con
            // valores negativos.
            OP_SRA: o_result = $signed(i_data_b) >>> shamt;

            default: begin
                o_result = {NB_DATA{1'b0}};
                o_carry  = 1'b0;
            end
        endcase
    end

    assign o_zero = (o_result == {NB_DATA{1'b0}});

endmodule
