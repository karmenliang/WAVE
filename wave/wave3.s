;;; -*- mode: asm; compile-command: "wia wave3.s" -*-
;;; (c) 2019 Andrew Thai and Karmen Liang

;;; --------- WIND REGISTERS --------------
	.requ	ir,r2		; instruction register, holds opcode
	.requ	sr1,r3		; source 1 value
	.requ	sr2,r4		; source 2 value
	.requ	dr,r5		; destination
	.requ	sr3,r6		; source 3
	.requ	tmp,r7		; temp, for calculations
	.requ	wsr1,r8		; source 1 reg
	.requ	shp,r9		; shop
	.requ	srg,r10		; shift reg
	.requ	wcr,r12		; warm ccr
	
	lea	warm,r0
	trap	$SysOverlay
		
;;; --------- INSTRUCTION FETCH LOOP ------
loop:	and	$0xFFFFFF,wpc	; TOP OF INSTRUCTION FETCH LOOP ----------------
	mov	wpc,r1
	mov	warm(r1),ir	; fetch instruction
	shr	$26,ir
	mov	conjmp(ir),rip	; jmp to condition

;;; --------- CONDITIONS ------------------
alw:	mov	warm(r1),r0	; ALWAYS
	trap	$SysPLA		; decode format
	mov	warm(r1),ir	; get opcode
	shr	$23,ir
	and	$0x3F,ir
	mov	formjmp(r0),rip	; jmp to format table
	
nev:	add	$1,wpc		; NEVER
	jmp	loop

eql:	test	$4,wcr		; EQUAL
	jne	alw		; Z = 1
	add	$1,wpc		
	jmp	loop
	
neql:	test	$4,wcr
	je	alw		; Z = 0
	add	$1,wpc		
	jmp	loop

lse:	test	$4,wcr		; LESS THAN OR EQUAL
	jne	alw		; Z = 1
lss:	mov	wcr,ir	
	mov	ir,tmp
	and	$1,tmp		; get V
	shr	$3,ir		; get N
	cmp	ir,tmp
	jne	alw		; V != N
	add	$1,wpc
	jmp	loop
	
grt:	test	$4,wcr		; GREATER THAN
	jne	stop		; Z = 0
grte:	mov	wcr,ir		; GREATER THAN OR EQUAL
	mov	ir,tmp
	and	$1,tmp		; get V
	shr	$3,ir		; get N
	cmp	ir,tmp
	je	alw		; V = N
stop:	add	$1,wpc
	jmp	loop
	
;;; --------- INSTRUCTION FORMATS ---------
form0:	mov	warm(r1),sr1	; ARITHMETIC 1: EXP AND VAL
	shr	$15,sr1		; get source 1, 15-18 bit
	and	$0xF,sr1
	mov	wregs(sr1),sr1	; store val in sr1
movf0:	mov	warm(r1),dr	; get dest, 19-22 bit
	shr	$19,dr
	and	$0xF,dr
cmpf0:	mov	warm(r1),tmp	; get sr2
	mov	tmp,sr2
	and	$0x1FF,sr2	; get val
	shr	$9,tmp
	and	$0x1F,tmp	; get exp
	shl	tmp,sr2		; shift val by exp
	add	$1,wpc		; increm pc
	mov	opjmp(ir),rip	; go to instruc
	
form1:	mov	warm(r1),sr1	; ARITHMETIC 2 or LOAD/STORE 1: SHIFT COUNT
	shr	$15,sr1		; get source 1
	and	$0xF,sr1
	mov	wregs(sr1),sr1	; store val in sr1
movf1:	mov	warm(r1),dr	; get dest
	shr	$19,dr
	and	$0xF,dr
cmpf1:	mov	warm(r1),sr2	; get source 2
	shr	$6,sr2
	and	$0xF,sr2
	mov	wregs(sr2),sr2	; store val in sr2
	add	$1,wpc		; increm pc
	mov	warm(r1),srg
	and	$0x3F,srg	; get shift count
	cmove	opjmp(ir),rip
	mov	warm(r1),shp
	shr	$10,shp
	and	$3,shp		; get shop
	mov	shpjmp(shp),rip	; go to shop

form2:	mov	warm(r1),sr1	; ARITHMETIC 3: SHIFT REG
	shr	$15,sr1		; get source 1
	and	$0xF,sr1
	mov	wregs(sr1),sr1	; store val in sr1
movf2:	mov	warm(r1),dr	; get dest
	shr	$19,dr
	and	$0xF,dr
