#Makefile for boot

#Programs,flags.
ASM		= nasm
ASMFLAGS	= -I include/


#This program
TARGET		= boot.bin loader.bin

#All phony targets
.PHONY : everything clean all

#Default starting position
everything : $(TARGET)

clean :	
	rm -f $(TARGET)

all : clean everything

boot.bin : boot.asm include/load.inc include/fat12hdr.inc
	$(ASM) $(ASMFLAGS) $< -o $@

loader.bin : loader.asm include/load.inc include/fat12hdr.inc include/pm.inc
	$(ASM) $(ASMFLAGS) $< -o $@


