VERILATOR        = verilator
INCLUDE_DIRS     = -Irtl -Itb

VFLAGS           = $(INCLUDE_DIRS) -Wall --trace -Wno-WIDTHTRUNC --timing --coverage --assert

TOP_MODULE_FIFO  = fifo_cache_tb
TOP_MODULE_ALU   = hsi_vector_core_tb
TOP_MODULE_WRAPPER = hsi_vector_core_wrapper_tb

SRC_FIFO         = tb/fifo_cache_tb.sv hw/rtl/fifo_cache.sv
SRC_ALU          = tb/hsi_vector_core_tb.sv hw/rtl/hsi_vector_core.sv  hw/rtl/fifo_cache.sv
SRC_WRAPPER = tb/hsi_vector_core_wrapper_tb.sv hw/rtl/hsi_vector_core_wrapper.sv
SRC_CPP          = sim/sim_main.cpp

BUILD_DIR        = build/
COVERAGE_DIR     = coverage/
DIAGRAM_DIR      = diagrams/

.DEFAULT_GOAL := help

help:
	@echo "Uso: make [target]"
	@echo ""
	@echo "Targets disponibles:"
	@echo "  fifo_cache     Compila y simula el testbench del módulo fifo_cache"
	@echo "  hsi_core       Compila y simula el testbench del módulo hsi_vector_core"
	@echo "  hsi_wrapper    Compila y simula el wrapper de hsi_vector_core (con interfaz OBI)"
	@echo "  coverage       Genera informe HTML con la cobertura funcional (genhtml)"
	@echo "  diagram        Genera diagrama RTL del módulo fifo_cache (SVG en diagrams/)"
	@echo "  doc            Genera documentación HTML con Doxygen en doc/html/"
	@echo "  all            Ejecuta todos los pasos anteriores (excepto help y clean)"
	@echo "  clean          Elimina archivos generados por Verilator, cobertura, doc, etc."
	@echo "  help           Muestra esta ayuda"

all: fifo_cache hsi_core coverage diagram doc

fifo_cache:
	$(VERILATOR) $(VFLAGS) --cc --exe \
		$(SRC_FIFO) $(SRC_CPP) \
		-CFLAGS "-DVL_MODULE=\\\"V$(TOP_MODULE_FIFO).h\\\" -DVL_TOP_TYPE=V$(TOP_MODULE_FIFO)" \
		--top-module $(TOP_MODULE_FIFO) \
		-Mdir $(BUILD_DIR)
	cd $(BUILD_DIR) && make -f V$(TOP_MODULE_FIFO).mk
	cd $(BUILD_DIR) && ./V$(TOP_MODULE_FIFO)

hsi_core:
	$(VERILATOR) $(VFLAGS) --cc --exe \
		$(SRC_ALU) $(SRC_CPP) \
		-CFLAGS "-DVL_MODULE=\\\"V$(TOP_MODULE_ALU).h\\\" -DVL_TOP_TYPE=V$(TOP_MODULE_ALU)" \
		--top-module $(TOP_MODULE_ALU) \
		-Mdir $(BUILD_DIR)
	cd $(BUILD_DIR) && make -f V$(TOP_MODULE_ALU).mk
	cd $(BUILD_DIR) && ./V$(TOP_MODULE_ALU)
hsi_wrapper:
	$(VERILATOR) $(VFLAGS) --cc --exe \
		$(SRC_WRAPPER) $(SRC_CPP) \
		-CFLAGS "-DVL_MODULE=\\\"V$(TOP_MODULE_WRAPPER).h\\\" -DVL_TOP_TYPE=V$(TOP_MODULE_WRAPPER)" \
		--top-module $(TOP_MODULE_WRAPPER) \
		-Mdir $(BUILD_DIR)
	cd $(BUILD_DIR) && make -f V$(TOP_MODULE_WRAPPER).mk
	cd $(BUILD_DIR) && ./V$(TOP_MODULE_WRAPPER)


coverage:
	verilator_coverage --write-info $(BUILD_DIR)/coverage.info $(BUILD_DIR)/coverage.dat
	genhtml $(BUILD_DIR)/coverage.info --output-directory $(COVERAGE_DIR)

diagram:
	mkdir -p $(DIAGRAM_DIR)
	echo "read_verilog -sv rtl/fifo_cache.sv; \
	      hierarchy -top fifo_cache; \
	      proc; opt; memory; opt; techmap; \
	      show -format svg -prefix $(DIAGRAM_DIR)/fifo_diagram" | yosys

doc:
	doxygen Doxyfile

clean:
	rm -rf $(BUILD_DIR) $(COVERAGE_DIR) $(DIAGRAM_DIR) doc *.vcd *.o *.d *.vvp *.log 

.PHONY: all fifo_cache hsi_core hsi_wrapper coverage diagram doc clean help
