`timescale 1ns / 1ps

//=============================================================================
// TOP - TP1 ALU
//
// Conecta la ALU al hardware fisico de la placa.
//
// DECISIONES DE DISENO
//
//  * Los TRES registros de entrada son de NB_DATA bits (8), aunque el opcode
//    use solo 6. Asi se instancia el MISMO modulo generico "register" tres
//    veces (modularidad) y el opcode se recorta despues con una MASCARA.
//
//  * El registro de salida tiene HABILITACION propia, controlada por un boton
//    de "calcular". Sin eso, el resultado en los LEDs cambiaria apenas se
//    modifica cualquier operando, mostrando resultados intermedios sin
//    sentido mientras se arma la operacion. Con la habilitacion, los LEDs
//    RETIENEN el resultado anterior hasta que el usuario decide calcular.
//
// SECUENCIA DE USO EN LA PLACA
//   1) Switches = operando A   -> BTN_A    (btnU)
//   2) Switches = operando B   -> BTN_B    (btnL)
//   3) Switches = codigo de op -> BTN_OP   (btnR)
//   4)                            BTN_CALC (btnD)  -> aparece el resultado
//   BTN_RESET (btnC) limpia todo en cualquier momento.
//=============================================================================
module top
#(
    parameter NB_DATA     = 8,
    parameter NB_OP_CODE  = 6,
    parameter NB_DEBOUNCE = 17    // 2^17 @100MHz ~= 1.31 ms
)
(
    input  wire                i_clock,
    input  wire [NB_DATA-1:0]  i_switches,
    input  wire                i_btn_reset,
    input  wire                i_btn_a,
    input  wire                i_btn_b,
    input  wire                i_btn_op,
    input  wire                i_btn_calc,
    output wire [NB_DATA-1:0]  o_leds,
    output wire                o_led_carry,
    output wire                o_led_zero
);

    //=========================================================================
    // Acondicionamiento de los cinco botones
    //=========================================================================
    wire pulse_a, pulse_b, pulse_op, pulse_calc;
    wire reset;                   // nivel limpio, se usa como reset sincrono

    button_conditioner #(.NB_COUNT(NB_DEBOUNCE)) u_cond_a (
        .i_clock(i_clock), .i_button(i_btn_a),
        .o_pulse(pulse_a), .o_level()
    );

    button_conditioner #(.NB_COUNT(NB_DEBOUNCE)) u_cond_b (
        .i_clock(i_clock), .i_button(i_btn_b),
        .o_pulse(pulse_b), .o_level()
    );

    button_conditioner #(.NB_COUNT(NB_DEBOUNCE)) u_cond_op (
        .i_clock(i_clock), .i_button(i_btn_op),
        .o_pulse(pulse_op), .o_level()
    );

    button_conditioner #(.NB_COUNT(NB_DEBOUNCE)) u_cond_calc (
        .i_clock(i_clock), .i_button(i_btn_calc),
        .o_pulse(pulse_calc), .o_level()
    );

    // Para el reset se usa el NIVEL, no el pulso: un reset debe mantenerse
    // activo mientras el boton este apretado, no durar un solo ciclo.
    button_conditioner #(.NB_COUNT(NB_DEBOUNCE)) u_cond_reset (
        .i_clock(i_clock), .i_button(i_btn_reset),
        .o_pulse(), .o_level(reset)
    );

    //=========================================================================
    // Registros de entrada: TRES instancias del mismo modulo generico,
    // las tres de NB_DATA bits
    //=========================================================================
    wire [NB_DATA-1:0] reg_a_out;
    wire [NB_DATA-1:0] reg_b_out;
    wire [NB_DATA-1:0] reg_op_out;

    register #(.NB(NB_DATA)) u_reg_a (
        .i_clock  (i_clock),
        .i_reset  (reset),
        .i_enable (pulse_a),
        .i_data   (i_switches),
        .o_data   (reg_a_out)
    );

    register #(.NB(NB_DATA)) u_reg_b (
        .i_clock  (i_clock),
        .i_reset  (reset),
        .i_enable (pulse_b),
        .i_data   (i_switches),
        .o_data   (reg_b_out)
    );

    register #(.NB(NB_DATA)) u_reg_op (
        .i_clock  (i_clock),
        .i_reset  (reset),
        .i_enable (pulse_op),
        .i_data   (i_switches),
        .o_data   (reg_op_out)
    );

    //=========================================================================
    // Mascara del opcode
    //
    // El registro guarda los 8 bits que vienen de los switches, pero la ALU
    // solo acepta NB_OP_CODE (6). La mascara pone en cero los bits sobrantes
    // para que un switch alto de mas no se cuele como parte del codigo.
    //
    // Con NB_DATA=8 y NB_OP_CODE=6 la mascara vale 8'b00111111.
    // Al construirse a partir de los parametros, se ajusta sola si cambian.
    //=========================================================================
    localparam [NB_DATA-1:0] OP_CODE_MASK =
        { {(NB_DATA-NB_OP_CODE){1'b0}}, {NB_OP_CODE{1'b1}} };

    wire [NB_DATA-1:0]    op_masked = reg_op_out & OP_CODE_MASK;
    wire [NB_OP_CODE-1:0] op_code   = op_masked[NB_OP_CODE-1:0];

    //=========================================================================
    // ALU (combinacional)
    //=========================================================================
    wire [NB_DATA-1:0] alu_result;
    wire               alu_carry;
    wire               alu_zero;

    alu #(
        .NB_DATA    (NB_DATA),
        .NB_OP_CODE (NB_OP_CODE)
    ) u_alu (
        .o_result  (alu_result),
        .o_carry   (alu_carry),
        .o_zero    (alu_zero),
        .i_data_a  (reg_a_out),
        .i_data_b  (reg_b_out),
        .i_op_code (op_code)
    );

    //=========================================================================
    // Registro de salida
    //
    // Cumple DOS funciones:
    //
    //  1) FUNCIONAL: retiene el resultado anterior mientras se modifican los
    //     operandos. Solo se actualiza cuando se aprieta el boton de calcular.
    //
    //  2) DE TEMPORIZADO: crea un camino flip-flop -> logica combinacional ->
    //     flip-flop (reg_a/reg_b/reg_op -> ALU -> este registro), que es lo
    //     que el analizador de tiempos de Vivado puede medir y reportar. Sin
    //     el, todos los caminos irian de un registro a un puerto de salida y
    //     el reporte de timing quedaria practicamente vacio.
    //
    // Se reutiliza el mismo modulo generico, empaquetando resultado y
    // banderas en un solo vector de NB_DATA+2 bits.
    //=========================================================================
    wire [NB_DATA+1:0] alu_bundle = {alu_zero, alu_carry, alu_result};
    wire [NB_DATA+1:0] out_bundle;

    register #(.NB(NB_DATA+2)) u_reg_out (
        .i_clock  (i_clock),
        .i_reset  (reset),
        .i_enable (pulse_calc),
        .i_data   (alu_bundle),
        .o_data   (out_bundle)
    );

    assign o_leds      = out_bundle[NB_DATA-1:0];
    assign o_led_carry = out_bundle[NB_DATA];
    assign o_led_zero  = out_bundle[NB_DATA+1];

endmodule
