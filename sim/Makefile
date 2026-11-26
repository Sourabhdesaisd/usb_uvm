
#===========================================================
# USB 2.0 PHY UVM Testbench - Xcelium Makefile
#===========================================================
LOG_DIR ?= logs
REGRESSION_SUMMARY := $(LOG_DIR)/regression_summary.txt

REGRESSION_SPEEDS = 0 1 2
# Simulator
XRUN        ?= xrun
TOP         ?= top_tb
FILELIST    ?= filelist.f

# UVM test selection
TEST        ?= usb_phy_full_path_test

# USB speed:
# 0 = Low Speed
# 1 = Full Speed
# 2 = High Speed
USB_SPEED   ?= 1

# Simulation control
SEED        ?= 1
FAULT       ?= 1
RESET_CASE  ?= 0
UVM_VERBOSITY ?= UVM_MEDIUM

# Output directories
LOG_DIR     ?= logs
WORK_DIR    ?= xcelium_work

# Log file
LOG_FILE    = $(LOG_DIR)/$(TEST)_speed$(USB_SPEED)_fault$(FAULT)_reset$(RESET_CASE)_seed$(SEED).log

# Xcelium options
XRUN_FLAGS  = -64bit -uvm -sv -access +rwc

# Runtime arguments
RUN_ARGS    = +UVM_TESTNAME=$(TEST) \
              +USB_SPEED=$(USB_SPEED) \
              +USB_FAULT=$(FAULT) \
              +RESET_CASE=$(RESET_CASE) \
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

#===========================================================
# RUN SINGLE UVM TEST WITH PROPER PASS/FAIL CHECK
#===========================================================

run:
	@mkdir -p $(LOG_DIR)
	@echo ""
	@echo "=================================================="
	@echo "       USB PHY UVM SIMULATION"
	@echo "=================================================="
	@echo " Test      : $(TEST)"
	@echo " Speed     : $(USB_SPEED)"
	@echo " Seed      : $(SEED)"
	@echo " Log       : $(LOG_FILE)"
	@echo "=================================================="

	@$(XRUN) $(XRUN_FLAGS) -f $(FILELIST) -top $(TOP) \
		$(RUN_ARGS) -l $(LOG_FILE); \
	XRUN_RC=$$?; \
	if [ $$XRUN_RC -ne 0 ]; then \
		echo "SIMULATION STATUS: FAIL (Xcelium error)"; \
		exit 1; \
	fi; \
	\
	awk -F: '\
	{ \
		gsub(/\033\[[0-9;]*[[:alpha:]]/, "", $$0); \
	} \
	/^[[:space:]]*UVM_ERROR[[:space:]]*:/ { \
		errors=$$2; \
		gsub(/[[:space:]]/, "", errors); \
		seen_error=1; \
	} \
	/^[[:space:]]*UVM_FATAL[[:space:]]*:/ { \
		fatals=$$2; \
		gsub(/[[:space:]]/, "", fatals); \
		seen_fatal=1; \
	} \
	END { \
		if (!seen_error || !seen_fatal) { \
			print "FAIL: UVM report summary missing"; \
			exit 2; \
		} \
		printf "UVM_ERROR = %s\n", errors; \
		printf "UVM_FATAL = %s\n", fatals; \
		if ((errors+0) > 0 || (fatals+0) > 0) { \
			print "SIMULATION STATUS: FAIL"; \
			exit 1; \
		} \
		print "SIMULATION STATUS: PASS"; \
		exit 0; \
	}' $(LOG_FILE); \
	AWK_RC=$$?; \
	if [ $$AWK_RC -ne 0 ]; then \
		echo "Test failed. Check $(LOG_FILE)"; \
		exit 1; \
	fi

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

#-----------------------------------------------------------
# Regression test list
# Format: TEST,SPEED,FAULT,RESET_CASE
#
# USB_SPEED:
# 0 = Low Speed
# 1 = Full Speed
# 2 = High Speed
#-----------------------------------------------------------

#-----------------------------------------------------------
# All UVM tests
#-----------------------------------------------------------

