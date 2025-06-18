#include "verilated.h"
#include "verilated_vcd_c.h"
#include <verilated_cov.h>

// Macros esperadas:
//   VL_MODULE     → nombre del header del DUT (ej: "Vfifo_cache_tb.h")
//   VL_TOP_TYPE   → tipo del objeto top (ej: Vfifo_cache_tb)

#ifndef VL_MODULE
# error "Debe definir VL_MODULE como el nombre del archivo .h del DUT (por ejemplo: -DVL_MODULE='\"Vfifo_cache_tb.h\"')"
#endif

#ifndef VL_TOP_TYPE
# error "Debe definir VL_TOP_TYPE como el nombre del tipo del módulo (por ejemplo: -DVL_TOP_TYPE=Vfifo_cache_tb)"
#endif

#include VL_MODULE  // incluir el archivo de cabecera correspondiente

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    VL_TOP_TYPE* top = new VL_TOP_TYPE;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("dump.vcd");

    top->eval();
    tfp->dump(main_time);

    const vluint64_t MAX_TIME = 1000000;
    while (!Verilated::gotFinish() && main_time < MAX_TIME) {
        main_time++;
        Verilated::timeInc(1);
        top->eval();
        tfp->dump(main_time);
    }

    Verilated::threadContextp()->coveragep()->write("coverage.dat");

    tfp->close();
    delete tfp;
    delete top;
    return 0;
}
