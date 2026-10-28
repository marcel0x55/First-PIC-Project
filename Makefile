-include src/config.mk

SRC       := $(wildcard src/*.asm)
TARGET    := $(basename $(notdir $(firstword $(SRC))))
BUILD_DIR := build

GPASM     := gpasm -a inhx32
PK2CMD    := pk2cmd -B/usr/share/pk2/

# Handle MCU Selection (AUTODETECT or unset results in -P)
ifeq ($(MCU),AUTODETECT)
    MCU_FLAG := -P
else ifdef MCU
    MCU_FLAG := -P$(MCU)
else
    MCU_FLAG := -P
endif

.PHONY: all assemble flash power poweroff clean check-src menuconfig

all: assemble

check-src:
ifeq ($(SRC),)
	$(error No .asm source file found in src/ directory)
endif

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

assemble: check-src | $(BUILD_DIR)
	@echo "==> Assembling $(firstword $(SRC)) into $(BUILD_DIR)/..."
	$(GPASM) $(firstword $(SRC)) -o $(BUILD_DIR)/$(TARGET).hex

flash: assemble
	@echo "==> Flashing $(BUILD_DIR)/$(TARGET).hex..."
	$(PK2CMD) $(MCU_FLAG) -F $(BUILD_DIR)/$(TARGET).hex -M -R

power:
ifndef VDD
	$(error ERROR: VDD voltage not specified! Run 'make menuconfig' or 'make power VDD=5.0')
endif
	@echo "==> Supplying $(VDD)V target VDD via PICkit..."
	$(PK2CMD) $(MCU_FLAG) -A$(VDD) -T -R

poweroff:
	@echo "==> Cutting PICkit target VDD power..."
	$(PK2CMD) $(MCU_FLAG)

clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)

menuconfig:
	@# 1. Parse MCU Part ($1) and fold all details ($2..$NF) into a single description
	@PARSED_LIST=$$($(PK2CMD) -?P 2>/dev/null | grep -E '^(PIC|dsPIC)' | awk '{ \
		part = $$1; \
		devid = $$NF; \
		details = ""; \
		for (i = 2; i < NF; i++) { \
			details = (details == "" ? "" : details "_") $$i; \
		} \
		print part, (details == "" ? "" : details "_") "(ID:" devid ")"; \
	}'); \
	if [ -n "$$PARSED_LIST" ]; then \
		MENU_ITEMS="AUTODETECT Auto-detect_Target SEARCH Search_Device_List $$PARSED_LIST"; \
	else \
		MCUS="PIC16F690 PIC16F688 PIC16F684 PIC16F887 PIC18F2550 PIC18F4550"; \
		MENU_ITEMS="AUTODETECT Auto-detect_Target SEARCH Search_Device_List"; \
		for mcu in $$MCUS; do MENU_ITEMS="$$MENU_ITEMS $$mcu -"; done; \
	fi; \
	\
	PROMPT="Select Target MCU:\n\n  MCU PART           FAMILY / ALIAS & DEVICE ID\n  --------------------------------------------------"; \
	MAIN_LOOP=1; \
	while [ $$MAIN_LOOP -eq 1 ]; do \
		SELECTED_MCU=$$(whiptail --title "PIC Target Selection" --menu "$$PROMPT" 22 78 12 $$MENU_ITEMS 3>&1 1>&2 2>&3); \
		if [ -z "$$SELECTED_MCU" ]; then echo "Configuration canceled."; exit 1; fi; \
		\
		if [ "$$SELECTED_MCU" = "SEARCH" ]; then \
			SEARCH_TERM=$$(whiptail --title "Search MCU" --inputbox "Enter part name or family to search (e.g., PIC16F6):" 10 60 3>&1 1>&2 2>&3); \
			if [ -z "$$SEARCH_TERM" ]; then continue; fi; \
			SEARCH_RESULTS=$$(echo "$$PARSED_LIST" | grep -i "$$SEARCH_TERM"); \
			if [ -z "$$SEARCH_RESULTS" ]; then \
				whiptail --title "No Results" --msgbox "No devices found matching '$$SEARCH_TERM'." 10 60 3>&1 1>&2 2>&3; \
				continue; \
			fi; \
			SEARCH_SELECTED=$$(whiptail --title "Search Results" --menu "Matches for '$$SEARCH_TERM':" 22 78 12 SEARCH_AGAIN New_Search $$SEARCH_RESULTS 3>&1 1>&2 2>&3); \
			if [ -z "$$SEARCH_SELECTED" ]; then continue; fi; \
			if [ "$$SEARCH_SELECTED" = "SEARCH_AGAIN" ]; then \
				# Selecting SEARCH_AGAIN cancels out of this if-block and restarts the while loop, \
				# but we want to go straight back to the search prompt, so we inject a pseudo-flag \
				SELECTED_MCU="SEARCH"; \
				continue; \
			fi; \
			SELECTED_MCU="$$SEARCH_SELECTED"; \
		fi; \
		MAIN_LOOP=0; \
	done; \
	\
	# 2. VDD Voltage Selection Menu \
	VDD_MENU="UNSET Target_Self-Powered_(Safe) 5.0 5.0V_Power_Supply 3.3 3.3V_Power_Supply 2.5 2.5V_Power_Supply CUSTOM Enter_Arbitrary_Voltage"; \
	SELECTED_VDD_CHOICE=$$(whiptail --title "Target VDD Supply" --menu "Select VDD Voltage:" 16 65 6 $$VDD_MENU 3>&1 1>&2 2>&3); \
	if [ -z "$$SELECTED_VDD_CHOICE" ]; then echo "Configuration canceled."; exit 1; fi; \
	\
	if [ "$$SELECTED_VDD_CHOICE" = "UNSET" ]; then \
		FINAL_VDD=""; \
	elif [ "$$SELECTED_VDD_CHOICE" = "CUSTOM" ]; then \
		FINAL_VDD=$$(whiptail --title "Custom VDD Voltage" --inputbox "Enter voltage between 1.8V and 5.0V (e.g. 4.2):" 10 60 "$(VDD)" 3>&1 1>&2 2>&3); \
	else \
		FINAL_VDD="$$SELECTED_VDD_CHOICE"; \
	fi; \
	\
	# 3. Save to src/config.mk \
	mkdir -p src; \
	echo "MCU = $$SELECTED_MCU" > src/config.mk; \
	if [ -n "$$FINAL_VDD" ]; then \
		echo "VDD = $$FINAL_VDD" >> src/config.mk; \
	fi; \
	echo "==> Saved configuration to src/config.mk:"; \
	cat src/config.mk
