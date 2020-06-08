extern disp_pos


[section .text]

;导出函数
global disp_str
global disp_color_str
global out_byte

;---------------------------------------------------------------------------
;打印字符串
;void disp_str(char* s)
;---------------------------------------------------------------------------
disp_str:
	push	ebp
	mov	ebp, esp	
	push	ebx		;为了找到字符串的地址
	
	mov	esi, [ebp+8]	;字符串首地址
	mov	edi, [disp_pos] ;edi存储显示的位置
	mov	ah, 0x07
.3:
	lodsb		;串操作指令 将ds:esi中的内容按字节传送到al中
	cmp	al, 0
	jz	.1	
	cmp	al, 0x0A	;换行键
	jnz	.2
	push	eax
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0x00FF	;取商
	inc	eax		;商+1
	mul	bl
	mov	edi, eax
	pop	eax
	jmp	.3	

.2:
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.3

.1:
	mov	[disp_pos], edi

	pop	ebx
	pop	ebp
	ret


;---------------------------------------------------------------------------
;打印字符串
;void disp_color_str(char* s)
;---------------------------------------------------------------------------
disp_color_str:	
	push	ebp
	mov	ebp, esp
	push	ebx
	mov	esi, [ebp+8]	;字符串首地址
	mov	edi, [disp_pos] ;edi存储显示的位置
	mov	ah, [ebp+12]
.3:
	lodsb		;串操作指令 将ds:esi中的内容按字节传送到al中
	cmp	al, 0
	jz	.1	
	cmp	al, 0x0A	;换行键
	jnz	.2
	push	eax
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0x00FF	;取商
	inc	eax		;商+1
	mul	bl
	mov	edi, eax
	pop	eax
	jmp	.3	

.2:
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.3

.1:
	mov	[disp_pos], edi

	pop	ebx
	pop	ebp
	ret



;---------------------------------------------------------------------------
;向指定端口写入数据
;void out_byte(u16 port, u8 value);
;---------------------------------------------------------------------------
out_byte:
	mov	dx, [esp+4]	;端口
	mov	al, [esp+8]	;数据
	out	dx, al
	nop			;一点延迟
	nop

	ret

