10 REM A2SPEED - Apple II Performance Test (Applesoft)
20 REM Timing via SPF-compatible clock driver (elapsed seconds)
30 HOME
31 REM Save default HIMEM. Lower it after BLOADs but before string-heavy setup.
32 HM = PEEK(115) + 256 * PEEK(116)
34 PRINT CHR$(4)"PR#0"
35 PRINT CHR$(4)"PR#3"
36 REM 80-column display (IIe extended 80-col card, usually slot 3)
37 HOME
38 PRINT "A2SPEED - Apple II Benchmarks (Applesoft)"
39 PRINT "=============================================="
40 REM Driver load $7000; CD/RD/CK/CS/TN MUST match applesoft/clockdrv.lst after each ca65/ld65 build
45 CD = 28672: RD = 28750: TN = 30416: CK = 30159: CS = 29623
46 CA = 24576: PA = 24579: REM Applesoft: only 1st 2 name chars matter — ML/MLP both "ML"; CA/PA differ
50 GOTO 400
55 REM (unused)
100 REM Timed CPU speed: GOSUB 102. SN=25000 empty FOR/NEXT; REFI=iter/s measured reference machine
102 SN = 25000: REFI = 481
103 GOSUB 130: T1 = T
104 FOR I = 1 TO SN: NEXT I
105 GOSUB 130: T2 = T: GOSUB 140
106 IF E <= 0 THEN PRINT "Timed speed: (invalid elapsed)": RETURN
107 SP = SN / E
108 MHZ = SP / REFI * 1.02
109 MHZ = INT(MHZ * 100 + 0.5) / 100
110 PRINT "Timed speed: "; INT(SP + 0.5); " iter/s, ~"; MHZ; " MHz eq (REFI "; REFI; ")"
111 RETURN
130 REM ----- Read time as decimal seconds (CALL CLOCK_READ -> TimeNow) -----
131 CALL RD
132 T = PEEK(TN) * 3600 + PEEK(TN + 1) * 60 + PEEK(TN + 2) + PEEK(TN + 3) / 100
135 RETURN
140 REM ----- Elapsed seconds (T1,T2 from GOSUB 130); sets E, EL -----
145 E = T2 - T1
146 IF E < 0 THEN IF E > -1800 THEN E = -E ELSE E = E + 86400
147 EL = INT(E * 100 + 0.5) / 100
150 REM EL = nearest 0.01 s; small negative E uses -E; else +86400 midnight wrap.
155 RETURN
160 REM ----- Print wall time T as HH:MM:SS.ss (nearest hundredth second) -----
162 TH = INT(T / 3600)
164 TM = INT((T - TH * 3600) / 60)
166 TS = T - TH * 3600 - TM * 60
168 TSD = INT(TS * 100 + 0.5) / 100
170 PRINT TH;":";TM;":";TSD;
172 RETURN
173 REM ----- T -> T$ (HH:MM:SS.s); same as 160, for LEN-based columns (POS fails in 80-col)
174 TH = INT(T / 3600)
175 TM = INT((T - TH * 3600) / 60)
176 TS = T - TH * 3600 - TM * 60
177 TSD = INT(TS * 100 + 0.5) / 100
178 T$ = STR$(TH) + ":" + STR$(TM) + ":" + STR$(TSD)
182 RETURN
184 IF T2 >= T1 THEN T = T2: GOTO 192
185 IF T1 - T2 >= 1800 THEN T = T2: GOTO 192
186 T = T1 + E
187 IF T >= 86400 THEN T = T - 86400
192 RETURN
194 REM ----- One row: fixed cols; label 32 + AppleSoft + ML + two ref %% cols -----
195 P1$ = MID$(L$ + PS32$, 1, 32)
196 SF = ES: GOSUB 226: A1$ = TF$
197 SF = EM: GOSUB 226: A2$ = TF$
198 AV = ES: RV = RA: GOSUB 240: A3$ = PF$
199 AV = EM: RV = RM: GOSUB 240: A4$ = PF$
200 PRINT P1$; A1$; A2$; A3$; A4$
201 RETURN
205 REM ----- Set stock Apple IIc reference times for current BO -----
206 IF BO = 1 THEN RA = 33.36: RM = .22: RETURN
207 IF BO = 2 THEN RA = 37.36: RM = 2.1: RETURN
208 IF BO = 3 THEN RA = 28.99: RM = 3.9: RETURN
209 IF BO = 4 THEN RA = 28.82: RM = .15: RETURN
210 IF BO = 5 THEN RA = 24.52: RM = .11: RETURN
211 IF BO = 6 THEN RA = 19.69: RM = .3: RETURN
212 IF BO = 7 THEN RA = 16.19: RM = 1.68: RETURN
213 IF BO = 8 THEN RA = 25.08: RM = 3.2: RETURN
214 RA = 0: RM = 0: RETURN
215 REM ----- ML bench: BO,N,M; POKE PA..; CALL CA; sets EM (EL2 aliases EL in Applesoft)
220 POKE PA, BO
221 POKE PA + 1, N - 256 * INT(N / 256): POKE PA + 2, INT(N / 256)
222 POKE PA + 3, M - 256 * INT(M / 256): POKE PA + 4, INT(M / 256)
223 GOSUB 130: T3 = T: CALL CA: GOSUB 130: T4 = T
224 T1 = T3: T2 = T4: GOSUB 140: EM = EL
225 RETURN
226 REM ----- TF$: pad STR$(SF)+" s" to width CW (for aligned AppleSoft / ML columns) -----
227 TF$ = STR$(SF) + " s"
228 IF LEN(TF$) > CW THEN TF$ = MID$(TF$, LEN(TF$) - CW + 1, CW)
229 IF LEN(TF$) < CW THEN TF$ = " " + TF$: GOTO 229
230 RETURN
240 REM ----- PF$: reference performance = REF / ACTUAL * 100 (higher is faster) -----
241 IF AV <= 0 OR RV <= 0 THEN PF$ = "      --": RETURN
242 PV = INT(RV / AV * 100 + 0.5)
243 PF$ = STR$(PV) + "%"
244 IF LEN(PF$) > 8 THEN PF$ = MID$(PF$, LEN(PF$) - 7, 8)
245 IF LEN(PF$) < 8 THEN PF$ = " " + PF$: GOTO 245
246 RETURN
400 REM ========== CLOCK DRIVER (ProDOS) ==========
405 PRINT : PRINT "--- CLOCK / DRIVER ---"
418 PRINT CHR$(4)"BLOAD BENCHML,A$6000"
420 PRINT CHR$(4)"BLOAD CLOCKDRV,A$7000"
421 REM After BLOADs, lower HIMEM before allocating strings so BASIC stays below BENCHML.
422 HIMEM: 24576
423 PS32$ = "": FOR IX = 1 TO 32: PS32$ = PS32$ + " ": NEXT IX: CW = 12: REM pad string; time column width
424 REM Do not raise HIMEM to $6FFF — Applesoft heap/string space will overwrite BENCHML.
425 REM CLOCK_INIT: IIgs, ROMX, MegaFlash, NoSlotClock, TimeMaster (order)
426 CALL CD
430 K = PEEK(CK)
432 TS = PEEK(CS)
435 IF K = 1 THEN PRINT "Clock backend: IIgs built-in - ready"
440 IF K = 2 THEN PRINT "Clock backend: ROMX - ready"
445 IF K = 3 THEN PRINT "Clock backend: MegaFlash - ready"
450 IF K = 4 THEN PRINT "Clock backend: No-Slot Clock - ready"
455 IF K = 5 THEN PRINT "Clock backend: TimeMaster II slot ";TS;" - ready"
465 IF K = 0 THEN PRINT "Clock backend: none detected - wall time unavailable"
468 REM ----- Processor / machine (IIgs from clock K; else ROM ID $FBB3 = 64435) -----
469 REM MHz: IIgs 65816 ~2.8 MHz; NTSC 6502/65C02 ~1.02 MHz (14.31818/14); unknown ~1.0
470 IF K = 1 THEN PRINT "Processor: 65816 (Apple IIgs) ~2.8 MHz est."
471 IF K = 1 THEN GOTO 490
472 MB = PEEK(64435)
473 MACH$ = "Apple II family"
474 CPU$ = "6502"
475 MH$ = "~1.0 MHz est."
476 IF MB = 6 THEN MACH$ = "Apple IIe": CPU$ = "65C02": MH$ = "~1.02 MHz est."
477 IF MB = 234 THEN MACH$ = "Apple II Plus": MH$ = "~1.02 MHz est."
478 IF MB = 0 THEN MACH$ = "Apple IIc (or IIc+)": CPU$ = "65C02": MH$ = "~1.02 MHz est."
485 PRINT "Processor: ";CPU$;" (";MACH$;") ";MH$
490 IF K = 0 THEN PRINT "Timed speed: N/A (no wall clock)": GOTO 500
491 GOSUB 102
492 GOTO 500
500 REM ========== MATH BENCHMARKS ==========
505 PRINT : PRINT "--- MATH ---"
508 REM Same widths as GOSUB 194: 32 + 12 + 12 + 8 + 8
509 H1$ = MID$("TEST" + PS32$, 1, 32): H2$ = "   AppleSoft": H3$ = "          ML": H4$ = "  A Ref%": H5$ = "  M Ref%": PRINT H1$; H2$; H3$; H4$; H5$
515 N = 5000
520 GOSUB 130: T1 = T
525 A = 0: FOR I = 1 TO N: A = A + 1: NEXT I
532 GOSUB 130: T2 = T: GOSUB 140: GOSUB 184
533 ES = EL: BO = 1: GOSUB 220: GOSUB 205
534 L$ = "Integer add (1 to " + STR$(N) + ")": GOSUB 194
545 GOSUB 130: T1 = T
550 X = 0: FOR I = 1 TO N: X = X + 1.0: NEXT I
557 GOSUB 130: T2 = T: GOSUB 140: GOSUB 184
558 ES = EL: BO = 2: GOSUB 220: GOSUB 205
559 L$ = "Float add (1 to " + STR$(N) + ")": GOSUB 194
565 N = 1500
572 GOSUB 130: T1 = T
575 Y = 1: FOR I = 1 TO N: Y = Y * 1.001: NEXT I
582 GOSUB 130: T2 = T: GOSUB 140: GOSUB 184
583 ES = EL: BO = 3: GOSUB 220: GOSUB 205
584 L$ = "Float mul (1.001^" + STR$(N) + ")": GOSUB 194
595 M = 500
598 GOSUB 130: T1 = T
600 FOR I = 1 TO M: Z = SIN(1): Z = COS(1): NEXT I
607 GOSUB 130: T2 = T: GOSUB 140: GOSUB 184
608 ES = EL: BO = 4: GOSUB 220: GOSUB 205
609 L$ = "SIN/COS x" + STR$(M): GOSUB 194
620 N = 500
622 GOSUB 130: T1 = T
625 FOR I = 1 TO N: Z = SQR(2): NEXT I
632 GOSUB 130: T2 = T: GOSUB 140: GOSUB 184
633 ES = EL: BO = 5: GOSUB 220: GOSUB 205
634 L$ = "SQR(2) x" + STR$(N): GOSUB 194
640 REM ========== COMPUTE BENCHMARKS ==========
645 PRINT : PRINT "--- COMPUTE ---"
648 H1$ = MID$("TEST" + PS32$, 1, 32): H2$ = "   AppleSoft": H3$ = "          ML": H4$ = "  A Ref%": H5$ = "  M Ref%": PRINT H1$; H2$; H3$; H4$; H5$
655 N = 10000
656 GOSUB 130: T1 = T
665 FOR I = 1 TO N: NEXT I
677 GOSUB 130: T2 = T: GOSUB 140: GOSUB 184
678 ES = EL: BO = 6: GOSUB 220: GOSUB 205
679 L$ = "Empty loop " + STR$(N): GOSUB 194
695 DIM A(255): N = 10
702 GOSUB 130: T1 = T
715 FOR J = 1 TO N: FOR I = 0 TO 255: A(I) = I: NEXT I: NEXT J
727 GOSUB 130: T2 = T: GOSUB 140: GOSUB 184
728 ES = EL: BO = 7: GOSUB 220: GOSUB 205
729 L$ = "Array fill 256 x" + STR$(N): GOSUB 194
742 GOSUB 130: T1 = T
745 S = 0
755 FOR J = 1 TO N: S = 0: FOR I = 0 TO 255: S = S + A(I): NEXT I: NEXT J
767 GOSUB 130: T2 = T: GOSUB 140: GOSUB 184
768 ES = EL: BO = 8: GOSUB 220: GOSUB 205
769 L$ = "Array sum 256 x" + STR$(N): GOSUB 194
785 REM ========== SUMMARY ==========
791 REM ProDOS cleanup: restore HIMEM (115/116), PR#0, CLOSE (avoids NO BUFFERS on re-RUN)
792 POKE 115, HM - INT(HM / 256) * 256
793 POKE 116, INT(HM / 256)
794 PRINT CHR$(4)"PR#0"
795 PRINT CHR$(4)"CLOSE"
800 END
