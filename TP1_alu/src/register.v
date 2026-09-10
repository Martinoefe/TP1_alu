`timescale 1ns / 1ps

//=============================================================================
// Registro generico con habilitacion y reset sincrono.
//
// Este es el modulo que permite MODULARIZAR el top: en vez de escribir tres
// bloques always casi identicos para A, B y opcode, se instancia este mismo
// modulo varias veces. Un solo lugar donde revisar la logica de carga.
//
//   i_enable = 1  -> en el proximo flanco captura i_data
//   i_enable = 0  -> RETIENE el valor anterior
//
// Esa retencion es justamente lo que hace que el resultado en los LEDs no
// cambie mientras se estan modificando los operandos.
//=============================================================================
module register
#(
    parameter NB = 8
)
(
    input  wire          i_clock,
    input  wire          i_reset,     // reset sincrono, activo alto
    input  wire          i_enable,
    input  wire [NB-1:0] i_data,
    output reg  [NB-1:0] o_data
);

    always @(posedge i_clock)
    begin
        if (i_reset)
            o_data <= {NB{1'b0}};
        else if (i_enable)
            o_data <= i_data;
        // sin else: si i_enable=0 el registro conserva su valor.
        // Esto NO infiere un latch: dentro de un always @(posedge clk) la
        // retencion es exactamente el comportamiento de un flip-flop.
    end

endmodule
