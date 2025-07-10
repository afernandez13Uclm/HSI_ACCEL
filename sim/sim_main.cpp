/**
 * @file sim_main.cpp
 * @brief Archivo principal para la simulación con Verilator de un módulo SystemVerilog.
 *
 * @details
 * Este archivo implementa un entorno mínimo para simular un DUT (Device Under Test) generado con Verilator.
 * Admite trazado VCD (cambio de señales) y cobertura de código. El nombre del módulo a simular debe proporcionarse
 * mediante macros de compilación:
 *
 * - `VL_MODULE`     → cadena con el nombre del archivo de cabecera del DUT, por ejemplo `"Vmodulo_tb.h"`.
 * - `VL_TOP_TYPE`   → tipo del objeto top-level generado por Verilator, por ejemplo `Vmodulo_tb`.
 *
 * Estas macros deben definirse en la línea de compilación mediante `-D`:
 * ```bash
 * verilator ... -DVL_MODULE="\\\"Vmodulo_tb.h\\\"" -DVL_TOP_TYPE=Vmodulo_tb ...
 * ```
 *
 * La simulación se detiene tras alcanzar un tiempo máximo (`MAX_TIME`) o cuando el DUT indique finalización.
 *
 * @author
 * Alejandro Fernández Rodríguez, UCLM
 *
 * @version 1.0
 * @date 2025
 *
 * @copyright
 * Copyright (c) 2025 Alejandro Fernández Rodríguez
 * Licensed under the MIT License.
 */

#include "verilated.h"
#include "verilated_vcd_c.h"
#include <verilated_cov.h>

/// @brief Verifica que las macros requeridas estén definidas
#ifndef VL_MODULE
# error "Debe definir VL_MODULE como el nombre del archivo .h del DUT (por ejemplo: -DVL_MODULE='\\\"Vfifo_cache_tb.h\\\"')"
#endif

#ifndef VL_TOP_TYPE
# error "Debe definir VL_TOP_TYPE como el nombre del tipo del módulo (por ejemplo: -DVL_TOP_TYPE=Vfifo_cache_tb)"
#endif

/// @brief Inclusión del DUT generado por Verilator (mediante macro)
#include VL_MODULE

/// @brief Reloj simulado actual en unidades Verilator
vluint64_t main_time = 0;

/// @brief Función requerida por Verilator para obtener el timestamp
double sc_time_stamp() {
    return main_time;
}

/**
 * @brief Punto de entrada principal para la simulación.
 *
 * @param argc Número de argumentos de línea de comandos
 * @param argv Argumentos de línea de comandos
 * @return Código de salida estándar (0 si correcto)
 *
 * @details
 * Crea el objeto `top` del DUT, inicializa la traza VCD, ejecuta la simulación
 * durante un máximo de `MAX_TIME` ciclos y escribe los resultados de cobertura.
 */
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);        ///< Procesa argumentos de simulación
    Verilated::traceEverOn(true);              ///< Habilita trazado VCD global

    VL_TOP_TYPE* top = new VL_TOP_TYPE;        ///< Instancia del DUT

    VerilatedVcdC* tfp = new VerilatedVcdC;    ///< Objeto de traza VCD
    top->trace(tfp, 99);                       ///< Conecta el DUT al trazador
    tfp->open("dump.vcd");                     ///< Archivo de salida de señales

    top->eval();                               ///< Evaluación inicial
    tfp->dump(main_time);                      ///< Dump del primer estado

    const vluint64_t MAX_TIME = 1000000;       ///< Límite máximo de tiempo simulado
    while (!Verilated::gotFinish() && main_time < MAX_TIME) {
        main_time++;
        Verilated::timeInc(1);                 ///< Incremento interno de tiempo Verilator
        top->eval();                           ///< Evaluación del DUT
        tfp->dump(main_time);                  ///< Dump al archivo VCD
    }

    Verilated::threadContextp()->coveragep()->write("coverage.dat"); ///< Dump de cobertura

    tfp->close();                              ///< Cierra el archivo de traza
    delete tfp;
    delete top;
    return 0;
}
