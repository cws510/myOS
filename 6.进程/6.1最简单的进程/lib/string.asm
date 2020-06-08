global	memcpy
global 	memset
;----------------------------------------------------------------------------------
;void* memcpy(void* pDst, void* pSrc. int iSize);
;----------------------------------------------------------------------------------
memcpy:
	mov	esi, [esp + 4]	;第一个参数
	mov	edi, [esp + 8]  ;第二个参数
	mov	ecx, [esp + 12]  ;第三个参数

.1:	;逐个字节复制
	mov	al, [edi]
	mov	[esi], al
	inc	edi
	inc	esi
	
	loop	.1

	ret


; ------------------------------------------------------------------------
; void memset(void* p_dst, char ch, int size);
; ------------------------------------------------------------------------
memset:
	push	ebp
	mov	ebp, esp

	push	esi
	push	edi
	push	ecx

	mov	edi, [ebp + 8]	; Destination
	mov	edx, [ebp + 12]	; Char to be putted
	mov	ecx, [ebp + 16]	; Counter
.1:
	cmp	ecx, 0		; 判断计数器
	jz	.2		; 计数器为零时跳出

	mov	byte [edi], dl		; ┓
	inc	edi			; ┛

	dec	ecx		; 计数器减一
	jmp	.1		; 循环
.2:

	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp

	ret			; 函数结束，返回
; ------------------------------------------------------------------------
