		.model	tiny
		.386p

Code16		segment	byte use16
		assume	cs:Code16, ds:Code16
		group	_Code Code16,Code32,ZZZcode16

		org 100h

Start:		jmp	Init

Code16		ends

Code32		segment byte use32
		assume	cs:Code32
irq0handler:	push	eax
		push	ebx

		mov	ebx,12345678h
PatchRelOffs	equ	dword ptr $-4
		mov	eax,30h
		mov	ds,ax
		
		mov	al,ds:TestVar[ebx]
		mov	ds:[0B0030h],al
		pop	ebx
		pop	eax
		db	0EAh		; JMP FAR
old0offset	dd	?
old0selector	dw	?

testvar		db	'@'
Code32		ends

ZZZcode16	segment	byte use16
		assume	cs:ZZZcode16,ds:Code16

Init:		xor	bx,bx
		call	GetLinearAddr
		mov	PatchRelOffs,eax
		call	FindQEMMIDT
		mov	bx,low offset irq0handler + 100h
		call	SetIRQ0address
		mov	dx,offset Init
		int	27h

FindQEMMIDT	proc	near
		sidt	QEMMidt
		mov	ecx,dword ptr QEMMidt + 2
		shr	ecx,12
		mov	ax,0DE06h		; Get REAL page address
		int	67h
		movzx	eax,word ptr QEMMidt + 2
		and	ah,0Fh
		add	eax,edx
		mov	QEMMIDTaddr,eax
		ret
FindQEMMIDT	endp

SetIRQ0address	proc	near
		call	GetLinearAddr
		push	eax
		mov	esi,QEMMIDTaddr
		mov	bx,offset Buffer
		call	GetLinearAddr
		mov	edi,eax
		mov	cx,16 * 8
		call	MoveXM
		mov	bx,offset Buffer + 8 * 8
		mov	ax,[bx + 6]
		shl	eax,16
		mov	ax,[bx]
		mov	old0offset,eax
		mov	ax,[bx+2]
		mov	old0selector,ax
		pop	eax
		mov	word ptr [bx],ax
		shr	eax,16
		mov	word ptr [bx+6],ax
		mov	bx,offset Buffer
		call	GetLinearAddr
		mov	esi,eax
		mov	edi,QEMMIDTaddr
		mov	cx,16 * 8
		call	MoveXM
		ret
Buffer		db	16 * 8 dup (?)
SetIRQ0address	endp

GetLinearAddr	proc	near
		mov	ax,ds
		movzx	eax,ax
		movzx	ebx,bx
		shl	eax,4
		add	eax,ebx
		ret
GetLinearAddr	endp

; IN: ESI   = source address
;     EDI   = dest address
;     CX    = counter
MoveXM		proc	near
		or	esi,93000000h
		or	edi,93000000h
		mov	dword ptr DescTable + 18,esi
		mov	dword ptr DescTable + 26,edi
		mov	si,offset DescTable
		shr	cx,1
		mov	ah,87h
		mov	si,offset DescTable
		int	15h
		ret

DescTable	label	near
rept	6
		dw	0FFFFh
		dd	0
		db	08Fh
		db	0
endm
MoveXM		endp

QEMMidt 	dq	?
QEMMIDTaddr	dd	?

ZZZcode16	ends

		end	Start
