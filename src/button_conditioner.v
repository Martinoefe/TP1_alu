`timescale 1ns / 1ps

//=============================================================================
// Acondicionador de boton
//
// Resuelve los TRES problemas de un pulsador mecanico conectado a un
// circuito sincrono:
//
//   1) METAESTABILIDAD: el boton es asincrono respecto del reloj. Si cambia
//      justo en el flanco viola los tiempos de setup/hold del flip-flop, que
//      puede quedar en un estado indefinido.
//      -> Sincronizador de dos flip-flops en cascada.
//
//   2) REBOTE (bouncing): los contactos mecanicos generan decenas de
//      transiciones 0<->1 durante algunos milisegundos al cerrarse. A 100 MHz
//      el circuito veria cada rebote como una pulsacion distinta.
//      -> Contador antirrebote: el valor solo se acepta si se mantuvo estable
//         durante 2^NB_COUNT ciclos.
//
//   3) DURACION: aun con la senal limpia, mantener el boton 100 ms equivale a
//      10 millones de ciclos en alto.
//      -> Detector de flanco: un unico pulso de un ciclo por pulsacion.
//
// Salidas:
//   o_pulse : 1 solo ciclo por pulsacion  (para habilitar registros)
//   o_level : nivel limpio y sincronizado (para senales tipo reset)
//=============================================================================
module button_conditioner
#(
    parameter NB_COUNT = 17      // 2^17 ciclos @100MHz ~= 1.31 ms
)
(
    input  wire i_clock,
    input  wire i_button,
    output wire o_pulse,
    output wire o_level
);

    //-------------------------------------------------------------------------
    // 1) Sincronizador de dos flip-flops.
    //
    // Notar que este bloque NO tiene reset: es la cadena que sincroniza la
    // entrada asincrona, y agregarle un reset asincrono reintroduciria el
    // mismo problema que se esta tratando de resolver.
    //-------------------------------------------------------------------------
    reg sync_ff1 = 1'b0;
    reg sync_ff2 = 1'b0;

    always @(posedge i_clock)
    begin
        sync_ff1 <= i_button;
        sync_ff2 <= sync_ff1;
    end

    //-------------------------------------------------------------------------
    // 2) Antirrebote por contador
    //-------------------------------------------------------------------------
    reg [NB_COUNT-1:0] counter = {NB_COUNT{1'b0}};
    reg                stable  = 1'b0;

    always @(posedge i_clock)
    begin
        if (sync_ff2 != stable)
        begin
            counter <= counter + 1'b1;
            if (&counter)               // el contador llego a todos unos
            begin
                stable  <= sync_ff2;    // se acepta el nuevo valor
                counter <= {NB_COUNT{1'b0}};
            end
        end
        else
            counter <= {NB_COUNT{1'b0}}; // volvio al valor actual: reiniciar
    end

    //-------------------------------------------------------------------------
    // 3) Detector de flanco ascendente
    //-------------------------------------------------------------------------
    reg stable_d = 1'b0;

    always @(posedge i_clock)
        stable_d <= stable;

    assign o_pulse = stable & ~stable_d;
    assign o_level = stable;

endmodule
