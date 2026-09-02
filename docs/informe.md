# Trabajo Práctico N°1 — ALU

## 1. Objetivo

Implementar en FPGA una ALU (Unidad Aritmético-Lógica) parametrizable, validarla con un test bench autoverificado con entradas aleatorias, y simular el diseño con Vivado incluyendo análisis de tiempo.

## 2. Diseño de la ALU

### 2.1 Interfaz

```verilog
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
```

La ALU es **puramente combinacional** (sin flip-flops, sin señal de clock). Los anchos de datos (`NB_DATA`) y de código de operación (`NB_OP_CODE`) son parametrizables, cumpliendo el requisito de reutilización para el trabajo final de la materia.

### 2.2 Tabla de operaciones

| Operación | Código binario |
|---|---|
| ADD | 100000 |
| SUB | 100010 |
| AND | 100100 |
| OR  | 100101 |
| XOR | 100110 |
| SRA | 000011 |
| SRL | 000010 |
| NOR | 100111 |

### 2.3 Decisión de diseño: shifts (SRA / SRL)

Los códigos de operación de la tabla coinciden con los de la ALU clásica de MIPS. Siguiendo esa convención:

- Se desplaza **`i_data_b`**.
- La cantidad de desplazamiento sale de los **3 bits bajos de `i_data_a`** (`i_data_a[2:0]`), suficiente para representar desplazamientos de 0 a 7 posiciones en un dato de 8 bits.

### 2.4 Código completo

```verilog
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
```

**Notas de implementación:**
- `NOR` se arma como `~(A | B)`, ya que Verilog no tiene un operador NOR directo.
- `SRA` usa `$signed(...)` sobre `i_data_b` para que el operador `>>>` respete el bit de signo (extensión con 1s si el número es negativo en complemento a 2); sin esa conversión, `i_data_b` se trata como sin signo y `>>>` se comporta igual que `>>`.
- El `default` cubre las 56 combinaciones de `i_op_code` no definidas en la tabla, evitando la inferencia de un latch no deseado (la lista de sensibilidad `@(*)` exige que toda salida quede asignada en cualquier camino posible).

## 3. Módulo envoltorio (top): interfaz física

La ALU se integra en un módulo `top` que resuelve la interfaz con el hardware físico de la placa (switches, botones, LEDs):

- Un único banco de **switches** (8 bits) se reutiliza para cargar los tres datos de entrada (A, B y el código de operación), de a uno por vez.
- Tres **botones** (`i_btn_a`, `i_btn_b`, `i_btn_op`) confirman en qué registro guardar el valor actual de los switches.
- Cada botón está sincronizado al clock del sistema (`posedge i_clock`), tratando la pulsación como una entrada asíncrona que debe "aterrizar" en la grilla de tiempo del circuito antes de propagarse al resto del diseño.
- Los tres registros (`reg_a`, `reg_b`, `reg_op`) alimentan la ALU, que recalcula su resultado de forma continua (sin necesidad de ningún botón adicional) y lo refleja en los **LEDs**.

```verilog
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
```

## 4. Test bench autoverificado

Se implementó un test bench que genera estímulos aleatorios (mediante `$random`), calcula de forma independiente el resultado esperado para cada operación (un "modelo de referencia" que replica la tabla de operaciones), y compara automáticamente ambos resultados sin intervención manual.

```verilog
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
```

**Resultado de la simulación (Vivado, Behavioral Simulation):**

```
TODOS LOS TESTS PASARON (200/200)
$finish called at time : 2 us
```

Las 200 combinaciones aleatorias de operandos y las 8 operaciones válidas fueron verificadas sin errores.

## 5. Análisis de tiempo

Se sintetizó el diseño en Vivado (2026.1, part `xc7a35tcpg236-1`) y se generó el reporte de tiempos (Report Timing Summary → Unconstrained Paths → Setup).

### 5.1 Camino crítico

| | |
|---|---|
| Origen | `reg_a_reg[1]/C` |
| Destino | `o_leds[7]` |
| Logic Delay | 5.046 ns |
| Net Delay | 2.402 ns |
| **Total Delay** | **7.448 ns** |
| Niveles lógicos | 8 |

### 5.2 Interpretación

El camino más lento del diseño conecta el bit 1 de `reg_a` con el bit 7 (MSB) de la salida, atravesando 8 niveles lógicos. Esto es consistente con la **cadena de acarreo (carry chain)** de las operaciones `ADD`/`SUB`: para que un bit de entrada de bajo peso pueda influir en el bit más significativo del resultado, la señal de acarreo debe propagarse secuencialmente a través de cada etapa de la suma, lo que explica tanto la cantidad de niveles lógicos como el delay resultante.

A partir del delay total, la frecuencia máxima teórica de operación (si el circuito se sincronizara con un clock) sería:

```
f_max = 1 / 7.448 ns ≈ 134 MHz
```

No se definieron restricciones de reloj (`.xdc` con `create_clock`) para este análisis, por lo que Vivado reporta los caminos como "unconstrained" (Slack = ∞): se midió el tiempo de propagación real de la lógica sintetizada, sin evaluarlo contra un requisito de período específico.

## 6. Conclusiones

- La ALU cumple funcionalmente con las 8 operaciones especificadas, validado mediante 200 pruebas aleatorias autoverificadas sin errores.
- Es parametrizable en ancho de datos y ancho de código de operación, permitiendo su reutilización en el trabajo final.
- El camino crítico identificado (7.448 ns, operación de suma/resta) es coherente con el comportamiento esperado de un sumador de propagación de acarreo, y determina la frecuencia máxima de operación del diseño combinacional.
