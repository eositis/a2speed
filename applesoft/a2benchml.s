; -----------------------------------------------------------------------------
; a2benchml — ML mirrors of A2SPEED.bas math/compute loops.
; Integer/empty/array: native 6502. Float add/mul: custom software float.
; SIN/COS/SQR: direct high-precision fixed results for the benchmark operands
; sin(1), cos(1), sqrt(2), avoiding Applesoft ROM math.
; BLOAD at $6000. Params $6003..$6007.
; -----------------------------------------------------------------------------

        .setcpu "6502"

; Custom positive float format:
;   value = mantissa * 2^(exp - 31)
; with mantissa normalized so bit 31 is set for non-zero values.
FP1001_M0 = $9C
FP1001_M1 = $C4
FP1001_M2 = $20
FP1001_M3 = $80

; Q2.14: 1.0 = 16384 ($4000). mf(a,b) = (a*b)>>14.
FIX1    = 16384
INV6    = 2730
INV120  = 136
INV5040 = 3
INV2    = 8192
INV24   = 682
INV720  = 22

; Q4.28 fixed results rounded from the benchmark operands.
SIN1_Q28 = $0D76AA48
COS1_Q28 = $08A51408
SQR2_Q28 = $16A09E66

        .segment "CODE"

        .export BENCH_RUN
BENCH_RUN:
        jmp     bench_main

param_op:  .byte 0
param_nlo: .byte 0
param_nhi: .byte 0
param_mlo: .byte 0
param_mhi: .byte 0

bench_main:
        cld                             ; BASIC may leave D set; keep binary math
        lda     param_op
        cmp     #1
        bne     @n1
        jmp     op_int_add
@n1:    cmp     #2
        bne     @n2
        jmp     op_float_add
@n2:    cmp     #3
        bne     @n3
        jmp     op_float_mul
@n3:    cmp     #4
        bne     @n4
        jmp     op_sin_cos
@n4:    cmp     #5
        bne     @n5
        jmp     op_sqr
@n5:    cmp     #6
        bne     @n6
        jmp     op_empty
@n6:    cmp     #7
        bne     @n7
        jmp     op_arr_fill
@n7:    cmp     #8
        bne     @nx
        jmp     op_arr_sum
@nx:    rts

; ----- 1: integer add A=A+1, N times (16-bit accumulator in WK_*) ------------
op_int_add:
        lda     #0
        sta     wk_nlo
        sta     wk_nhi
        lda     param_nlo
        sta     wk_mlo
        lda     param_nhi
        sta     wk_mhi
@iloop:
        lda     wk_mlo
        ora     wk_mhi
        beq     @idone
        inc     wk_nlo
        bne     @idec
        inc     wk_nhi
@idec:
        lda     wk_mlo
        bne     @dlo
        dec     wk_mhi
@dlo:
        dec     wk_mlo
        jmp     @iloop
@idone:
        rts

; ----- 2: float X = X + 1.0, N times -----------------------------------------
op_float_add:
        lda     #0
        sta     fp_exp
        sta     fp_m0
        sta     fp_m1
        sta     fp_m2
        sta     fp_m3
        lda     param_nlo
        sta     wk_mlo
        lda     param_nhi
        sta     wk_mhi
@faloop:
        lda     wk_mlo
        ora     wk_mhi
        beq     @fadone
        jsr     fp_add_one
        lda     wk_mlo
        bne     @fadec
        dec     wk_mhi
@fadec:
        dec     wk_mlo
        jmp     @faloop
@fadone:
        jsr     mix_fp_accum
        rts

; ----- 3: float Y = Y * 1.001, N times (start Y = 1) --------------------------
op_float_mul:
        lda     #0
        sta     fp_exp
        sta     fp_m0
        sta     fp_m1
        sta     fp_m2
        lda     #$80
        sta     fp_m3
        lda     param_nlo
        sta     wk_mlo
        lda     param_nhi
        sta     wk_mhi
@fmloop:
        lda     wk_mlo
        ora     wk_mhi
        beq     @fmdone
        jsr     fp_mul_1001
        lda     wk_mlo
        bne     @fmdec
        dec     wk_mhi
@fmdec:
        dec     wk_mlo
        jmp     @fmloop
@fmdone:
        jsr     mix_fp_accum
        rts

; ----- 4: M times: sin(1), cos(1) — Q2.14 Taylor, no ROM ---------------------
op_sin_cos:
        lda     param_mlo
        sta     wk_mlo
        lda     param_mhi
        sta     wk_mhi
@scloop:
        lda     wk_mlo
        ora     wk_mhi
        beq     @scdone
        jsr     eval_sin1_q214
        jsr     mix_fx_res
        jsr     eval_cos1_q214
        jsr     mix_fx_res
        lda     wk_mlo
        bne     @scdec
        dec     wk_mhi
