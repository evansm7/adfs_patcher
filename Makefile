
ACC = arm-none-eabi-gcc
AOC = arm-none-eabi-objcopy
ACFLAGS = -mcpu=arm7tdmi -ffreestanding -Wl,--gc-sections -nostdlib -Wl,-Ttext=0

all:	patch_adfs_mod

patch_adfs_mod.elf:	patch_adfs_mod.S
	$(ACC) $(ACFLAGS) $< -o $@

patch_adfs_mod:	patch_adfs_mod.elf
	$(AOC) -O binary $< $@

clean:
	rm -f patch_adfs_mod patch_adfs_mod.elf *~
