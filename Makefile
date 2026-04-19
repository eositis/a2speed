# A2SPEED - Apple II performance test
# Builds 6502 and 65C02 cc65 binaries; optional MegaFlash FPU benchmark.
#
# Prefer Apple Silicon Homebrew cc65 when present so Intel-only /usr/local/bin tools
# do not shadow arm64 binaries (avoids "Bad CPU type in executable" on arm64 Macs).

ifneq ($(wildcard /opt/homebrew/bin/cl65),)
CC65 := /opt/homebrew/bin/cl65
CA65 := /opt/homebrew/bin/ca65
LD65 := /opt/homebrew/bin/ld65
else
CC65 := cl65
CA65 := ca65
LD65 := ld65
endif

# AppleCommander needs Java. On Apple Silicon, Intel Homebrew `java` often fails with
# "Bad CPU type"; prefer Homebrew arm64 OpenJDK when installed (`brew install openjdk`).
# Override if needed: make disk JAVA=/path/to/java
ifneq ($(wildcard /opt/homebrew/opt/openjdk/bin/java),)
JAVA := /opt/homebrew/opt/openjdk/bin/java
else
JAVA := java
endif

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
BENCHML_ADDR := 0x6000
DISK_IMAGE := a2speed.po
VOL_NAME := A2SPEED
PRODOS_SYS ?= prodos/PRODOS
BASIC_SYSTEM ?= prodos/BASIC.SYSTEM
PRODOS_IMAGE ?= prodos/ProDOS_2_4_3.po

.PHONY: all clean disk applesoft_drv bump-release prodos_sysfiles

all: cc65/a2speed_6502.po cc65/a2speed_65c02.po applesoft_drv applesoft/benchml.bin

applesoft/a2benchml.o: applesoft/a2benchml.s
	$(CA65) -t none -l applesoft/benchml.lst $< -o $@

applesoft/benchml.bin: applesoft/a2benchml.o applesoft/benchml.cfg
	$(LD65) -C applesoft/benchml.cfg $< -m applesoft/benchml.map -o $@

applesoft/clockdrv.o: applesoft/clockdrv.s $(SPF)/src/prodos/gettime.asm
	$(CA65) -t none -I $(SPF)/src/prodos -l applesoft/clockdrv.lst applesoft/clockdrv.s -o $@

applesoft/clockdrv.bin: applesoft/clockdrv.o applesoft/clockdrv.cfg
	$(LD65) -C applesoft/clockdrv.cfg $< -m applesoft/clockdrv.map -o $@

applesoft_drv: applesoft/clockdrv.bin

cc65/a2speed_6502.po: $(addprefix cc65/,$(SRC)) cc65/a2speed.h
	$(CC65) $(CFLAGS_6502) -o $@ $(addprefix cc65/,$(SRC)) $(MFLIB)

cc65/a2speed_65c02.po: $(addprefix cc65/,$(SRC)) cc65/a2speed.h
	$(CC65) $(CFLAGS_65C02) -o $@ $(addprefix cc65/,$(SRC)) $(MFLIB)

# Build a bootable ProDOS 140K disk image and add all built files (requires AppleCommander).
# Set AC_JAR to the path of AppleCommander ac.jar, e.g.:
#   make disk AC_JAR=/path/to/AppleCommander-ac.jar
#   make disk AC_JAR=../spf/build/lib/AppleCommander-1.3.5.13-ac.jar
# Provide ProDOS system files (required for boot), e.g.:
#   make disk PRODOS_SYS=/path/to/PRODOS BASIC_SYSTEM=/path/to/BASIC.SYSTEM
# Defaults expect these in repo at prodos/PRODOS and prodos/BASIC.SYSTEM.
# If those files are missing and PRODOS_IMAGE exists, make will auto-extract
# PRODOS and BASIC.SYSTEM from PRODOS_IMAGE using AppleCommander.
# Bump build number and refresh metadata (version unchanged). Set SKIP_BUMP=1 to skip when iterating on the disk image.
bump-release:
	bash scripts/apply-release-metadata.sh

prodos_sysfiles:
	@if [ -z "$(AC_JAR)" ]; then \
		echo "Set AC_JAR to the path of AppleCommander ac.jar, e.g.:"; \
		echo "  make disk AC_JAR=/path/to/AppleCommander-ac.jar"; \
		exit 1; \
	fi
	@if [ -f "$(PRODOS_SYS)" ] && [ -f "$(BASIC_SYSTEM)" ]; then \
		echo "Using existing system files: $(PRODOS_SYS), $(BASIC_SYSTEM)"; \
	elif [ -f "$(PRODOS_IMAGE)" ]; then \
		echo "Extracting PRODOS and BASIC.SYSTEM from $(PRODOS_IMAGE)..."; \
		mkdir -p "$(dir $(PRODOS_SYS))" "$(dir $(BASIC_SYSTEM))"; \
		$(JAVA) -jar "$(AC_JAR)" -g "$(PRODOS_IMAGE)" PRODOS "$(PRODOS_SYS)"; \
		$(JAVA) -jar "$(AC_JAR)" -g "$(PRODOS_IMAGE)" BASIC.SYSTEM "$(BASIC_SYSTEM)"; \
	else \
		echo "Missing system files and source image."; \
		echo "Provide either:"; \
		echo "  1) PRODOS_SYS and BASIC_SYSTEM files, or"; \
		echo "  2) PRODOS_IMAGE containing both files (default: $(PRODOS_IMAGE))"; \
		exit 1; \
	fi

