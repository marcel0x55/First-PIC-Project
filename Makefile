SRC       := $(wildcard *.asm)
TARGET    := $(basename $(notdir $(firstword $(SRC))))
BUILD_DIR := build

GPASM     := gpasm -a inhx32
PK2CMD    := pk2cmd -B/usr/share/pk2/

ifdef MCU
    MCU_FLAG := -P$(MCU)
else
    MCU_FLAG := -P
endif

.PHONY: all assemble flash power poweroff clean check-src

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
	$(error ERROR: VDD voltage not specified! Run 'make power VDD=3.3' or 'make power VDD=5.0')
endif
	@echo "==> Supplying $(VDD)V target VDD via PICkit 3..."
	$(PK2CMD) $(MCU_FLAG) -A$(VDD) -T -R

poweroff:
	@echo "==> Cutting PICkit 3 target VDD power..."
	$(PK2CMD) $(MCU_FLAG)

clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
