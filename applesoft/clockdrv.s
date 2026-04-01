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
        jsr     GetTimeMegaFlashA2
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

; A2Speed wrapper for SPF MegaFlash time read:
; SPF returns a first byte in 4 ms units and currently zeros TimeNow+3.
; Convert that 0..249 range to exact hundredths via a lookup table.
GetTimeMegaFlashA2:
        lda     #MF_CMD_GETPRODOS25TIME
        sta     MF_CMDSTATUS
@mf_wait:
        bit     MF_CMDSTATUS
        bmi     @mf_wait
        bvs     @mf_done
        lda     MF_PARAM                ; t4ms (0..249 in 4 ms units)
        sta     MFTimeA2+0
        lda     MF_PARAM                ; seconds
        sta     MFTimeA2+1
        lda     MF_PARAM                ; time lo
        sta     MFTimeA2+2
        lda     MF_PARAM                ; time hi
        sta     MFTimeA2+3
        lda     MF_PARAM                ; date lo - discard
        lda     MF_PARAM                ; date hi - discard
        ldx     MFTimeA2+0
        lda     MegaFlashHundredths,x
        sta     TimeNow+3               ; Hundredths
        lda     MFTimeA2+2
        and     #$3F
        sta     TimeNow+1               ; Minutes
        lda     MFTimeA2+2
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     MFTimeA2+0              ; temp: hour low 2 bits
        lda     MFTimeA2+3
        and     #$07
        asl     a
        asl     a
        ora     MFTimeA2+0
        sta     TimeNow                 ; Hours
        lda     MFTimeA2+1
        sta     TimeNow+2               ; Seconds
@mf_done:
        rts

MFTimeA2:
        .res    4

MegaFlashHundredths:
        .repeat 250, I
        .byte   (I * 4) / 10
        .endrepeat

CLOCK_KIND:
        .res    1
ZPSAVE:
        .res    256
TimeNow:
        .res    4
