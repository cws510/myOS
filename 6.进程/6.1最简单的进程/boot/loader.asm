
;进入保护模式步骤：
;1.准备GDT
;2.用lgdt加载gdtr
;3.打开A20
;4.置cr0的PE位
;5.跳转，进入保护模式
	
	org	0x0100
	jmp	CodeStart16

;下面是FAT12磁盘的头
%include "fat12hdr.inc"
%include "pm.inc"
%include "load.inc"


;----------------------------------------------------------------------------
;				段基址		段界限		属性
LABEL_GDT:	 Descriptor	0h,		0h,		0h     ;空描述符
LABEL_DES_CODE32:Descriptor	0h,		0fffffh,	DA_CR|DA_32|DA_LIMIT_4K		;只读32位代码段0~4G
LABEL_DES_DATA:	 Descriptor	0h,		0fffffh,	DA_DRW|DA_32|DA_LIMIT_4K		;可读写32位数据段0~4G 
LABEL_DES_VIDEO: Descriptor	0B8000h,	0ffffh,		DA_DRW | DA_DPL3 ;显存首地址


GDTLen	equ	$-LABEL_GDT
GDTR	dw	GDTLen-1
	dd	BaseOfLoader*10h + LABEL_GDT		;GDT被加载的基地址

;选择子
SEC_CODE32	equ	LABEL_DES_CODE32-LABEL_GDT
SEC_DATA	equ	LABEL_DES_DATA-LABEL_GDT
SEC_VIDEO	equ	LABEL_DES_VIDEO-LABEL_GDT

;----------------------------------------------------------------------------



;----------------------------------------------------------------------------
BaseOfStack	equ	0x0100		;堆栈基地址(栈底,从这个位置向低地址生长)	

KernelFileName	db	"KERNEL  BIN"	;loader文件名
Message1	db	"Loading  "
Message2	db	"Ready    "
DHNumber	db	3
MessageLength	equ	9
;----------------------------------------------------------------------------



;----------------------------------------------------------------------------
[section .code16]
[bits 16]
CodeStart16:				
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, BaseOfStack

	;调用int 15h中断
	;将内存信息放入MemoryBuffer内存缓冲区中
	mov	ebx, 0
	mov	di, _MemoryBuffer
.14:
	mov	eax, 0E820h
	mov	ecx, 20
	mov	edx, 0534D4150h
	int	15h
	jc	.13
	inc	dword [_ARDSNumber]
	add	edi, 20
	cmp	ebx, 0
	jnz	.14
.13:

	;打印字符串"Loading"
	mov	bp, Message1
	call	DisStrRealMode

	;寻找Kernel.bin
	call	FindKernel	;调用完函数 ax中保存着开始簇号
.8:	
	push	ax		;之后GetFATEntry函数中要用到开始簇号,所以压栈保存

	add	ax, 14+19-2	;簇号和实际扇区相差(14+19-2)=31
	call	ReadSector	;读取软盘扇区,将软盘一个扇区内容放入es:bx所在的内存中
	add	bx, 0x200

	push	ax		; \
	
	push	bx		; |	
	mov	ah, 0Eh		; |  AH=0EH 电传打字机输出
	mov	al, '.'		; |  每读取一个扇区就在"Booting"后面打印一个点
	mov	bl, 0Fh		; |
	int 	10h		; |	
	pop	bx		; |
	pop	ax		;/

	pop	ax		;出栈,此时ax中为开始簇号
	;找到指定扇区号对应的FAT项的值
	call	GetFATEntry
	cmp	ax, 0x0FF8
	jb	.8		;如果小于0xFF8,接着读取下一个扇区		
				;如果下一个簇号>=0xFF8,表示这个簇已经是最后一个
	;关闭软驱马达
	call	KillMotor

	;打印字符串"Ready"
	mov	bp, Message2
	call	DisStrRealMode

	;----------------------------------------------------------------
	;下面进入保护模式
	;----------------------------------------------------------------

	;加载GDTR
	lgdt 	[GDTR]

	;关中断
	cli

	;打开A20
	in 	al, 92h
	or 	al, 00000010b
	out 	92h, al

	;置cr0的PE位
	mov 	eax, cr0
	or 	eax, 01h
	mov 	cr0, eax

	;跳转，进入保护模式
	jmp	dword SEC_CODE32:(BaseOfLoader*10h+CodeStart32)

;----------------------------------------------------------------------------


