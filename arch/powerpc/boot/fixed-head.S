#include "ppc_asm.h"

/* TODO: how to include arch/powerpc/include/asm/reg_booke.h */
#define SPRN_L1CFG0        0x203
#define L1CFG0_CSIZE 0xff

.macro load_const rD, expr
    lis \rD, \expr@h
    ori \rD, \rD, \expr@l
.endm

	.text
	.globl _zimage_start
_zimage_start:
#ifdef CONFIG_E500
	mfmsr   r10
	rlwinm  r10,r10,0,~(1<<15)        /* Clear MSR_EE */
	sync
	mtmsr   r10
	isync
#endif

    /* find where MOTLoad has left us */
    bl startx
startx:
    mflr r0                /* holds actual address of 'startx' */
    load_const r1, startx  /* desired location of 'startx' */

    sub. r26, r0, r1     /* actual - desired, aka.  src - dest */

    /* short circuit if we are already running form our desired location */
    cmpw r26, 0
    beq _zimage_start_lib

    mfspr r25, SPRN_L1CFG0
    andi. r25, r25, L1CFG0_CSIZE /* L1 cache line size */

    /* copy movecode() above max(src, dest)+size */

    load_const r5, _end /* dest+size */

    cmpwi r26, 0
    blt usedest
    /* src >= dest */
    add r5, r5, r26 /* src+size */
usedest:

    /* skip to start of next cache line */
    subi r3, r25, 1
    or r5, r5, r3
    addi r5, r5, 1

    load_const r3, codemove
    add r3, r3, r26 /* actual codemove */

    load_const r4, end_codemove - codemove

    mr r8, r5 /* save pointer to relocator codemove */
    bl codemove

    /* jump to codemove() to copy ourself to final destination.
     * relocator must jump to final destination as this location
     * may be clobbered.
     */

    load_const r5, _start /* dest */
    load_const r4, _end
    sub r4, r4, r5  /* # of bytes */
    add r3, r5, r26 /* src */

    mtctr r8 /* branch to relocator (copy of codemove() ) */
    load_const r8, atfinal /* which returns to atfinal in final location */
    mtlr r8

    bctr

atfinal:

	b	_zimage_start_lib

/* codemove() (memmove() with L1 icache clear)
 *
 * r3 - base address of code to move
 * r4 - size of code to move
 * r5 - address of destination
 *
 * clobbers
 *  ctr
 *  cr0
 *  r3 - r7
 */
codemove:
    cmpwi r4, 0
    beqlr-

    /* save for later use w/ L1 */
    mr r6, r4
    mr r7, r5

    /* add one as 'bdnz' equivalent is if(--ctr) */
    addi r4, r4, 1
    mtctr r4
    subi r4, r4, 1

    cmpw r5, r3
    beq relcd /* dest == src */

    bgt down

up: /* dest < src */
    subi r3, r3, 1
    subi r5, r5, 1

uploop:
    lbzu r4, 1(r3)
    stbu r4, 1(r5)
    bdnz+ uploop

    b relcd
down: /* dest > src */
    add r3, r3, r4
    add r5, r5, r4
    addi r3, r3, 1
    addi r5, r5, 1

downloop:
    lbzu r4, -1(r3)
    stbu r4, -1(r5)
    bdnz+ downloop

relcd:
    sync
    isync

    /* invalidate destination in L1 instruction cache */
    add r3, r7, r6 /* dest+size */
    mr r5, r7       /* dest */

iline:
    dcbst 0, r5
    sync
    icbi 0, r5
    isync
    add r5, r5, r25
    cmpw r5, r3
    blt+ iline

    blr
end_codemove:
