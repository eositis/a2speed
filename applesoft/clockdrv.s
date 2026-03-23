; A2SPEED clock driver for Applesoft (ProDOS/BASIC.SYSTEM)
; Safer wrapper around SPF gettime routines.
;
; Entry points (load at $7000; see clockdrv.lst/map):
;   $7000 CLOCK_INIT  - detect/select backend (no self-modifying GetTime vector)
;   $704E CLOCK_READ  - sample selected backend into TimeNow (see clockdrv.lst; sync A2SPEED.bas)
;
; Detection priority (first match wins):
;   1 IIgs   2 ROMX   3 MegaFlash   4 No-Slot Clock
;   5 TimeMaster II H.O. (slot ROM id $4D/$D9 at Cn00-01; AE ROM Rev 5)
; Thunderclock is not selected: 1 s resolution is too coarse for A2Speed wall timing.
; TimeMaster read still uses SPF GetTimeThunderclock (BCD slot path; name is historical).

        UTILPTR = $07

        KIND_NONE   = 0
        KIND_GS     = 1
        KIND_ROMX   = 2
        KIND_MEGA   = 3
        KIND_NSC    = 4
        KIND_TM     = 5

        .segment "CODE"
        .export CLOCK_KIND, TimeNow, ClockSlot

CLOCK_INIT:
        jsr     SaveZP
        lda     #KIND_NONE
        sta     CLOCK_KIND

        ; IIgs
        sec
        jsr     $FE1F
        bcs     @chk_romx
        lda     #KIND_GS
        sta     CLOCK_KIND
        jmp     @done_init

@chk_romx:
        jsr     CheckForROMX
        bcs     @chk_mega
        lda     #KIND_ROMX
        sta     CLOCK_KIND
        jmp     @done_init

@chk_mega:
        jsr     CheckForMegaFlash
        bcs     @chk_nsc
        lda     #KIND_MEGA
        sta     CLOCK_KIND
        jmp     @done_init

@chk_nsc:
        jsr     CheckForNoSlotClock
        bcs     @chk_tm
        lda     #KIND_NSC
        sta     CLOCK_KIND
        jmp     @done_init

@chk_tm:
        jsr     CheckForTimeMaster
        bcs     @done_init
        lda     #KIND_TM
        sta     CLOCK_KIND
        jmp     @done_init

@done_init:
        jsr     RestoreZP
        rts

CLOCK_READ:
        jsr     SaveZP
        lda     CLOCK_KIND
        cmp     #KIND_GS
        bne     @r2
        jsr     GetTimeGS
        jmp     @done_read
@r2:
        cmp     #KIND_ROMX
        bne     @r3
        jsr     GetTimeROMX
        jmp     @done_read
@r3:
        cmp     #KIND_MEGA
        bne     @r4
        jsr     GetTimeMegaFlash
        jmp     @done_read
@r4:
        cmp     #KIND_NSC
        bne     @r5
        jsr     GetTimeNSC
        jmp     @done_read
@r5:
        cmp     #KIND_TM
        bne     @done_read
        jsr     GetTimeTimeMaster
        jmp     @done_read

@done_read:
        jsr     RestoreZP
        rts

GetTimeTimeMaster:
        jmp     GetTimeThunderclock

SaveZP:
        ldx     #$00
@sloop:
        lda     $00,x
        sta     ZPSAVE,x
        inx
        bne     @sloop
        rts

RestoreZP:
        ldx     #$00
@rloop:
        lda     ZPSAVE,x
        sta     $00,x
        inx
        bne     @rloop
        rts

; Applied Engineering TimeMaster II H.O. — ROM id at Cn00-01 ($4D $D9), not Thunder $08 $78 $28.
CheckForTimeMaster:
        sec
        ldx     #$07
@tmloop:
        clc
        txa
        adc     #$c0
        sta     UTILPTR+1
        lda     #$00
        sta     UTILPTR
        ldy     #$00
        lda     (UTILPTR),y
        cmp     #$4D
        bne     @tmnext
        iny
        lda     (UTILPTR),y
        cmp     #$D9
        bne     @tmnext
        stx     ClockSlot
        clc
        rts
@tmnext:
        dex
        bne     @tmloop
        sec
        rts

        .include "gettime.asm"

CLOCK_KIND:
        .res    1
ZPSAVE:
        .res    256
TimeNow:
        .res    4
