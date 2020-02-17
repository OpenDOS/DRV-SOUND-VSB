.286
;-Set-vectors-macro-----
set_vec		macro	int_num,handler,old
		mov	ax,3500h+int_num
		int	21h
		mov	word ptr old,bx
		mov	word ptr old+2,es
		mov	ax,2500h+int_num
		mov	dx,offset handler
		int	21h
		endm
;-equals----------------
cr		equ	0dh
lf		equ	0ah
buf_lenr	equ	08h		; default buffer length
buf_len		equ	20h
kb_flag		equ	17h
kb_mask		equ	00000001b	; right_shift
inc_key		equ	4eh		; grey_plus
dec_key		equ	4ah		; grey_minus
p_data		equ	278h		; address of any free port
p_stat		equ	p_data+1
p_cont		equ	p_data+2
p_dac		equ	378h		; address of dac port
p_sdac		equ	p_dac+2
p_nest		equ	40ah		; 408h - lpt1  40ch - lpt3
					; 40ah - lpt2  40eh - lpt4
tune_attr	equ	0ah		; green on black
rtc_speed	equ	0100011b; 1111 - 2 hz   1010 - 64 hz   0101 - 2048 hz
		;divisor^^^ù^^^	; 1110 - 4 hz   1001 - 128 hz  0100 - 4096 hz
		;counter---ù	; 1101 - 8 hz   1000 - 256 hz  0011 - 8192 hz
				; 1100 - 16 hz  0111 - 512 hz  0010&0001 - n/a
				; 1011 - 32 hz  0110 - 1024 hz 0000 - none
cseg		segment
		org 100h
		assume cs:cseg,ds:cseg
start:
		jmp	init_
;-int-70h-handler-------
int70_hand	proc	near
		cmp	byte ptr cs:int70_act,1
		jnz	int70_ex
		cli
		push	ax cx dx si ds cs
		pop	ds
		cld
		mov	si,word ptr ds:dss_offtim
		mov	dx,p_sdac	; use this
		mov	al,3		; on stereo-in-one
		out	dx,al		; only!
		Mov	dx,p_dac
int70_3:
		outsb
		cmp	byte ptr ds:count,0
		jz	int70_2
		dec	byte ptr ds:count
int70_2:
		cmp	si,offset dss_buf+buf_len
		jnz	int70_1
		mov	si,offset dss_buf
int70_1:
		mov	word ptr ds:dss_offtim,si
		cmp	si,word ptr ds:dss_offcab
		jnz	int70_ex1
		mov	byte ptr ds:int70_act,0
int70_ex1:
		pop	ds si dx cx ax
		sti
int70_ex:
		push	ax
int70_4:
		mov	al,0ch
		out	70h,al
		in	al,71h
		test	al,40h
		jnz	int70_4
		mov	al,20h
		out	0a0h,al
		out	20h,al
		pop	ax
		iret
int70_act	db	0
int70_hand	endp
;-callback-function-----
callb_fun	proc	near
		push	bx ds cs
		pop	ds
		mov	bl,byte ptr ds:dss_buflen
		cmp	dx,p_data
		jz	send_data
		cmp	dx,p_stat
		jz	get_stat
		cmp	dx,p_cont
		jz	send_strob
		pop	ds bx
		stc
		retf
send_data:
		or	cl,cl
		jz	callb_ex
		cmp	byte ptr ds:count,bl
		jg	callb_ex
		push	di
		mov	di,word ptr ds:dss_offcab
		mov	byte ptr ds:[di],al
		pop	di
		jmp	callb_ex
get_stat:
		or	cl,cl
		jnz	callb_ex
		cmp	byte ptr ds:count,bl
		jg	not_ready
		mov	al,0
		jmp	callb_ex
not_ready:
		mov	al,40h
		jmp	callb_ex
send_strob:
		or	cl,cl
		jz	callb_ex
		cmp	byte ptr ds:count,bl
		jg	callb_ex
		test	al,8
		jnz	callb_ex
		inc	byte ptr ds:count
		push	ax
		mov	ax,word ptr ds:dss_offcab
		inc	ax
		cmp	ax,offset dss_buf+buf_len
		jnz	send_1
		mov	ax,offset dss_buf
send_1:
		mov	word ptr ds:dss_offcab,ax
		cmp	byte ptr ds:int70_act,1
		jz	alr_act
		mov	byte ptr ds:int70_act,1
alr_act:
		pop	ax
callb_ex:
		pop	ds bx
		clc
		retf
dss_buflen	db	buf_lenr
dss_offcab	dw	offset dss_buf
dss_offtim	dw	offset dss_buf
count		db	0
dss_buf		db	buf_len dup (80h)
callb_fun	endp
;-int-09h-handler-------
int09_hand	proc	near
		push	es ax
		push	40h
		pop	es
		test	byte ptr es:kb_flag,kb_mask
		jz	int09_ex
		mov	ah,byte ptr cs:dss_buflen
		in	al,60h
		cmp	al,inc_key
		jz	inc_buf
		cmp	al,dec_key
		jnz	int09_ex
	;-decrease-buf--
		cmp	ah,1
		jz	set_bufl
		dec	ah
		jmp	set_bufl
	;-increase-buf--
inc_buf:
		cmp	ah,buf_len-1
		jz	set_bufl
		inc	ah