;---------------------------------------------------------------------------
;寻找kernel.bin
;---------------------------------------------------------------------------
FindKernel:
	;软驱复位
	xor	ah, ah
	xor	dl, dl
	int	13h

	mov	ax, BaseOfKernel
	mov	es, ax			;kernel加载段地址
	mov	bx, OffsetKernel	;kernel加载偏移地址
	xor	ecx, ecx
	mov	cx, RootDirSectors	;根目录占用扇区数14
	mov	ax, RootDirFirSecNum	;根目录第一个扇区号19
.1:	;此循环读取根目录的所有扇区

	push	cx			;之前有用到cx,所以此时使用要压栈
	
	;读取软盘扇区,将软盘一个扇区内容放入es:bx所在的内存中
	call	ReadSector

	mov	cx, 11			;kernel文件名的长度
	mov	di, 0			;di指向es:bx内存内容
	mov	si, KernelFileName	;si指向kernel文件名字
.3:
	mov	dl, [es:(bx+di)]
	cmp	dl, [si]		;判断指向的字符是否相同
	jz	.2
	mov	cx, 11			;字符只要有一个不同就将cx的值重新置为11
	inc	di
	cmp	di, 512
	jz	.5
	mov	si, KernelFileName
	jmp	.3
.2:
	dec	cx			;字符相同cx减一
	cmp	cx, 0			;如果cx=0说明11个字符完全相同,找到kernel
	jz	.4
	inc	si
	inc	di
	cmp	di, 512
	jz	.5
	jmp	.3

.5:				;跳转到.5说明此扇区寻找失败,接着寻找下一个扇区
	pop	cx
	inc	ax		;读取下一个扇区


	loop	.1
	
	ret
.4:				;跳转到.4说明寻找成功
	pop	cx

				;寻找成功此时di指向文件名的最后一个字符
	add	di, 16		;di+16使di指向DIR_FstClus(kernel文件内容对应的开始簇号)
	mov	ax, [es:(bx+di)];将开始簇号保存到ax寄存器中

	ret
;----------------------------------------------------------------------------



;----------------------------------------------------------------------------
;读取软盘扇区
;输入为ax(扇区号)
;----------------------------------------------------------------------------
ReadSector:

	push	ax
	push	cx
	push	bx
	;假设ax中存放的是扇区号
	mov	bl, [BPB_SecPerTrk]	;bl:除数 值为18
	div	bl			;商在al,余数在ah
	inc	ah
	mov	cl, ah			;cl:起始扇区号=余数+1
	mov	ah, al			;此时ah, al中存放的都是商
	shr	al, 1
	mov	ch, al			;ch:磁道号=商>>1
	and	ah, 00000001B
	mov	dh, ah			;dh:磁头号=商&1
	mov	dl, [BS_DrvNum]		;dl:驱动器号(0表示A盘) 值为0

	mov	ah, 02h
	mov	al, 01h			;al:要读扇区数
	
	pop	bx		;bx涉及地址应在int中断前弹出
	;int 13h中断:从磁盘将数据读入es:bx指向的缓冲区
GoOnReading:
	int 	13h	
	jc	GoOnReading	;如果读取错误,CF会被置为1;重新读取

	pop	cx
	pop	ax

	ret
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
;找到指定扇区号对应的FAT项的值
;输入为ax(簇号)
;----------------------------------------------------------------------------
GetFATEntry:
	mov	cx, ax		;将ax中的簇号保存到cx中
	mov	ax, 1
	call	ReadSector	;读软盘1号扇区
	mov	di, 0		;di指向读取FAT第一个扇区的首字节
	mov	ax, cx
	mov	dl, 2
	div	dl
	cmp	ah, 0		;判断ax中的簇号是奇数还是偶数
	jz	.6
	;奇数的情况
	mov	dl, 3
	mul	dl		;al*3是目标FAT项首字节的偏移量
	mov	di, ax
	mov	eax, [es:(bx+di)]	;取出四个字节
	shr	eax, 12
	and	eax, 00000FFFh		;右移12位,高20位清零
	jmp	.7

.6:	;偶数的情况
	mov	dl, 3
	mul	dl
	mov	di, ax
	mov	eax, [es:(bx+di)]	;取出四个字节
	and	eax, 00000FFFh		;高20位清零	