REGRESSION_TESTS = \
	usb_phy_base_test \
	usb_phy_tx_test \
	usb_phy_slave_rx_test \
	usb_phy_slave_turnaround_test \
	usb_phy_full_path_test \
	usb_phy_fault_test \
	usb_phy_speed_switch_test \
	usb_phy_reset_test \
	usb_phy_back_to_back_test \
	usb_phy_underrun_test \
	usb_phy_cdr_test \
	usb_phy_alignment_test

# USB 2.0 speeds
REGRESSION_SPEEDS = 0 1 2


#===========================================================
# FULL REGRESSION: ALL TESTS + ALL SPEEDS + RANDOM SEEDS
#===========================================================


#===========================================================
# FULL REGRESSION - ALL TESTS / ALL SPEEDS / RANDOM SEEDS
#===========================================================

regression:
	@mkdir -p "$(LOG_DIR)"
	@rm -f "$(REGRESSION_SUMMARY)"
	@set -u; \
	PASSED=0; \
	FAILED=0; \
	TOTAL=0; \
	printf "%-36s %-8s %-12s %-10s\n" "TEST NAME" "SPEED" "SEED" "STATUS" > "$(REGRESSION_SUMMARY)"; \
	printf '%s\n' "------------------------------------------------------------------------" >> "$(REGRESSION_SUMMARY)"; \
	echo ""; \
	echo "============================================================"; \
	echo " USB PHY REGRESSION - ALL TESTS / ALL SPEEDS"; \
	echo "============================================================"; \
	for TEST_NAME in $(REGRESSION_TESTS); do \
		for SPEED in $(REGRESSION_SPEEDS); do \
			case $$SPEED in \
				0) SPEED_NAME=LS ;; \
				1) SPEED_NAME=FS ;; \
				2) SPEED_NAME=HS ;; \
			esac; \
			SEED_VALUE=$$(od -An -N4 -tu4 /dev/urandom | tr -d ' '); \
			SEED_VALUE=$$((SEED_VALUE % 2147483646 + 1)); \
			TOTAL=$$((TOTAL + 1)); \
			echo ""; \
			echo "Running: $$TEST_NAME | $$SPEED_NAME | Seed=$$SEED_VALUE"; \
			$(MAKE) --no-print-directory run \
				TEST=$$TEST_NAME \
				USB_SPEED=$$SPEED \
				SEED=$$SEED_VALUE \
				FAULT=1 \
				RESET_CASE=0; \
			RC=$$?; \
			if [ $$RC -eq 0 ]; then \
				PASSED=$$((PASSED + 1)); \
				STATUS=PASS; \
			else \
				FAILED=$$((FAILED + 1)); \
				STATUS=FAIL; \
			fi; \
			printf "%-36s %-8s %-12s %-10s\n" \
				"$$TEST_NAME" "$$SPEED_NAME" "$$SEED_VALUE" "$$STATUS" \
				>> "$(REGRESSION_SUMMARY)"; \
			echo "RESULT: $$TEST_NAME | $$SPEED_NAME | SEED=$$SEED_VALUE | $$STATUS"; \
		done; \
	done; \
	{ \
		echo ""; \
		echo "============================================================"; \
		echo "                 REGRESSION RESULTS"; \
		echo "============================================================"; \
		echo "TOTAL TESTS : $$TOTAL"; \
		echo "PASSED      : $$PASSED"; \
		echo "FAILED      : $$FAILED"; \
		echo ""; \
		if [ $$FAILED -eq 0 ]; then \
			echo "REGRESSION STATUS: PASS"; \
		else \
			echo "REGRESSION STATUS: FAIL"; \
		fi; \
		echo "============================================================"; \
	} >> "$(REGRESSION_SUMMARY)"; \
	echo ""; \
	echo "============================================================"; \
	echo "           COMPLETE REGRESSION REPORT"; \
	echo "============================================================"; \
	cat "$(REGRESSION_SUMMARY)"; \
	echo ""; \
	echo "Summary saved to: $(REGRESSION_SUMMARY)"; \
	if [ $$FAILED -ne 0 ]; then exit 1; fi



#-----------------------------------------------------------
# Optional compile-only target
# - Use this only with the Xcelium elaboration flow.
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