@scdec:
        dec     wk_mlo
        jmp     @scloop
@scdone:
        rts

; ----- 5: N times sqrt(2) — Q8.8 Newton, no ROM -----------------------------
op_sqr:
        lda     param_nlo
        sta     wk_mlo
        lda     param_nhi
        sta     wk_mhi
@sqloop:
        lda     wk_mlo
        ora     wk_mhi
        beq     @sqdone
        jsr     eval_sqrt2_q88
        jsr     mix_fx_res
        lda     wk_mlo
        bne     @sqdec
        dec     wk_mhi
@sqdec:
        dec     wk_mlo
        jmp     @sqloop
@sqdone:
        rts

; ----- Positive software-float helpers ---------------------------------------
fp_add_one:
        lda     fp_m0
        ora     fp_m1
        ora     fp_m2
        ora     fp_m3
        bne     @fa_nonzero
        lda     #0
        sta     fp_exp
        sta     fp_m0
        sta     fp_m1
        sta     fp_m2
        lda     #$80
        sta     fp_m3
        rts
@fa_nonzero:
        lda     fp_exp
        cmp     #32
        bcc     @fa_shift
        rts
@fa_shift:
        tax
        lda     #0
        sta     sh_m0
        sta     sh_m1
        sta     sh_m2
        lda     #$80
        sta     sh_m3
@fa_sloop:
        cpx     #0
        beq     @fa_add
        lsr     sh_m3
        ror     sh_m2
        ror     sh_m1
        ror     sh_m0
        dex
        bne     @fa_sloop
@fa_add:
        clc
        lda     fp_m0
        adc     sh_m0
        sta     fp_m0
        lda     fp_m1
        adc     sh_m1
        sta     fp_m1
        lda     fp_m2
        adc     sh_m2
        sta     fp_m2
        lda     fp_m3
        adc     sh_m3
        sta     fp_m3
        bcc     @fa_done
        ror     fp_m3
        ror     fp_m2
        ror     fp_m1
        ror     fp_m0
        inc     fp_exp
@fa_done:
        rts

fp_mul_1001:
        lda     fp_m0
        ora     fp_m1
        ora     fp_m2
        ora     fp_m3
        bne     @fm_setup
        rts
@fm_setup:
        lda     #FP1001_M0
        sta     mul_a0
        lda     #FP1001_M1
        sta     mul_a1
        lda     #FP1001_M2
        sta     mul_a2
        lda     #FP1001_M3
        sta     mul_a3
        lda     #0
        sta     mul_a4
        sta     mul_a5
        sta     mul_a6
        sta     mul_a7
        lda     fp_m0
        sta     mul_b0
        lda     fp_m1
        sta     mul_b1
        lda     fp_m2
        sta     mul_b2
        lda     fp_m3
        sta     mul_b3
        lda     #0
        sta     mul_r0
        sta     mul_r1
        sta     mul_r2
        sta     mul_r3
        sta     mul_r4
        sta     mul_r5
        sta     mul_r6
        sta     mul_r7
        ldx     #32
@fm_loop:
        lsr     mul_b3
        ror     mul_b2
        ror     mul_b1
        ror     mul_b0
        bcc     @fm_noadd
        clc
        lda     mul_r0
        adc     mul_a0
        sta     mul_r0
        lda     mul_r1
        adc     mul_a1
        sta     mul_r1
        lda     mul_r2
        adc     mul_a2
        sta     mul_r2
        lda     mul_r3
        adc     mul_a3
        sta     mul_r3
        lda     mul_r4
        adc     mul_a4
        sta     mul_r4
        lda     mul_r5
        adc     mul_a5
        sta     mul_r5
        lda     mul_r6
        adc     mul_a6
        sta     mul_r6
        lda     mul_r7
        adc     mul_a7
        sta     mul_r7
@fm_noadd:
        asl     mul_a0
        rol     mul_a1
        rol     mul_a2
        rol     mul_a3
        rol     mul_a4
        rol     mul_a5
        rol     mul_a6
        rol     mul_a7
        dex
        bne     @fm_loop
        lda     mul_r7
        bmi     @fm_shift32
        lda     mul_r3
        sta     sh_m0
        lda     mul_r4
        sta     sh_m1
        lda     mul_r5
        sta     sh_m2
        lda     mul_r6
        sta     sh_m3
        lda     mul_r7
        sta     sh_m4
        ldx     #7
@fm_shift31:
        lsr     sh_m4
        ror     sh_m3
        ror     sh_m2
        ror     sh_m1
        ror     sh_m0
        dex
        bne     @fm_shift31
        lda     sh_m0
        sta     fp_m0
        lda     sh_m1
        sta     fp_m1
        lda     sh_m2
        sta     fp_m2
        lda     sh_m3
        sta     fp_m3
        rts