.7:
	
	ret
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
;打印字符串
;输入为bp(字符串位置)
;----------------------------------------------------------------------------
DisStrRealMode:
	push	es		;因为此函数修改了es的值,所以将es压栈
	push	bx

	mov	cx, MessageLength	;串长度
	mov	ax, cs
	mov	es, ax			;es:bp=串地址
	mov	ax, 0x1301
	mov	bx, 0x000c
	mov	dh, [DHNumber]		;DH.DL=坐标(行.列)		
	mov	dl, 0
	int 	10h

	inc	byte [DHNumber]

	pop	bx
	pop	es
	ret
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
;关闭软驱马达
;----------------------------------------------------------------------------
KillMotor:
	mov	dx, 0x03F2
	mov	al, 0
	out	dx, al

	ret
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
;从此以后的代码在保护模式下执行 
;----------------------------------------------------------------------------
[section .32]
[bits 32]
CodeStart32:
	;初始化显存描述符
	mov	ax, SEC_VIDEO
	mov	gs, ax

	;初始化数据段描述符
	mov	ax, SEC_DATA
	mov	ds, ax
	;初始化es,fs,ss
	mov	es, ax
	mov	fs, ax
	mov	ss, ax
	mov	esp, TopOfStack

	mov	ah, 0x04
	mov	al, 'S'
	mov	[gs:((80*0+39)*2)], ax

	;打印内存信息
	call	DisplayMem
	;启动分页机制
	call	SetupPage

	;初始化内核(重新放置内核)
	call	InitKernel	

	;正式进入内核
	jmp	SEC_CODE32:KernelEntryPointPhyAddr

;---------------------------------------------------------------------------
;打印内存信息
;---------------------------------------------------------------------------
DisplayMem:
	;打印内存结构信息字符串
	call	DisplayMemStru
	;打印内存详细信息
	xor	ecx, ecx
	mov	ecx, [ARDSNumber]
	mov	esi, 0
	mov	ebx, MemoryBuffer
.15:
	push	ecx
	mov	ecx, 5
.16:
	
	;将可用内存总量存入MemorySize中
	cmp	ecx, 1
	jnz	.21
	push	eax
	mov	eax, dword [ebx+esi-8]	
	add	eax, dword [ebx+esi-16]
	cmp	eax, dword [MemorySize]
	jbe	.22		
	mov	dword [MemorySize], eax

.22:
	pop	eax
	
.21:
	mov	eax, dword [ebx+esi]
	rol	eax, 8
	call	DisplayAL	;十六进制打印寄存器AL中的数
	rol	eax, 8
	call	DisplayAL
	rol	eax, 8
	call	DisplayAL
	rol	eax, 8
	call	DisplayAL
	
	;打印字符'H'
	mov	al, 0x48
	mov	ah, 0x04
	mov	[gs:edi], ax
	add	edi, 2
	;打印空格
	call	DisplaySpace

	add	esi, 4

	loop	.16
	pop	ecx
	;回车换行
	call	DisplayLinefeed
	loop	.15

	;打印内存总量MemorySize
	mov	edi, (80*14+0)*2
	mov	ebx, Message4
	mov	ecx, Message4Len
	call	DisplayStr	;打印字符串
	mov	eax, dword [MemorySize]
	rol	eax, 8
	call	DisplayAL	;十六进制打印寄存器AL中的数
	rol	eax, 8
	call	DisplayAL
	rol	eax, 8
	call	DisplayAL
	rol	eax, 8
	call	DisplayAL
	;打印字符'H'
	mov	al, 0x48
	mov	ah, 0x04
	mov	[gs:edi], ax
	add	edi, 2
	
	ret
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
;开启分页机制
;----------------------------------------------------------------------------
SetupPage:
	;初始化页目录表
	mov	eax, dword [MemorySize]
	shr	eax, 22			;eax除以4M
	mov	ecx, eax		;PDE的个数
	push	ecx			;暂存PDE个数
	mov	edi, PDTBaseAdd		;页目录表首地址
	mov	eax, PTBaseAdd|PG_P|PG_USU|PG_RWW
	cld		;用来操作方向标志位DF,CLD使DF复位,即DF=0调用该指令后，EDI自增4，
.11:
	stosd		;将EAX中的值传递到当前ES段的EDI地址处
	add	eax, 4096
	loop	.11

	;初始化页表
	pop	eax
	mov	ebx, 1024
	mul	ebx		;每个页目录表1024个PTE
	mov	ecx, eax	
	xor	eax, eax
	mov	edi, PTBaseAdd
	mov	eax, PG_P|PG_USU|PG_RWW
.12:
	stosd
	add	eax, 4096
	loop	.12

	;使cr3寄存器指向页目录表基地址
	mov	eax, PDTBaseAdd
	mov	cr3, eax
	;开启分页机制
	mov	eax, cr0
	or	eax, 80000000h
	mov	cr0, eax
	
	ret
;---------------------------------------------------------------------------


