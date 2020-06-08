BaseOfLoader	equ	0x9000		;loader.bin被加载的位置---段地址
OffsetLoader	equ	0x0100		;loader.bin被加载的位置---偏移地址

BaseOfLoaderPhyAddr	equ	BaseOfLoader * 10h	; LOADER.BIN 被加载到的位置 ---- 物理地址 (= BaseOfLoader * 10h)

BaseOfKernel    equ     0x8000          ;kernel.bin被加载的位置---段地址
OffsetKernel    equ     0               ;kernel.bin被加载的位置---偏移地址


BaseOfKernelPhyAddr	equ	BaseOfKernel * 10h
KernelEntryPointPhyAddr	equ	030400h	; 注意：1、必须与 MAKEFILE 中参数 -Ttext 的值相等!!
					;       2、这是个地址而非仅仅是个偏移，如果 -Ttext 的值为 0x400400，则它的值也应该是 0x400400。




PDTBaseAdd	equ	100000h			;页目录表基地址
PTBaseAdd	equ	101000h			;页表基地址
