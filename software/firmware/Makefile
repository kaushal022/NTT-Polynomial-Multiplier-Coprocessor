TOOLCHAIN_PREFIX ?= riscv-none-elf-
ifeq ($(shell which $(TOOLCHAIN_PREFIX)gcc 2>/dev/null),)
TOOLCHAIN_PREFIX := riscv32-unknown-elf-
endif

CC      = $(TOOLCHAIN_PREFIX)gcc
OBJCOPY = $(TOOLCHAIN_PREFIX)objcopy
OBJDUMP = $(TOOLCHAIN_PREFIX)objdump
SIZE    = $(TOOLCHAIN_PREFIX)size
PYTHON  = python

CFLAGS  = -march=rv32i -mabi=ilp32 -O2 -nostdlib -Wall -Wextra
LDFLAGS = -T firmware.lds

TARGET  = firmware
SRCS    = firmware_start.s firmware.c

all: $(TARGET).hex $(TARGET).bin

hybrid: ../../rtl/soc/firmware_hybrid.hex

firmware_hybrid.elf: firmware_start.s firmware_hybrid.c firmware.lds
	$(CC) $(CFLAGS) -Werror $(LDFLAGS) -o $@ firmware_start.s firmware_hybrid.c
	$(SIZE) $@

firmware_hybrid.bin: firmware_hybrid.elf
	$(OBJCOPY) -O binary $< $@

../../rtl/soc/firmware_hybrid.hex: firmware_hybrid.bin
	$(PYTHON) -c 'with open("$<", "rb") as f: d = f.read(); words = [d[i:i+4] for i in range(0, len(d), 4)]; [print("{:02x}{:02x}{:02x}{:02x}".format(w[3], w[2], w[1], w[0])) for w in words]; [print("00000000") for _ in range(8192 - len(words))]' > $@

$(TARGET).elf: $(SRCS) firmware.lds
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)
	$(SIZE) $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).c firmware.lds firmware_start.s
	$(PYTHON) ../../scripts/gen_firmware.py

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(TARGET).hex firmware_hybrid.elf firmware_hybrid.bin

.PHONY: all hybrid clean