;---------------------------------------------------------------------------
;初始化内核(重新放置内核)
;---------------------------------------------------------------------------
InitKernel:
	mov	edi, BaseOfKernelPhyAddr	;kernel.bin被加载的地址
	xor	ecx, ecx	;ecx寄存器清零
	mov	cx, [edi+0x2C]	;e_phnum:Program header table中条目数
	mov	eax, [edi+0x1C]	;phoff:Program header table在文件中的偏移量
	add	eax, edi	;eax+edi:Program header table的起始地址
	mov	ebx, eax	;此时ebx指向第一个Program header table
.23:
	push	ecx		;eax中存放复制的字节数
	push	edi		;edi保存kernel.bin被加载的初始地址

	mov	ecx, [ebx+0x14]	;p_memsz:段在内存中的长度
	mov	esi, [ebx+0x08]	;p_vaddr:段的第一个字节在内存中的虚拟地址
	add	edi, [ebx+0x04]	;edi+p_offset(段的第一个字节在文件中的偏移)
.24:	;逐个字节复制到指定内存
	mov	al, [edi]
	mov	[esi], al
	inc	esi
	inc	edi
	loop	.24

	
	pop	edi
	pop	ecx
	loop	.23
	ret
;---------------------------------------------------------------------------


;---------------------------------------------------------------------------
;打印内存信息结构字符串
;---------------------------------------------------------------------------
DisplayMemStru:

	mov	edi, (80*6+0)*2
	mov	ebx, Message3
	mov	ecx, Message3Len
	call	DisplayStr	;打印字符串

	;回车换行
	call	DisplayLinefeed

	ret	
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
;显示字符串
;----------------------------------------------------------------------------
DisplayStr:
	mov	esi, 0
x1:	
	mov	ah, 0x04
	mov	al, [ebx+esi]
	mov	word [gs:edi], ax
	add	edi, 2
	inc	esi
	loop	x1
	
	ret
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
;打印空格
;----------------------------------------------------------------------------
DisplaySpace:
	mov	ah, 0x04
	mov	al, 0x20
	mov	word [gs:edi], ax
	add	edi, 2
	ret
;---------------------------------------------------------------------------


;---------------------------------------------------------------------------
;打印换行符
;---------------------------------------------------------------------------
DisplayLinefeed:
	push	eax
	push	ebx

	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0x00FF
	inc	eax
	mul	bl
	mov	edi, eax
	
	pop	ebx
	pop	eax
	ret
;---------------------------------------------------------------------------


;---------------------------------------------------------------------------
;以十六进制打印AL中的内容
;---------------------------------------------------------------------------
DisplayAL:
	push	ax
	push	bx

	mov	ah, 0
	mov	bl, 16
	div	bl
	push	ax
	div	bl
	;显示字节中第一个十六进制
	mov	al, ah
	cmp	al, 9		;如果是10以上的数字
	ja	.17
	add	al, 0x30
	jmp	.18
.17:
	add	al, 0x37
.18:
	mov	ah, 0x04
	mov	[gs:edi], ax
	add	edi, 2
	;显示字节中第二个十六进制
	pop	ax
	mov	al, ah
	cmp	al, 9
	ja	.19
	add	al, 0x30
	jmp	.20
.19:
	add	al, 0x37
.20:
	mov	ah, 0x04
	mov	[gs:edi], ax
	add	edi, 2

	pop	bx
	pop	ax
	ret
;---------------------------------------------------------------------------


;---------------------------------------------------------------------------
[section .data]
[bits 32]
DataSegment:

;实模式下使用这些符号
_ARDSNumber	dd	0		;地址范围描述符结构个数
_MemoryBuffer	times	256 db 0 	;内存缓冲区
_MemorySize	dd	0		;可用内存大小
_Message3	db	"BaseAddrL BaseAddrH LengthLow LengthHigh   Type"
Message3Len	equ	$-_Message3
_Message4	db	"RAM Size:"
Message4Len	equ	$-_Message4
;保护模式下使用这些符号
ARDSNumber	equ	BaseOfLoaderPhyAddr + _ARDSNumber	;地址范围描述符结构个数
MemoryBuffer	equ	BaseOfLoaderPhyAddr + _MemoryBuffer	;内存缓冲区
MemorySize	equ	BaseOfLoaderPhyAddr + _MemorySize	;可用内存大小
Message3	equ	BaseOfLoaderPhyAddr + _Message3		;Message3偏移量
Message4	equ	BaseOfLoaderPhyAddr + _Message4		;Message4偏移量

;---------------------------------------------------------------------------


;---------------------------------------------------------------------------
;堆栈定义
StackSpace	times	1024	db	0
TopOfStack	equ	BaseOfLoaderPhyAddr + $
;---------------------------------------------------------------------------
