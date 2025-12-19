NASM = nasm
QEMU = qemu-system-x86_64

all: flowos.img

boot.bin: boot.asm
	$(NASM) -f bin boot.asm -o boot.bin

kernel.bin: kernel.asm
	$(NASM) -f bin kernel.asm -o kernel.bin

flowos.bin: boot.bin kernel.bin
	cat boot.bin kernel.bin > flowos.bin

flowos.img: flowos.bin
	dd if=/dev/zero of=flowos.img bs=1M count=64
	dd if=flowos.bin of=flowos.img conv=notrunc
	rm -f boot.bin kernel.bin flowos.bin

run: flowos.img
	$(QEMU) -fda flowos.img -boot a -m 512M

clean:
	rm -f *.bin *.img

.PHONY: all run clean