disk: applesoft_drv applesoft/benchml.bin prodos_sysfiles
	@if [ -z "$(AC_JAR)" ]; then \
		echo "Set AC_JAR to the path of AppleCommander ac.jar, e.g.:"; \
		echo "  make disk AC_JAR=/path/to/AppleCommander-ac.jar"; \
		exit 1; \
	fi
	@if [ -z "$(SKIP_BUMP)" ]; then \
		bash scripts/apply-release-metadata.sh; \
	fi
	@echo "Cloning base ProDOS boot image to $(DISK_IMAGE)..."
	cp "$(PRODOS_IMAGE)" "$(DISK_IMAGE)"
	@echo "Renaming volume to $(VOL_NAME)..."
	$(JAVA) -jar "$(AC_JAR)" -n "$(DISK_IMAGE)" "$(VOL_NAME)"
	@echo "Removing bundled utilities to free space..."
	@for f in VIEW.README BITSY.BOOT QUIT.SYSTEM COPYIIPLUS.8.4 BLOCKWARDEN CAT.DOCTOR UNSHRINK CD.EXT FASTDSK FASTDSK.CONF FASTDSK.SYSTEM MAKE.SMALL.P8 MINIBAS MR.FIXIT.Y2K README; do \
		$(JAVA) -jar "$(AC_JAR)" -d "$(DISK_IMAGE)" "$$f" || true; \
	done
	@echo "Refreshing PRODOS..."
	$(JAVA) -jar "$(AC_JAR)" -d "$(DISK_IMAGE)" PRODOS || true
	$(JAVA) -jar "$(AC_JAR)" -p "$(DISK_IMAGE)" PRODOS SYS < "$(PRODOS_SYS)"
	@echo "Refreshing BASIC.SYSTEM..."
	$(JAVA) -jar "$(AC_JAR)" -d "$(DISK_IMAGE)" BASIC.SYSTEM || true
	$(JAVA) -jar "$(AC_JAR)" -p "$(DISK_IMAGE)" BASIC.SYSTEM SYS < "$(BASIC_SYSTEM)"
	@echo "Adding STARTUP launcher (ProDOS autostart)..."
	$(JAVA) -jar "$(AC_JAR)" -d "$(DISK_IMAGE)" STARTUP || true
	cat applesoft/STARTUP.bas | $(JAVA) -jar "$(AC_JAR)" -bas $(DISK_IMAGE) STARTUP
	@echo "Adding HELLO launcher (manual fallback)..."
	$(JAVA) -jar "$(AC_JAR)" -d "$(DISK_IMAGE)" HELLO || true
	cat applesoft/HELLO.bas | $(JAVA) -jar "$(AC_JAR)" -bas $(DISK_IMAGE) HELLO
	@echo "Adding Applesoft A2SPEED..."
	$(JAVA) -jar "$(AC_JAR)" -d "$(DISK_IMAGE)" A2SPEED || true
	cat applesoft/A2SPEED.bas | $(JAVA) -jar "$(AC_JAR)" -bas $(DISK_IMAGE) A2SPEED
	@echo "Adding README.TXT..."
	$(JAVA) -jar "$(AC_JAR)" -d "$(DISK_IMAGE)" README.TXT || true
	$(JAVA) -jar "$(AC_JAR)" -ptx $(DISK_IMAGE) README.TXT < applesoft/README.TXT
	@echo "Adding BENCHML (ML benchmark; A2SPEED CALL)..."
	$(JAVA) -jar "$(AC_JAR)" -d "$(DISK_IMAGE)" BENCHML || true
	$(JAVA) -jar "$(AC_JAR)" -p $(DISK_IMAGE) BENCHML BIN $(BENCHML_ADDR) < applesoft/benchml.bin
	@echo "Adding CLOCKDRV (SPF-compatible clock support)..."
	$(JAVA) -jar "$(AC_JAR)" -d "$(DISK_IMAGE)" CLOCKDRV || true
	$(JAVA) -jar "$(AC_JAR)" -p $(DISK_IMAGE) CLOCKDRV BIN $(CLK_ADDR) < applesoft/clockdrv.bin
	@echo "Disk image: $(DISK_IMAGE) (volume /$(VOL_NAME)/, bootable with BASIC.SYSTEM)"

clean:
	rm -f cc65/a2speed_6502.po cc65/a2speed_65c02.po cc65/*.o $(DISK_IMAGE)
	rm -f applesoft/clockdrv.bin applesoft/clockdrv.o applesoft/clockdrv.map
	rm -f applesoft/benchml.bin applesoft/a2benchml.o applesoft/benchml.map applesoft/benchml.lst
