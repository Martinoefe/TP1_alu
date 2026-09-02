# Trabajo Práctico N°1 — ALU

Arquitectura de Computadoras — FCEFyN, Universidad Nacional de Córdoba

Implementación en Verilog de una ALU parametrizable, con test bench autoverificado y análisis de tiempo en Vivado.

## Contenido del repositorio

| Archivo | Descripción |
|---|---|
| `src/alu.v` | Módulo de la ALU (combinacional, parametrizable) |
| `src/top.v` | Módulo envoltorio: switches, botones y LEDs |
| `sim/tb_alu.v` | Test bench autoverificado con estímulos aleatorios |
| `docs/informe.md` | Informe del trabajo práctico |

## Descripción del diseño

### ALU (`alu.v`)

Unidad aritmético-lógica **puramente combinacional** (sin flip-flops ni señal de reloj), implementada con un bloque `always @(*)` y una sentencia `case`.

**Parámetros:**

| Parámetro | Valor por defecto | Descripción |
|---|---|---|
| `NB_DATA` | 8 | Ancho del bus de datos |
| `NB_OP_CODE` | 6 | Ancho del código de operación |

**Puertos:**

| Puerto | Dirección | Ancho | Descripción |
|---|---|---|---|
| `i_data_a` | entrada | `NB_DATA` | Primer operando |
| `i_data_b` | entrada | `NB_DATA` | Segundo operando |
| `i_op_code` | entrada | `NB_OP_CODE` | Código de operación |
| `o_result` | salida | `NB_DATA` | Resultado |

**Operaciones soportadas:**

| Operación | Código | Descripción |
|---|---|---|
| ADD | `100000` | Suma |
| SUB | `100010` | Resta |
| AND | `100100` | AND bit a bit |
| OR | `100101` | OR bit a bit |
| XOR | `100110` | XOR bit a bit |
| NOR | `100111` | NOR bit a bit |
| SRL | `000010` | Desplazamiento lógico a derecha |
| SRA | `000011` | Desplazamiento aritmético a derecha |

### Decisiones de diseño

**Desplazamientos.** Los códigos de operación coinciden con los del campo *funct* de MIPS, por lo que se adoptó su convención: se desplaza `i_data_b`, y la cantidad de posiciones se toma de los 3 bits menos significativos de `i_data_a`. Tres bits alcanzan para representar desplazamientos de 0 a 7 posiciones en un dato de 8 bits.

**SRA y extensión de signo.** El operador `>>>` solo preserva el bit de signo si el operando está declarado como `signed`. Como los puertos son `wire` sin signo, se aplica `$signed()` sobre `i_data_b` en esa rama del `case`. Sin esa conversión, SRA se comportaría igual que SRL.

**Cláusula `default`.** El código de operación es de 6 bits (64 combinaciones posibles) y solo 8 están definidas. La rama `default` cubre las 56 restantes, evitando que el sintetizador infiera un latch por dejar `o_result` sin asignar en algún camino de ejecución.

### Módulo envoltorio (`top.v`)

Resuelve la interfaz con el hardware físico de la placa. Como el banco de switches no alcanza para cargar los tres operandos simultáneamente (8 + 8 + 6 = 22 bits), se reutiliza el mismo banco tres veces:

- Tres botones (`i_btn_a`, `i_btn_b`, `i_btn_op`) confirman en qué registro almacenar el valor actual de los switches.
- Cada registro se carga en el flanco positivo del reloj, sincronizando la pulsación (entrada asíncrona) con el dominio de reloj del sistema.
- Los tres registros alimentan la ALU, cuyo resultado se refleja de forma continua en los LEDs.

## Test bench autoverificado

El test bench (`sim/tb_alu.v`) implementa los requisitos de la consigna:

- **Estímulos aleatorios** mediante `$random` para ambos operandos.
- **Selección de operaciones válidas**: el código de operación se sortea sobre un arreglo con los 8 códigos definidos, en lugar de generarlo al azar entre los 64 valores posibles. De otro modo, la mayoría de los casos caería en la rama `default`.
- **Chequeo automático**: un modelo de referencia calcula independientemente el resultado esperado y lo compara contra la salida del DUT en cada iteración. Se utiliza el operador de desigualdad estricta (`!==`) para detectar también valores indefinidos (`x`) o de alta impedancia (`z`).
- **Reporte por consola**: cada discrepancia imprime los operandos y el código de operación que la causaron; al finalizar se informa el total.

### Resultado

```
TODOS LOS TESTS PASARON (200/200)
$finish called at time : 2 us
```

## Análisis de tiempo

Síntesis realizada en Vivado para el dispositivo `xc7a35tcpg236-1` (Artix-7).

**Camino crítico** (Report Timing Summary → Unconstrained Paths → Setup):

| | |
|---|---|
| Origen | `reg_a_reg[1]/C` |
| Destino | `o_leds[7]` |
| Logic Delay | 5.046 ns |
| Net Delay | 2.402 ns |
| **Total Delay** | **7.448 ns** |
| Niveles lógicos | 8 |

**Interpretación.** El camino más lento conecta el flip-flop del bit 1 del operando A con el bit más significativo de la salida, atravesando 8 niveles lógicos. Esto es consistente con la cadena de acarreo de las operaciones de suma y resta: para que un bit de bajo peso influya sobre el bit más significativo del resultado, el acarreo debe propagarse secuencialmente a través de todas las etapas intermedias. Los caminos hacia bits de menor peso presentan menos niveles y menor retardo (`o_leds[0]`: 6.516 ns, 6 niveles).

A partir del retardo total, la frecuencia máxima teórica de operación resulta:

```
f_max = 1 / 7.448 ns ≈ 134 MHz
```

No se definieron restricciones de reloj, por lo que Vivado reporta los caminos como *unconstrained* (Slack = ∞): se mide el retardo de propagación real de la lógica sintetizada, sin evaluarlo contra un requisito de período.

## Cómo reproducir

### Simulación

1. Crear un proyecto RTL en Vivado con el dispositivo `xc7a35tcpg236-1`.
2. Agregar `src/alu.v` y `src/top.v` como *design sources*.
3. Agregar `sim/tb_alu.v` como *simulation source*.
4. Ejecutar **Run Simulation → Run Behavioral Simulation**.
5. Ejecutar **Run All** (el test bench requiere 2 µs de simulación).
6. Verificar el mensaje de resultado en la consola Tcl.

### Síntesis y análisis de tiempo

1. Ejecutar **Run Synthesis**.
2. Abrir **Open Synthesized Design**.
3. Ejecutar **Report Timing Summary**.
4. Navegar a **Unconstrained Paths → NONE to NONE → Setup**.