cmpf2:	mov	warm(r1),sr2	; get source 2
	shr	$6,sr2
	and	$0xF,sr2
	mov	wregs(sr2),sr2	; store val in sr2
	mov	warm(r1),srg
	and	$0xF,srg	; get shift reg
	mov	wregs(srg),srg
	mov	warm(r1),shp
	shr	$10,shp
	and	$3,shp		; get shop
	add	$1,wpc
	mov	shpjmp(shp),rip	; go to shop

form3:	mov	warm(r1),sr1	; ARITHMETIC 4: 3 REG
	shr	$15,sr1		; get source 1
	and	$0xF,sr1
	mov	wregs(sr1),sr1	; store val in sr1
	mov	warm(r1),dr	; get dest
	shr	$19,dr
	and	$0xF,dr
	mov	warm(r1),sr2	; get source 2
	shr	$6,sr2
	and	$0xF,sr2
	mov	wregs(sr2),sr2	; store val in sr2	
	mov	warm(r1),sr3
	and	$0xF,sr3	; get source 3
	mul	wregs(sr3),sr2
	add	$1,wpc		; increm pc
	mov	opjmp(ir),rip	; go to instruc
	
form4:	mov	warm(r1),wsr1	; LOAD/STORE 1: SIGNED OFFSET
	shr	$15,wsr1
	and	$0xF,wsr1	; get base reg
	mov	wregs(wsr1),sr1	; store val in base reg
	mov	warm(r1),dr
	shr	$19,dr
	and	$0xF,dr		; get dest
	mov	warm(r1),sr2
	shl	$18,sr2		; sign extend
	sar	$18,sr2
	add 	$1,wpc		; increm pc	
	mov	opjmp(ir),rip	; go to instruc

form6:	test	$0x1000000,warm(r1)	; BRANCH
	jne	wbl		; 1101, wbl
	add	warm(r1),wpc	; wb: compute dest
	and	$0xFFFFFF,wpc	; TOP OF INSTRUCTION FETCH LOOP ----------------
	mov	wpc,r1
	mov	warm(r1),ir	; fetch instruction
	shr	$26,ir
	mov	conjmp(ir),rip	; jmp to condition

beql:	test	$4,wcr		; EQUAL
	jne	form6		; Z = 1
	add	$1,wpc		
	jmp	loop

bneql:	test	$4,wcr
	je	form6		; Z = 0
	add	$1,wpc		
	jmp	loop

blse:	test	$4,wcr		; LESS THAN OR EQUAL
	jne	form6		; Z = 1
blss:	mov	wcr,ir		
	mov	ir,tmp
	and	$1,tmp		; get V
	shr	$3,ir		; get N
	cmp	ir,tmp
	jne	form6		; V != N
	add	$1,wpc
	jmp	loop
	
bgrt:	test	$4,wcr		; GREATER THAN
	jne	stop		; Z = 0
bgrte:	mov	wcr,ir	
	mov	ir,tmp
	and	$1,tmp		; get V
	shr	$3,ir		; get N
	cmp	ir,tmp
	je	form6		; V = N
	add	$1,wpc
	jmp	loop

;;; ---------- SHIFT OPERATIONS  ----------
wlsl:	shl	srg,sr2		; LSL
	mov	opjmp(ir),rip

wlsr:	shr	srg,sr2		; LSR
	mov	opjmp(ir),rip

wasr:	sar	srg,sr2		; ASR
	mov	opjmp(ir),rip

wror:	mov	$32,shp		; ROR
	sub	srg,shp		; 32 - shift amount
	mov	sr2,tmp
	shl	shp,sr2		; bottom n bits on top
	shr	srg,tmp		
	add	tmp,sr2
	mov	opjmp(ir),rip
	
;;; -------- EXECUTING INSTRUCTION --------
wadd:	lea	0(sr1,sr2),wregs(dr) ; ADD
	jmp	loop		; ADD DONE
	
wadc:	test	$2,wcr		; ADC
	je	wadd
	lea	1(sr1,sr2),wregs(dr)
	jmp	loop		; ADC DONE

wsub:	sub	sr2,sr1		; SUB
	mov	sr1,wregs(dr)
	jmp	loop		; SUB DONE

wcmp:	mov	warm(r1),sr1	; CMP
	shr	$15,sr1		; get source 1
	and	$0xF,sr1
	cmp	sr2,wregs(sr1)	
	mov	ccr,wcr
	jmp	loop		; CMP DONE

weor:	xor	sr1,sr2		; EOR
	mov	sr2,wregs(dr)
	jmp	loop		; EOR DONE

