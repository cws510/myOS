	
	org	0x7c00
	
	jmp	LABEL_START
	nop			;这个nop不可少

;下面是FAT12磁盘的头
%include "fat12hdr.inc"
%include "load.inc"

;-----------------------------------------------------------------------------
BaseOfStack	equ	0x7c00		;堆栈基地址(栈底,从这个位置向低地址生长)	

LoaderFileName	db	"LOADER  BIN"	;loader文件名
Message1	db	"Booting  "
Message2	db	"Ready    "
DHNumber	db	0
MessageLength	equ	9
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
LABEL_START:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, BaseOfStack

	;清屏
	mov	ax, 0600h	;AH=06H 向上滚动窗口	AL=0 清除
	mov	bx, 0700h	;黑底白字
	mov	cx, 0		;左上角(0,0)
	mov	dx, 0184fh	;右下角(80,50)
	int	10h

	;打印字符串"Booting"
	mov	bp, Message1
	call	DisplayStr

	;寻找loader.bin
	call	FindLoader	;调用完函数 ax中保存着开始簇号
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

	;打印字符串"Ready"
	mov	bp, Message2
	call	DisplayStr

	jmp	BaseOfLoader:OffsetLoader	;这一句正式跳转到已加载到内存中
						;的loader.bin的开始处,开始执行
						;loader.bin的代码,boot引导扇区
						;使命到此结束
;----------------------------------------------------------------------------


;---------------------------------------------------------------------------
;寻找loader.bin
;---------------------------------------------------------------------------
FindLoader:
	;软驱复位
	xor	ah, ah
	xor	dl, dl
	int	13h

	mov	ax, BaseOfLoader
	mov	es, ax			;loader加载段地址
	mov	bx, OffsetLoader	;loader加载偏移地址
	xor	ecx, ecx
	mov	cx, RootDirSectors	;根目录占用扇区数14
	mov	ax, RootDirFirSecNum	;根目录第一个扇区号19
.1:	;此循环读取根目录的所有扇区

	push	cx			;之前有用到cx,所以此时使用要压栈
	
	;读取软盘扇区,将软盘一个扇区内容放入es:bx所在的内存中
	call	ReadSector

	mov	cx, 11			;loader文件名的长度
	mov	di, 0			;di指向es:bx内存内容
	mov	si, LoaderFileName	;si指向loader文件名字
.3:
	mov	dl, [es:(bx+di)]
	cmp	dl, [si]		;判断指向的字符是否相同
	jz	.2
	mov	cx, 11			;字符只要有一个不同就将cx的值重新置为11
	inc	di
	cmp	di, 512
	jz	.5
	mov	si, LoaderFileName
	jmp	.3
.2:
	dec	cx			;字符相同cx减一
	cmp	cx, 0			;如果cx=0说明11个字符完全相同,找到loader
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
	add	di, 16		;di+17使di指向DIR_FstClus(loader文件内容对应的开始簇号)
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
DisplayStr:
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


times	510-($-$$)	db	0
end	dw	0xaa55	

