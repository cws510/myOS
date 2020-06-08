#Makefile for Kernel

#Programs,flags.
ASM		= nasm
CC		= gcc
LD		= ld
ASMFLAGS1	= -I boot/include/
ASMFLAGS2	= -I include/ -f elf
CCFLAGS		= -I include/ -m32 -c -fno-builtin -fno-stack-protector
LDFLAGS		= -m elf_i386 -s -Ttext 0x30400

#This program
BOOT		= boot/boot.bin boot/loader.bin
KERNEL		= kernel/kernel.bin
OBJS		= kernel/kernel.o kernel/start.o lib/string.o lib/kliba.o kernel/i8259.o kernel/global.o kernel/protect.o lib/klib.o kernel/main.o


#All phony targets
.PHONY : image everything clean build

#Default starting position
image : everything build

everything : $(BOOT) $(KERNEL)

build:
	dd if=boot/boot.bin of=a.img bs=512 count=1 conv=notrunc
	sudo mount a.img /mnt/floppy/
	sudo cp boot/loader.bin /mnt/floppy/
	sudo cp kernel/kernel.bin /mnt/floppy/
	sudo umount /mnt/floppy/

clean:
	rm $(BOOT) $(KERNEL) $(OBJS)

boot/boot.bin : boot/boot.asm boot/include/load.inc boot/include/fat12hdr.inc
	$(ASM) $(ASMFLAGS1) $< -o $@

boot/loader.bin : boot/loader.asm boot/include/load.inc boot/include/fat12hdr.inc boot/include/pm.inc
	$(ASM) $(ASMFLAGS1) $< -o $@

kernel/kernel.bin : $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) -o $@

kernel/kernel.o : kernel/kernel.asm include/sconst.inc
	$(ASM) $(ASMFLAGS2) $< -o $@

kernel/start.o : kernel/start.c include/type.h include/protect.h include/const.h include/string.h include/proto.h
	$(CC) $(CCFLAGS) $< -o $@

kernel/i8259.o : kernel/i8259.c include/type.h include/proto.h include/const.h include/protect.h
	$(CC) $(CCFLAGS) $< -o $@

kernel/global.o : kernel/global.c include/type.h include/const.h include/protect.h include/proto.h include/global.h
	$(CC) $(CCFLAGS) $< -o $@


kernel/protect.o : kernel/protect.c include/type.h include/protect.h include/const.h include/global.h 
	$(CC) $(CCFLAGS) $< -o $@

lib/string.o : lib/string.asm
	$(ASM) $(ASMFLAGS2) $< -o $@

lib/kliba.o : lib/kliba.asm
	$(ASM) $(ASMFLAGS2) $< -o $@

lib/klib.o : lib/klib.c include/proto.h
	$(CC) $(CCFLAGS) $< -o $@

kernel/main.o : kernel/main.c include/proto.h
	$(CC) $(CCFLAGS) $< -o $@