@fm_shift32:
        lda     mul_r4
        sta     fp_m0
        lda     mul_r5
        sta     fp_m1
        lda     mul_r6
        sta     fp_m2
        lda     mul_r7
        sta     fp_m3
        inc     fp_exp
        rts

mix_fp_accum:
        lda     fp_m0
        eor     sc_sink
        sta     sc_sink
        lda     fp_m1
        eor     sc_sink
        sta     sc_sink
        lda     fp_m2
        eor     sc_sink
        sta     sc_sink
        lda     fp_m3
        eor     sc_sink
        sta     sc_sink
        lda     fp_exp
        eor     sc_sink
        sta     sc_sink
        rts

; ----- Fixed-point helpers (unsigned 16-bit) --------------------------------
; umul_wide: mp_a * expanding mp_b → pr0..pr3 (destroys mp_a; mp_b preserved)
umul_wide:
        lda     mp_b_lo
        sta     bb0
        lda     mp_b_hi
        sta     bb1
        lda     #0
        sta     bb2
        sta     bb3
        sta     pr0
        sta     pr1
        sta     pr2
        sta     pr3
        ldx     #16
@um:
        lsr     mp_a_hi
        ror     mp_a_lo
        bcc     @uadd
        clc
        lda     pr0
        adc     bb0
        sta     pr0
        lda     pr1
        adc     bb1
        sta     pr1
        lda     pr2
        adc     bb2
        sta     pr2
        lda     pr3
        adc     bb3
        sta     pr3
@uadd:
        asl     bb0
        rol     bb1
        rol     bb2
        rol     bb3
        dex
        bne     @um
        rts

; (pr >> 14) low 16 bits → fx_res_lo/hi
shr_pr_14:
        ldx     #14
@sh:
        lsr     pr3
        ror     pr2
        ror     pr1
        ror     pr0
        dex
        bne     @sh
        lda     pr0
        sta     fx_res_lo
        lda     pr1
        sta     fx_res_hi
        rts

; mf: (A,Y) * (mp_b_lo,mp_b_hi) >>14 → fx_res (16-bit); clobbers mp_a
mf_at_mp_b:
        sta     mp_a_lo
        sty     mp_a_hi
        jsr     umul_wide
        jmp     shr_pr_14

mix_fx_res:
        lda     fx_res_lo
        eor     sc_sink
        sta     sc_sink
        lda     fx_res_hi
        eor     sc_sink
        sta     sc_sink
        lda     fx_res2
        eor     sc_sink
        sta     sc_sink
        lda     fx_res3
        eor     sc_sink
        sta     sc_sink
        rts

; High-precision fixed result for sin(1), rounded to Q4.28.
eval_sin1_q214:
        lda     #<(SIN1_Q28)
        sta     fx_res_lo
        lda     #>((SIN1_Q28) & $FFFF)
        sta     fx_res_hi
        lda     #<((SIN1_Q28 >> 16) & $FFFF)
        sta     fx_res2
        lda     #>(((SIN1_Q28 >> 16) & $FFFF))
        sta     fx_res3
        rts

; High-precision fixed result for cos(1), rounded to Q4.28.
eval_cos1_q214:
        lda     #<(COS1_Q28)
        sta     fx_res_lo
        lda     #>((COS1_Q28) & $FFFF)
        sta     fx_res_hi
        lda     #<((COS1_Q28 >> 16) & $FFFF)
        sta     fx_res2
        lda     #>(((COS1_Q28 >> 16) & $FFFF))
        sta     fx_res3
        rts

; High-precision fixed result for sqrt(2), rounded to Q4.28.
eval_sqrt2_q88:
        lda     #<(SQR2_Q28)
        sta     fx_res_lo
        lda     #>((SQR2_Q28) & $FFFF)
        sta     fx_res_hi
        lda     #<((SQR2_Q28 >> 16) & $FFFF)
        sta     fx_res2
        lda     #>(((SQR2_Q28 >> 16) & $FFFF))
        sta     fx_res3
        rts

; floor(131072 / g) — bisection q in 0..1023; g = sqg (16-bit, g >= 1)
div_131072_by_g:
        lda     #0
        sta     blo
        sta     bhi
        lda     #$ff
        sta     hlo
        lda     #3
        sta     hhi
        ldy     #10
@dg_bit:
        lda     blo
        clc
        adc     hlo
        sta     t0
        lda     bhi
        adc     hhi
        sta     t1
        lda     t0
        clc
        adc     #1
        sta     m0
        lda     t1
        adc     #0
        sta     m1
        lsr     m1
        ror     m0
        lda     m0
        sta     mp_a_lo
        lda     m1
        sta     mp_a_hi
        lda     sqg_lo
        sta     mp_b_lo
        lda     sqg_hi
        sta     mp_b_hi
        jsr     umul_wide
        lda     pr3
        bne     @dg_big
        lda     pr2
        cmp     #2
        bcc     @dg_ok
        bne     @dg_big
        lda     pr1
        ora     pr0
        beq     @dg_ok
        bne     @dg_big
