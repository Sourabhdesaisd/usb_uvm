
#===========================================================
# USB 2.0 PHY UVM Testbench - Xcelium Makefile
#===========================================================

# Simulator
XRUN        ?= xrun
TOP         ?= tb_top
FILELIST    ?= filelist.f

# UVM test selection
TEST        ?= usb_phy_base_test

# USB speed:
# 0 = Low Speed
# 1 = Full Speed
# 2 = High Speed
USB_SPEED   ?= 1

# Simulation control
SEED        ?= 1
UVM_VERBOSITY ?= UVM_MEDIUM

# Output directories
LOG_DIR     ?= logs
WORK_DIR    ?= xcelium_work

# Log file
LOG_FILE    = $(LOG_DIR)/$(TEST)_speed$(USB_SPEED)_seed$(SEED).log

# Xcelium options
XRUN_FLAGS  = -64bit -uvm -sv -access +rwc

# Runtime arguments
RUN_ARGS    = +UVM_TESTNAME=$(TEST) \
              +USB_SPEED=$(USB_SPEED) \
              +UVM_VERBOSITY=$(UVM_VERBOSITY) \
              -seed $(SEED)

.PHONY: all run compile ls fs hs regression clean help

# Default target
all: run

#-----------------------------------------------------------
# Run selected test at selected speed
# Example:
# make run TEST=usb_phy_base_test USB_SPEED=1 SEED=10
#-----------------------------------------------------------
run:
	@mkdir -p $(LOG_DIR)
	@echo "=================================================="
	@echo " USB 2.0 PHY UVM Simulation"
	@echo " Test       : $(TEST)"
	@echo " USB Speed  : $(USB_SPEED)"
	@echo " Seed       : $(SEED)"
	@echo " Log        : $(LOG_FILE)"
	@echo "=================================================="
	$(XRUN) $(XRUN_FLAGS) -f $(FILELIST) -top $(TOP) \
		$(RUN_ARGS) -l $(LOG_FILE)

#-----------------------------------------------------------
# Speed-specific targets
#-----------------------------------------------------------
ls:
	$(MAKE) run USB_SPEED=0

fs:
	$(MAKE) run USB_SPEED=1

hs:
	$(MAKE) run USB_SPEED=2

#-----------------------------------------------------------
# Basic regression: run the selected test at all speeds
# Each speed gets a separate log file.
#-----------------------------------------------------------
regression:
	$(MAKE) run USB_SPEED=0 SEED=$(SEED)
	$(MAKE) run USB_SPEED=1 SEED=$(SEED)
	$(MAKE) run USB_SPEED=2 SEED=$(SEED)

#-----------------------------------------------------------
# Optional compile-only target
# - Use this only if your Xcelium version supports the
#   compile/elaboration flow used by your project.
#-----------------------------------------------------------
compile:
	@mkdir -p $(LOG_DIR)
	$(XRUN) $(XRUN_FLAGS) -f $(FILELIST) -top $(TOP) \
		-elaborate -l $(LOG_DIR)/elaborate.log

#-----------------------------------------------------------
# Clean generated simulation files
#-----------------------------------------------------------
clean:
	rm -rf xcelium.d INCA_libs $(WORK_DIR) *.history
	rm -rf $(LOG_DIR)
	rm -f *.key *.log *.diag

#-----------------------------------------------------------
# Help
#-----------------------------------------------------------
help:
	@echo "USB 2.0 PHY UVM Makefile targets:"
	@echo "  make run                 Run default test at FS"
	@echo "  make ls                  Run at Low Speed"
	@echo "  make fs                  Run at Full Speed"
	@echo "  make hs                  Run at High Speed"
	@echo "  make regression          Run LS, FS and HS"
	@echo "  make compile             Elaborate the design"
	@echo "  make clean               Remove generated files"
	@echo ""
	@echo "Variables:"
	@echo "  TEST=usb_phy_base_test"
	@echo "  USB_SPEED=0|1|2"
	@echo "  SEED=1"
	@echo "  UVM_VERBOSITY=UVM_MEDIUM"