worr:	or	sr1,sr2		; OR
	mov	sr2,wregs(dr)
	jmp	loop		; OR DONE

wand:	and	sr1,sr2		; AND
	mov	sr2,wregs(dr)
	jmp	loop		; AND DONE

wtst:	test	sr1,sr2	
	mov	ccr,wcr
	jmp	loop		; TEST DONE
	
wmul:	mul	sr1,sr2		; MUL
	mov	sr2,wregs(dr)
	jmp	loop		; MUL DONE

wmla:	lea	0(sr1,sr2),wregs(dr)
	jmp	loop		; MLA DONE
	
wdiv:	div	sr2,sr1		; DIV
	mov	sr1,wregs(dr)
	jmp	loop		; DIV DONE
	
wmov:	mov	sr2,wregs(dr)	; MOV
	and	$0xFFFFFF,wpc	; TOP OF INSTRUCTION FETCH LOOP ----------------
	mov	wpc,r1
	mov	warm(r1),ir	; fetch instruction
	shr	$26,ir
	mov	conjmp(ir),rip	; jmp to condition

wmvn:	mov	sr2,wregs(dr)	; MOVN
	xor	$0xFFFFFFFF,wregs(dr)
	jmp	loop		; MOVN DONE

wswi:	mov	swijmp(sr2),rip	; SWI

gchar:	trap	$SysGetChar 	; #SYSGETCHAR
	mov	r0,wr0
	jmp	loop		; SWI DONE
	
gnum:	trap	$SysGetNum	; #SYSGETNUM
	mov	r0,wr0
	jmp	loop		; SWI DONE
	
pchar:	mov	wr0,r0		; #SYSPUTCHAR
	trap	$SysPutChar
	jmp	loop		; SWI DONE
	
pnum:	mov	wr0,r0		; #SYSPUTNUM
	trap	$SysPutNum
	jmp	loop		; SWI DONE
	
ent:	trap	$SysEntropy	; #SYSENTROPY
	mov	r0,wr0
	jmp	loop		; SWI DONE
	
olay:	trap	$SysOverlay	; #SYSOVERLAY
	jmp	loop		; SWI DONE
	
pla:	trap	$SysPLA		; #SYSPLA
	mov	r0,wr0
	jmp	loop		; SWI DONE
	
wbl:	mov	wpc,wlr
	add	$1,wlr
	add	warm(r1),wpc
	jmp	loop		; BL DONE
	
halt:	trap	$SysHalt

wldm:	mov	wregs(dr),tmp	; LDM
	mov	$0,sr3		; current register
ldmlp:	and	$0xFFFFFF,tmp	; mask adr
	test	$0x1,sr2	; check bit
	je	ldmend		; not set
	mov	warm(tmp),wregs(sr3) ; load
	add	$1,tmp		     ; increment adr
ldmend:	add	$1,sr3		; increment register
	cmp	$15,sr3		; if wpc
	je	ldmcr		; is wpc
	shr	$1,sr2		; time for next bit
	jne	ldmlp		; if 0 can stop, not 0 repeat
	jmp	wlstop		; stop
ldmcr:	shr	$1,sr2		; check 15th bit
	je	wlstop		; if 0 can stop
	and	$0xFFFFFF,tmp	; mask
	mov	warm(tmp),wpc	; load wpc
	mov	warm(tmp),wcr	; get cc
	shr	$28,wcr		
	add	$1,tmp		
wlstop:	mov	tmp,wregs(dr)
	and	$0xFFFFFF,wregs(dr)
	jmp	loop
	
wstm:	mov	wregs(dr),tmp
	mov	$15,sr3
	test	$0x8000,sr2
	je	stmend
	sub	$1,tmp
	and	$0xFFFFFF,tmp
	mov	wcr,warm(tmp)
	shl	$28,warm(tmp)
	and	$0xFFFFFF,wpc
	add	wpc,warm(tmp)
stmend:	sub	$1,sr3
	shl	$1,sr2
	and	$0xFFFF,sr2
	je	wsstop
	test	$0x8000,sr2
	je	stmend
	sub	$1,tmp
	and	$0xFFFFFF,tmp
	mov	wregs(sr3),warm(tmp)
	jmp	stmend
wsstop:	mov	tmp,wregs(dr)
	and	$0xFFFFFF,wregs(dr)
	jmp	loop
	
wldr:	add	sr1,sr2		; LDR
	and	$0xFFFFFF,sr2
	mov	warm(sr2),wregs(dr)
	jmp	loop		; LDR DONE
	
