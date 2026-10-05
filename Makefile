-include config.mk

SRC       := $(wildcard *.asm)
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
	$(error No .asm source file found in current directory)
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
		MENU_ITEMS="AUTODETECT Auto-detect_Target MANUAL_ENTRY Manual_Input_/_Search $$PARSED_LIST"; \
	else \
		MCUS="PIC16F690 PIC16F688 PIC16F684 PIC16F887 PIC18F2550 PIC18F4550"; \
		MENU_ITEMS="AUTODETECT Auto-detect_Target MANUAL_ENTRY Manual_Input_/_Search"; \
		for mcu in $$MCUS; do MENU_ITEMS="$$MENU_ITEMS $$mcu -"; done; \
	fi; \
	\
	PROMPT="Select Target MCU:\n\n  MCU PART           FAMILY / ALIAS & DEVICE ID\n  --------------------------------------------------"; \
	SELECTED_MCU=$$(whiptail --title "PIC Target Selection" --menu "$$PROMPT" 22 78 12 $$MENU_ITEMS 3>&1 1>&2 2>&3); \
	if [ -z "$$SELECTED_MCU" ]; then echo "Configuration canceled."; exit 1; fi; \
	\
	# If manual entry chosen, prompt with input box & validate against device list \
	if [ "$$SELECTED_MCU" = "MANUAL_ENTRY" ]; then \
		MANUAL_MCU=$$(whiptail --title "Manual MCU Entry" --inputbox "Enter PIC MCU name (e.g., PIC16F690):" 10 60 3>&1 1>&2 2>&3); \
		if [ -z "$$MANUAL_MCU" ]; then echo "Configuration canceled."; exit 1; fi; \
		MATCH=$$(echo "$$PARSED_LIST" | grep -i -w "$$MANUAL_MCU" | awk '{print $$1}' | head -n 1); \
		if [ -n "$$MATCH" ]; then \
			SELECTED_MCU="$$MATCH"; \
		else \
			whiptail --title "MCU Not Recognized" --yesno "'$$MANUAL_MCU' was not found in PK2DeviceFile.dat.\n\nDo you want to continue anyway?" 12 65 3>&1 1>&2 2>&3; \
			if [ $$? -ne 0 ]; then echo "Configuration canceled."; exit 1; fi; \
			SELECTED_MCU="$$MANUAL_MCU"; \
		fi; \
	fi; \
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
	# 3. Save to config.mk \
	echo "MCU = $$SELECTED_MCU" > config.mk; \
	if [ -n "$$FINAL_VDD" ]; then \
		echo "VDD = $$FINAL_VDD" >> config.mk; \
	fi; \
	echo "==> Saved configuration to config.mk:"; \
	cat config.mk
