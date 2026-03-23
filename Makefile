# A2SPEED - Apple II performance test
# Builds 6502 and 65C02 cc65 binaries; optional MegaFlash FPU benchmark.

CC65   = cl65
CA65   = ca65
LD65   = ld65
MEGAFLASH ?= ../MegaFlash
SPF ?= ../spf

# Common sources (no 65C02 opcodes in C; compiler emits 6502 or 65C02 per target)
SRC = main.c bench.c
CFLAGS_6502  = -t apple2 -O -D_A2SPEED_
CFLAGS_65C02 = -t apple2 --cpu 65c02 -O -DA2SPEED_65C02 -D_A2SPEED_

# Optional MegaFlash: add FPU benchmark and link MegaFlash library
ifneq ($(wildcard $(MEGAFLASH)/cc65/megaflash.c),)
  SRC += mf_bench.c
  MFLIB = $(MEGAFLASH)/cc65/megaflash.c
  CFLAGS_6502  += -DA2SPEED_MEGAFLASH -I$(MEGAFLASH)/cc65
  CFLAGS_65C02 += -DA2SPEED_MEGAFLASH -I$(MEGAFLASH)/cc65
endif

# AppleCommander: JAR path for `make disk` (override with AC_JAR=...). Default: macOS user install.
AC_INSTALL := $(HOME)/Library/Application\ Support/AppleCommander/AppleCommander-ac.jar
AC_JAR ?= $(wildcard $(AC_INSTALL))

# ProDOS load address for cc65 apple2 binaries
LOAD_ADDR := 0x803
# SPF-based clock driver for Applesoft ( machine code; GPLv2 — same as SPF gettime.asm )
CLK_ADDR := 0x7000
DISK_IMAGE := a2speed.po
VOL_NAME := A2SPEED

.PHONY: all clean disk applesoft_drv

all: cc65/a2speed_6502.po cc65/a2speed_65c02.po applesoft_drv

applesoft/clockdrv.o: applesoft/clockdrv.s $(SPF)/src/prodos/gettime.asm
	$(CA65) -t none -I $(SPF)/src/prodos -l applesoft/clockdrv.lst applesoft/clockdrv.s -o $@

applesoft/clockdrv.bin: applesoft/clockdrv.o applesoft/clockdrv.cfg
	$(LD65) -C applesoft/clockdrv.cfg $< -m applesoft/clockdrv.map -o $@

applesoft_drv: applesoft/clockdrv.bin

cc65/a2speed_6502.po: $(addprefix cc65/,$(SRC)) cc65/a2speed.h
	$(CC65) $(CFLAGS_6502) -o $@ $(addprefix cc65/,$(SRC)) $(MFLIB)

cc65/a2speed_65c02.po: $(addprefix cc65/,$(SRC)) cc65/a2speed.h
	$(CC65) $(CFLAGS_65C02) -o $@ $(addprefix cc65/,$(SRC)) $(MFLIB)

# Build a ProDOS 140K disk image and add all built files (requires AppleCommander).
# Set AC_JAR to the path of AppleCommander ac.jar, e.g.:
#   make disk AC_JAR=/path/to/AppleCommander-ac.jar
#   make disk AC_JAR=../spf/build/lib/AppleCommander-1.3.5.13-ac.jar
disk: all applesoft_drv
	@if [ -z "$(AC_JAR)" ]; then \
		echo "Set AC_JAR to the path of AppleCommander ac.jar, e.g.:"; \
		echo "  make disk AC_JAR=/path/to/AppleCommander-ac.jar"; \
		exit 1; \
	fi
	@echo "Creating ProDOS image $(DISK_IMAGE)..."
	java -jar "$(AC_JAR)" -pro140 $(DISK_IMAGE) $(VOL_NAME)
	@echo "Adding Applesoft A2SPEED..."
	cat applesoft/A2SPEED.bas | java -jar "$(AC_JAR)" -bas $(DISK_IMAGE) A2SPEED
	@echo "Adding CLOCKDRV (SPF-compatible clock support)..."
	java -jar "$(AC_JAR)" -p $(DISK_IMAGE) CLOCKDRV BIN $(CLK_ADDR) < applesoft/clockdrv.bin
	@echo "Adding A2SPEED_6502..."
	java -jar "$(AC_JAR)" -p $(DISK_IMAGE) A2SPEED_6502 BIN $(LOAD_ADDR) < cc65/a2speed_6502.po
	@echo "Adding A2SPEED_65C02..."
	java -jar "$(AC_JAR)" -p $(DISK_IMAGE) A2SPEED_65C02 BIN $(LOAD_ADDR) < cc65/a2speed_65c02.po
	@echo "Disk image: $(DISK_IMAGE) (volume /$(VOL_NAME)/)"

clean:
	rm -f cc65/a2speed_6502.po cc65/a2speed_65c02.po cc65/*.o $(DISK_IMAGE)
	rm -f applesoft/clockdrv.bin applesoft/clockdrv.o applesoft/clockdrv.map