wstr:	add	sr1,sr2		; STR
	and	$0xFFFFFF,sr2	
	mov	wregs(dr),warm(sr2)	; dest val written to mem location
	jmp	loop		; STR DONE

wldu:	test	$0x2000,sr2	; LDU
	je	wldup		
	add	sr1,sr2
	and	$0xFFFFFF,sr2
	mov	warm(sr2),wregs(dr)
	mov	sr2,wregs(wsr1)
	jmp	loop		; LDU DONE
	
wldup:	and	$0xFFFFFF,sr1
	mov	warm(sr1),wregs(dr)
	lea	0(sr1,sr2),wregs(wsr1)
	and	$0xFFFFFF,wregs(wsr1)
	jmp	loop		; LDU DONE
	
wstu:	test	$0x2000,sr2	; STU
	je	wstup		
	add	sr1,sr2		; add offset to base
	and	$0xFFFFFF,sr2
	mov	wregs(dr),warm(sr2) ; dest val written to mem location
	mov	sr2,wregs(wsr1)	; effective addr written to base
	jmp	loop 		; STU DONE
	
wstup:	and	$0xFFFFFF,sr1
	mov	wregs(dr),warm(sr1)
	lea	0(sr1,sr2),wregs(wsr1)
	and	$0xFFFFFF,wregs(wsr1)
	jmp	loop		; STU DONE
	
wadr:	lea	0(sr1,sr2),wregs(dr) ; ADR
	and	$0xFFFFFF,wregs(dr)	; sum of offset and base
	jmp	loop		; ADR DONE
	
;;; -------- CONDITIONED INSTRUCTIONS --------	
wadds:	add	sr1,sr2		; ADDS
	mov	ccr,wcr
	mov	sr2,wregs(dr)
	jmp	loop		; ADDS DONE

wadcs:	test	$2,wcr		; ADCS
	je	wadds
	lea	1(sr1,sr2),wregs(dr)
	cmp	$0,wregs(dr)
	mov	ccr,wcr
	jmp	loop		; ADCS DONE
	
wsubs:	sub	sr2,sr1		; SUBS
	mov	ccr,wcr
	mov	sr1,wregs(dr)
	jmp	loop		; SUBS DONE

weors:	xor	sr1,sr2		; EOR
	mov	ccr,wcr
	mov	sr2,wregs(dr)
	jmp	loop		; EOR DONE

worrs:	or	sr1,sr2		; OR
	mov	ccr,wcr
	mov	sr2,wregs(dr)
	jmp	loop		; OR DONE

wands:	and	sr1,sr2		; AND
	mov	ccr,wcr
	mov	sr2,wregs(dr)
	jmp	loop		; AND DONE

wmuls:	mul	sr1,sr2		; MUL
	mov	ccr,wcr
	mov	sr2,wregs(dr)
	jmp	loop		; MUL DONE

wmlas:	add	sr1,sr2		; MLA
	mov	ccr,wcr
	mov 	sr2,wregs(dr)
	jmp	loop		; MLA DONE
	
wdivs:	div	sr2,sr1
	mov	ccr,wcr
	mov	sr1,wregs(dr)
	jmp	loop		; DIV DONE
	
wmovs:	mov	sr2,wregs(dr)	; MOV
	cmp	$0,sr2
	mov	ccr,wcr
	and	$0xFFFFFF,wpc	; TOP OF INSTRUCTION FETCH LOOP ----------------
	mov	wpc,r1
	mov	warm(r1),ir	; fetch instruction
	shr	$26,ir
	mov	conjmp(ir),rip	; jmp to condition

wmvns:	mov	sr2,wregs(dr)	; MOVN
	xor	$0xFFFFFFFF,wregs(dr)
	mov	ccr,wcr
	jmp	loop		; MOVN DONE

wswis:	mov	swisjmp(sr2),rip; SWIS

gchars:	trap	$SysGetChar	; #SYSGETCHAR
	cmp	$0,r0
	mov	ccr,wcr
	mov	r0,wr0
	jmp	loop		; SWIS DONE
	
gnums:	trap	$SysGetNum	; #SYSGETNUM
	cmp	$0,r0
	mov	ccr,wcr
	mov	r0,wr0
	jmp	loop		; SWIS DONE

pchars:	mov	wr0,r0
	cmp	$0,r0		; #SYSPUTCHAR
	mov	ccr,wcr
	trap	$SysPutChar
	jmp	loop		; SWI DONE
	
pnums:	mov	wr0,r0		; #SYSPUTNUM
	cmp	$0,r0
	mov	ccr,wcr
	trap	$SysPutNum
	jmp	loop		; SWI DONE

