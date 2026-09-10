##=============================================================================
## Constraints - TP1 ALU
## Digilent Basys3 - Artix-7 xc7a35tcpg236-1
##
## VERIFICAR estos pines contra el XDC maestro oficial de Digilent
## (github.com/Digilent/digilent-xdc -> Basys-3-Master.xdc) antes de programar
## la placa. Si la placa de la facultad no es una Basys3, el archivo maestro
## que corresponda a ese modelo es el que manda.
##=============================================================================

##-----------------------------------------------------------------------------
## Reloj de 100 MHz
##
## El create_clock es lo que habilita el ANALISIS DE TIEMPO que pide el
## enunciado: sin este constraint, Vivado no tiene contra que comparar los
## retardos del camino combinacional y el reporte de timing queda vacio.
##-----------------------------------------------------------------------------
set_property PACKAGE_PIN W5 [get_ports i_clock]
set_property IOSTANDARD LVCMOS33 [get_ports i_clock]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports i_clock]

##-----------------------------------------------------------------------------
## Switches SW0..SW7 -> operandos y codigo de operacion
##-----------------------------------------------------------------------------
set_property PACKAGE_PIN V17 [get_ports {i_switches[0]}]
set_property PACKAGE_PIN V16 [get_ports {i_switches[1]}]
set_property PACKAGE_PIN W16 [get_ports {i_switches[2]}]
set_property PACKAGE_PIN W17 [get_ports {i_switches[3]}]
set_property PACKAGE_PIN W15 [get_ports {i_switches[4]}]
set_property PACKAGE_PIN V15 [get_ports {i_switches[5]}]
set_property PACKAGE_PIN W14 [get_ports {i_switches[6]}]
set_property PACKAGE_PIN W13 [get_ports {i_switches[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[*]}]

##-----------------------------------------------------------------------------
## LEDs LD0..LD7 -> resultado
##-----------------------------------------------------------------------------
set_property PACKAGE_PIN U16 [get_ports {o_leds[0]}]
set_property PACKAGE_PIN E19 [get_ports {o_leds[1]}]
set_property PACKAGE_PIN U19 [get_ports {o_leds[2]}]
set_property PACKAGE_PIN V19 [get_ports {o_leds[3]}]
set_property PACKAGE_PIN W18 [get_ports {o_leds[4]}]
set_property PACKAGE_PIN U15 [get_ports {o_leds[5]}]
set_property PACKAGE_PIN U14 [get_ports {o_leds[6]}]
set_property PACKAGE_PIN V14 [get_ports {o_leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[*]}]

## LD14 -> carry   |   LD15 -> zero
set_property PACKAGE_PIN P1 [get_ports o_led_carry]
set_property IOSTANDARD LVCMOS33 [get_ports o_led_carry]

set_property PACKAGE_PIN L1 [get_ports o_led_zero]
set_property IOSTANDARD LVCMOS33 [get_ports o_led_zero]

##-----------------------------------------------------------------------------
## Botones (los cinco de la placa)
##   btnC (U18) -> reset
##   btnU (T18) -> cargar operando A
##   btnL (W19) -> cargar operando B
##   btnR (T17) -> cargar codigo de operacion
##   btnD (U17) -> calcular (habilita el registro de salida)
##-----------------------------------------------------------------------------
set_property PACKAGE_PIN U18 [get_ports i_btn_reset]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_reset]

set_property PACKAGE_PIN T18 [get_ports i_btn_a]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_a]

set_property PACKAGE_PIN W19 [get_ports i_btn_b]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_b]

set_property PACKAGE_PIN T17 [get_ports i_btn_op]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_op]

set_property PACKAGE_PIN U17 [get_ports i_btn_calc]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_calc]

##-----------------------------------------------------------------------------
## Caminos sin analisis de temporizado.
##
## Botones y switches son senales ASINCRONAS: no tienen ninguna relacion
## temporal con el reloj del sistema, asi que analizarlas produciria
## violaciones falsas que taparian las reales. Los botones ya estan tratados
## por el sincronizador de dos flip-flops dentro de button_conditioner.
##
## Lo mismo para los LEDs: son salidas hacia un dispositivo sin requisitos de
## temporizado (el ojo humano no tiene setup/hold).
##-----------------------------------------------------------------------------
set_false_path -from [get_ports i_btn_reset]
set_false_path -from [get_ports i_btn_a]
set_false_path -from [get_ports i_btn_b]
set_false_path -from [get_ports i_btn_op]
set_false_path -from [get_ports i_btn_calc]
set_false_path -from [get_ports {i_switches[*]}]
set_false_path -to   [get_ports {o_leds[*]}]
set_false_path -to   [get_ports o_led_carry]
set_false_path -to   [get_ports o_led_zero]

##-----------------------------------------------------------------------------
## Configuracion del bitstream
##-----------------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