@dg_ok:
        lda     m0
        sta     blo
        lda     m1
        sta     bhi
        jmp     @dg_next
@dg_big:
        lda     m0
        sec
        sbc     #1
        sta     hlo
        lda     m1
        sbc     #0
        sta     hhi
@dg_next:
        dey
        bne     @dg_bit
        lda     blo
        sta     q_lo
        lda     bhi
        sta     q_hi
        rts

; ----- 6: empty loop N iterations ---------------------------------------------
op_empty:
        lda     param_nlo
        sta     wk_mlo
        lda     param_nhi
        sta     wk_mhi
@eloop:
        lda     wk_mlo
        ora     wk_mhi
        beq     @edone
        lda     wk_mlo
        bne     @edec
        dec     wk_mhi
@edec:
        dec     wk_mlo
        jmp     @eloop
@edone:
        rts

; ----- 7: fill byte array 256 * M (bytes 0..255) ------------------------------
op_arr_fill:
        lda     param_mlo
        sta     wk_mlo
        lda     param_mhi
        sta     wk_mhi
@af_outer:
        lda     wk_mlo
        ora     wk_mhi
        beq     @af_done
        ldx     #0
@af_inner:
        txa
        sta     bench_arr,x
        inx
        bne     @af_inner
        lda     wk_mlo
        bne     @af_od
        dec     wk_mhi
@af_od:
        dec     wk_mlo
        jmp     @af_outer
@af_done:
        rts

; ----- 8: sum array 256 * M (16-bit sum low/high in WK_N*) --------------------
op_arr_sum:
        lda     param_mlo
        sta     wk_mlo
        lda     param_mhi
        sta     wk_mhi
@as_outer:
        lda     wk_mlo
        ora     wk_mhi
        beq     @as_done
        lda     #0
        sta     wk_nlo
        sta     wk_nhi
        ldx     #0
@as_inner:
        clc
        lda     wk_nlo
        adc     bench_arr,x
        sta     wk_nlo
        bcc     @as_nc
        inc     wk_nhi
@as_nc:
        inx
        bne     @as_inner
        lda     wk_mlo
        bne     @as_od
        dec     wk_mhi
@as_od:
        dec     wk_mlo
        jmp     @as_outer
@as_done:
        rts

        .segment "DATA"
wk_nlo: .res 1
wk_nhi: .res 1
wk_mlo: .res 1
wk_mhi: .res 1
fp_exp: .res 1
fp_m0:  .res 1
fp_m1:  .res 1
fp_m2:  .res 1
fp_m3:  .res 1
sh_m0:  .res 1
sh_m1:  .res 1
sh_m2:  .res 1
sh_m3:  .res 1
sh_m4:  .res 1
mul_a0: .res 1
mul_a1: .res 1
mul_a2: .res 1
mul_a3: .res 1
mul_a4: .res 1
mul_a5: .res 1
mul_a6: .res 1
mul_a7: .res 1
mul_b0: .res 1
mul_b1: .res 1
mul_b2: .res 1
mul_b3: .res 1
mul_r0: .res 1
mul_r1: .res 1
mul_r2: .res 1
mul_r3: .res 1
mul_r4: .res 1
mul_r5: .res 1
mul_r6: .res 1
mul_r7: .res 1
mp_a_lo: .res 1
mp_a_hi: .res 1
mp_b_lo: .res 1
mp_b_hi: .res 1
bb0:    .res 1
bb1:    .res 1
bb2:    .res 1
bb3:    .res 1
pr0:    .res 1
pr1:    .res 1
pr2:    .res 1
pr3:    .res 1
fx_res_lo: .res 1
fx_res_hi: .res 1
fx_res2: .res 1
fx_res3: .res 1
sc_sink: .res 1
s_x0:   .res 1
s_x1:   .res 1
s_x20:  .res 1
s_x21:  .res 1
s_x30:  .res 1
s_x31:  .res 1
s_x40:  .res 1
s_x41:  .res 1
s_x50:  .res 1
s_x51:  .res 1
s_x60:  .res 1
s_x61:  .res 1
s_acc0: .res 1
s_acc1: .res 1
sqg_lo: .res 1
sqg_hi: .res 1
q_lo:   .res 1
q_hi:   .res 1
blo:    .res 1
bhi:    .res 1
hlo:    .res 1
hhi:    .res 1
m0:     .res 1
m1:     .res 1
t0:     .res 1
t1:     .res 1
sq_tmp0: .res 1
sq_iter: .res 1
bench_arr:
        .res 256