ents:	trap	$SysEntropy	; #SYSENTROPY
	mov	r0,wr0
	cmp	$0,r0
	mov	ccr,wcr
	jmp	loop		; SWI DONE

plas:	trap	$SysPLA
	mov	r0,wr0
	cmp	$0,wr0
	mov	ccr,wcr
	jmp	loop
	
wldrs:	add	sr1,sr2
	and	$0xFFFFFF,sr2
	mov	warm(sr2),wregs(dr)
	cmp	$0,wregs(dr)
	mov	ccr,wcr
	jmp	loop		; LDRS DONE
	
wstrs:	add	sr1,sr2
	and	$0xFFFFFF,sr2	
	mov	wregs(dr),warm(sr2)
	cmp	$0,wregs(dr)
	mov	ccr,wcr
	jmp	loop		; STRS DONE

wldus:	test	$0x2000,sr2	; LDUS
	je	wldups
	add	sr1,sr2
	and	$0xFFFFFF,sr2
	mov	warm(sr2),wregs(dr)
	cmp	$0,wregs(dr)
	mov	ccr,wcr
	mov	sr2,wregs(wsr1)
	jmp	loop		; LDUS DONE

wldups:	and	$0xFFFFFF,sr1
	mov	warm(sr1),wregs(dr)
	cmp	$0,wregs(dr)
	mov	ccr,wcr
	lea	0(sr1,sr2),wregs(wsr1)
	and	$0xFFFFFF,wregs(wsr1)
	jmp	loop		; LDU DONE

wstus:	test	$0x2000,sr2
	je	wstups
	add	sr1,sr2
	and	$0xFFFFFF,sr2
	mov	wregs(dr),warm(sr2)
	cmp	$0,wregs(dr)
	mov	ccr,wcr
	mov	sr2,wregs(wsr1)
	jmp	loop 		; STUS DONE

wstups:	and	$0xFFFFFF,sr1
	mov	wregs(dr),warm(sr1)
	cmp	$0,wregs(dr)
	mov	ccr,wcr
	lea	0(sr1,sr2),wregs(wsr1)
	and	$0xFFFFFF,wregs(wsr1)
	jmp	loop		; STU DONE
	
;;; ------------ TABLES ------------
formjmp:
	.data	form0,form1,form2,form3,form4,form1,form6,halt
	.data 	movf0,movf1,movf2,halt,cmpf0,cmpf1,cmpf2

shpjmp:
	.data	wlsl,wlsr,wasr,wror

swijmp:
	.data	halt,gchar,gnum,pchar,pnum,ent,olay,pla	

swisjmp:
	.data	halt,gchars,gnums,pchars,pnums,ents,olay,plas	

conjmp:
	.data	alw,alw,alw,form6,alw,alw,alw,form6
	.data	nev,nev,nev,nev,nev,nev,nev,nev
	.data	eql,eql,eql,beql,eql,eql,eql,beql
	.data	neql,neql,neql,bneql,neql,neql,neql,bneql
	.data	lss,lss,lss,blss,lss,lss,lss,blss
	.data	lse,lse,lse,blse,lse,lse,lse,blse
	.data	grte,grte,grte,bgrte,grte,grte,grte,bgrte
	.data	grt,grt,grt,bgrt,grt,grt,grt,bgrt

opjmp:
	.data	wadd,wadc,wsub,wcmp,weor,worr,wand,wtst
	.data	wmul,wmla,wdiv,wmov,wmvn,wswi,wldm,wstm
	.data	wldr,wstr,wldu,wstu,wadr,halt,halt,halt
	.data	halt,halt,halt,halt,halt,halt,halt,halt
	.data	wadds,wadcs,wsubs,wcmp,weors,worrs,wands,wtst
	.data	wmuls,wmlas,wdivs,wmovs,wmvns,wswis,wldm,wstm
	.data	wldrs,wstrs,wldus,wstus,wadr
	
;;; DO NOT WRITE ANYTHING BELOW THIS LINE
wregs:
wr0:	.data	0
wr1:	.data	0
wr2:	.data	0
wr3:	.data	0
wr4:	.data	0
wr5:	.data	0
wr6:	.data	0
wr7:	.data	0
wr8:	.data	0
wr9:	.data	0
wr10:	.data	0
wfp:	
wr11:	.data	0
wr12:	.data	0
wsp:	
wr13:	.data	0x00ffffff
wlr:	
wr14:	.data	0
wpc:	
wr15:	.data	0

warm:	
