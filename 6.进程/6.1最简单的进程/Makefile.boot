#Makefile for boot

#Programs,flags.
ASM		= nasm
ASMFLAGS	= -I boot/include/


#This program
TARGET		= boot/boot.bin boot/loader.bin

#All phony targets
.PHONY : everything clean all

#Default starting position
everything : $(TARGET)

clean :	
	rm -f $(TARGET)

all : clean everything

boot/boot.bin : boot/boot.asm boot/include/load.inc boot/include/fat12hdr.inc
	$(ASM) $(ASMFLAGS) $< -o $@

boot/loader.bin : boot/loader.asm boot/include/load.inc boot/include/fat12hdr.inc boot/include/pm.inc
	$(ASM) $(ASMFLAGS) $< -o $@