set_bufl:
		mov	byte ptr cs:dss_buflen,ah
		push	bx
		xor	al,al
		xchg	al,ah
		mov	bx,0b800h
		mov	es,bx
		mov	bl,10
		div	bl
		add	ax,3030h
		mov	bx,78*2
		mov	byte ptr es:[bx],al
		mov	byte ptr es:[bx+1],tune_attr
		mov	byte ptr es:[bx+2],ah
		mov	byte ptr es:[bx+3],tune_attr
		in	al,61h
		mov	ah,al
		or	al,80h
		out	61h,al
		xchg	al,ah
		out	61h,al
		mov	al,20h
		out	20h,al
		pop	bx ax es
		iret
int09_ex:
		pop	ax es
		db	0eah		; jmp far
int09_old	dd	?
Int09_hand	endp
;-get-qemm-api-address--
init_		label	near
		mov	dx,offset logo
		call	fast_ex
		mov	ah,3fh
		mov	cx,5145h	; 'qe'
		mov	dx,4d4dh	; 'mm'
		int	67h
		or	ah,ah
		jz	cont_1
		mov	dx,offset err_1
		jmp	fast_ex
cont_1:
		mov	word ptr ds:api_seg,es
		mov	word ptr ds:api_off,di
;-check-qemm-state------
		mov	ah,0
		call	qemm_api
		test	al,1
		jz	cont_2
		mov	dx,offset err_2
		jmp	fast_ex
cont_2:
		test	al,2
		jz	cont_3
		mov	dx,offset err_3
		jmp	fast_ex
cont_3:
		mov	dx,offset suc_1
		call	fast_ex
;-check-ports-trap------
		mov	cx,3
		mov	si,offset port_list
cont_6:
		lodsw
		xchg	dx,ax
		mov	bp,dx
		mov	ax,1a08h
		call	qemm_api
		or	bl,bl
		jz	cont_5
		mov	dx,offset err_5
		jmp	fast_ex
cont_5:
;-trap-dss-ports--------
		mov	ax,1a09h
		mov	dx,bp
		call	qemm_api
		jnc	cont_4
		mov	dx,offset err_4
		jmp	fast_ex
cont_4:
		loop	cont_6
;-set-callback-address--
		mov	ax,1a07h
		push	cs
		pop	es
		mov	di,offset callb_fun
		call	qemm_api
;-set-new-lpt2-address--
		xor	ax,ax
		mov	es,ax
		mov	word ptr es:p_nest,p_data
;-set-vectors-----------
		mov	dx,offset suc_3
		call	fast_ex
		mov	ax,2570h
		mov	dx,offset int70_hand
		int	21h
;-irq8-inable-----------
		cli
		in	al,0a1h
		and	al,0feh
		out	0a1h,al
;-set-real-timer-active-
		mov	al,0bh
		out	70h,al
		in	al,71h
		and	al,7fh
		or	al,40h
		push	ax
		mov	al,0bh
		out	70h,al
		pop	ax
		out	71h,al
;-set-real-timer-speed--
		mov	al,0ah
		out	70h,al
		in	al,71h
		and	al,80h
		or	al,rtc_speed
		push	ax
		mov	al,0ah
		out	70h,al
		pop	ax
		out	71h,al
		sti
;-calculate-buffer-len--
		mov	bl,buf_len-1	; start value
ca_bu_4:
		mov	byte ptr ds:dss_buflen,bl
		mov	dx,p_cont
		mov	al,4
		out	dx,al
		mov	cx,buf_len
ca_bu_1:
		mov	dx,p_data
		mov	al,80h
		out	dx,al
		push	ax
		pop	ax
		mov	al,0ch
		mov	dx,p_cont
		out	dx,al
		push	ax
		pop	ax
		push	ax
		pop	ax
		mov	al,04h
		mov	dx,p_cont
		out	dx,al
		loop	ca_bu_1
		mov	dx,p_stat
		in	al,dx
		or	al,al
		jnz	ca_bu_2
		mov	dx,p_cont
		mov	al,0ch
		out	dx,al
		dec	bl
		jz	ca_bu_2
ca_bu_3:
		cmp	byte ptr ds:count,0
		jnz	ca_bu_3
		jmp	ca_bu_4
ca_bu_2:
;-write-buffer-length---
		xor	bh,bh
		mov	al,10
		xchg	bx,ax
		div	bl
		add	ax,3030h
		int	29h
		xchg	al,ah
		int	29h
		mov	dx,offset suc_4
		call	fast_ex
;-set-int-09h-handler---
		set_vec	09h,int09_hand,int09_old
;-leave-tsr-------------
		mov	dx,offset suc_2
		call	fast_ex
		mov	dx,offset init_
		int	27h
;-call-qemm-api---------
qemm_api:
		db	09ah		; call far
api_off		dw	0
api_seg		dw	0
		retn
;-fast-exit-------------
fast_ex:
		mov	ah,9
		int	21h
		retn
;-program-data----------
port_list	dw	p_data,p_stat,p_cont
logo		db	'dss emulator v0.05 By skullc0der',cr,lf,'$'
err_1		db	'qemm not installed!',Cr,lf,'$'
err_2		db	'qemm is turned off!',Cr,lf,'$'
err_3		db	'qemm is in auto mode!',Cr,lf,'$'
err_4		db	'error while trapping ports!$',Cr,lf,'$'
err_5		db	'port already trapped!',Cr,lf,'$'
suc_1		db	'qemm is ok.',Cr,lf,'$'
suc_2		db	'you now have real dss on lpt2!',Cr,lf
		db	'key usage:',cr,lf
		db	'right_shift+grey_minus to decrease buffer',cr,lf
		db	'right_shift+grey_plus to increase buffer',cr,lf
		db	'exiting.',Cr,lf,'$'
suc_3		db	'dss buffer length is now $'
suc_4		db	' bytes.',Cr,lf,'$'

cseg		ends
		end	start
