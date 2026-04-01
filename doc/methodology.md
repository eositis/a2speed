# A2Speed test methodology and expected results

## Estimated runtime (Apple II, ~1 MHz 6502)

| Program | Estimated total runtime |
|---------|--------------------------|
| **Applesoft** (`A2SPEED`) | **~1–3 minutes** — Interpreter and ROM float are slow; SIN/COS/SQR and array ops dominate. |
| **cc65** (`A2SPEED_6502` or `A2SPEED_65C02`) | **~5–30 seconds** — Compiled code; most tests finish in a few jiffies each. With MegaFlash FPU block add a few seconds. |
| **MegaFlash FPU** (when present) | **~1–5 seconds** — 500× FADD, 500× FMUL, 500× FSQR; card does the work. |

So a **full run of all three** (Applesoft once, then both cc65 binaries) on a stock Apple II is roughly **2–5 minutes**. The Applesoft run is the longest; the two cc65 runs are short.

### How results are output

- **Destination**: **Screen only.** There is no file or printer output.
- **Applesoft**: Enables **80-column** output (`PR#3` after `CHR$(4)`; assumes an 80-column card in **slot 3** on IIe-class hardware). After **`CLOCKDRV`** is loaded and **`CLOCK_INIT`** runs, a single line reports **Clock backend: … - ready** (or **none detected - wall time unavailable** if no backend matched); that line means setup finished and the run continues. A **Processor:** line follows (CPU type and machine ID from ROM **`$FBB3`**; on **IIgs** the clock backend is **IIgs built-in** and the processor is shown as **65816**), plus an **MHz est.** note: **~2.8 MHz** for **IIgs** (65816), **~1.02 MHz** for typical **NTSC** 6502/65C02 models (crystal/14), **~1.0 MHz** when the machine type is unknown—not measured by this benchmark. **Timed speed** (when **`K≠0`**): one line prints **`Timed speed: N iter/s, ~M MHz eq (REFI R)`** from **`SN=25000`** Applesoft empty **`FOR/NEXT`** iterations and **`CLOCK_READ`** elapsed seconds—**iter/s** is the primary figure for **comparing accelerators**; **MHz eq** uses **REFI** (see line **102** in **`A2SPEED.bas`**). If **`K=0`**, timed speed is **N/A**. **`A2SPEED.bas`** line **45** (**`CD`/`RD`/`CK`/`CS`/`TN`**) must match **`applesoft/clockdrv.lst`** after each **`clockdrv.bin`** rebuild, or **`CALL`** / **`PEEK`** hit the wrong addresses (symptoms: **K=0** with hardware present, or crashes). Then **MATH** / **COMPUTE** sections print **three columns** (**TEST**, **AppleSoft**, **ML**): **AppleSoft** is elapsed seconds for the interpreted loop; **ML** is elapsed seconds for a **6502 routine** (`BENCHML` loaded at **`$6000`**, `CALL` entry **`$6000`**, parameters **`$6003..$6007`**) that performs the **same iteration counts** using **direct machine code** (float add/mul call **Applesoft ROM** **`FADD`/`FMULT`/`GIVAYF`**; **SIN/COS/SQR** use direct high-precision fixed results for the benchmark operands and do **not** charge **ROM** **`SIN`/`COS`/`SQR`**). Alignment uses **fixed-width columns** (test name **`MID$(…,1,32)`**, each elapsed field padded to **12** characters from **`STR$`+`" s"`**) because **`SPC` after a variable-length label does not line up** numeric columns and **`POS(0)` is wrong in 80-column mode** (primary 40-column cursor only). **One result line per test** with **ES** (Applesoft s) and **EM** (ML s) in seconds (nearest **0.01 s**). **Applesoft ignores the third+ character of variable names** (e.g. **`ML`** and **`MLP`** are the same variable, as are **`EL`** and **`EL2`**), so the program uses distinct two-letter roots **`CA`/`PA`/`BO`/`EM`** for call address, param address, bench op, and ML elapsed.
- **cc65**: Clears the screen (`clrscr()`), then uses `printf()` to stdout (console). Prints a banner (build type), section headers (`--- MATH ---`, `--- COMPUTE ---`, `--- MegaFlash FPU ---` if present), one line per test with test name, jiffies, and (when jiffies &gt; 0) `~N iter/s`, then "Times in 60 Hz jiffies..." and "Done."
- **Format**: Applesoft: **three columns** per section (**TEST** / **AppleSoft** / **ML** — elapsed seconds for interpreter vs ML). cc65: one line per test with jiffies and optional **~iter/s**. To keep results you can copy from the screen, use a screen-capture tool, or (on emulators) save the session log.
- **ProDOS re-`RUN` / “NO BUFFERS AVAILABLE”**: `A2SPEED.bas` saves **`HIMEM`** (from **`PEEK(115)+256*PEEK(116)`**) before **`PR#`**, then performs the **`BLOAD BENCHML`** and **`BLOAD CLOCKDRV`** operations while ProDOS still has room for file buffers. After those loads it sets **`HIMEM`** to **24576 (`$6000`)** so Applesoft’s heap never overlaps **`$6000`–`$6630`** (the ML image) or the clock driver at **`$7000`**. Before **`END`** the program restores **`HIMEM`** via **`POKE`** to **115/116**, sends **`PR#0`**, and **`CLOSE`**. If you **`STOP`** mid-run, **`HIMEM`** may stay lowered—**`BYE`** and re-enter BASIC or **`POKE`** **115/116** to your machine’s normal top-of-BASIC value.
- **AppleCommander `-bas` quirk**: Do not use lines that are only `nnn REM` with nothing after `REM` (blank remark lines). The tokenizer can merge the next program line into that `REM`, so the next line number disappears and `GOSUB` targets (e.g. 2000) become **?UNDEF'D STATEMENT**. Some builds also drop or mishandle **`GOTO` targets at “round” high line numbers (e.g. 700, 900)**; prefer **sequential fall-through** or **`GOTO` in the 700–799 range** to a summary block **without** relying on line **900**.
- **Applesoft `FOR`/`NEXT`**: Never execute `NEXT O` unless the matching `FOR O` ran on this path. Patterns like `IF TMS = 0 THEN FOR O = 0 TO 252` followed by unconditional `NEXT O` will **mis-nest** when `TMS <> 0`, which can hang or break at the inner `NEXT`. Use an early branch to skip the inner loop entirely, or always use a matching `FOR`/`NEXT` pair.

## Test methodology

### Timing

- **Applesoft**: Elapsed time uses **wall-clock seconds** (with hundredths when the clock exposes them). `A2SPEED.bas` loads **`CLOCKDRV`** at **`$7000`** and calls **`CLOCK_READ`** (address in line 45; must match `applesoft/clockdrv.lst` after rebuilds). See `doc/CLOCKDRV.md`. **Display** uses **EL** = **INT(E×100+0.5)/100** (nearest **0.01 s**). **Elapsed** `E = T2 - T1`: if `E` is **negative** by **less than 30 minutes** (1800 s), it is treated as a **small clock/read quirk** (e.g. slot clock vs full ZP save) and **`E` is negated**; otherwise **`E += 86400`** for **midnight** wrap in time-of-day encoding.
- **Applesoft timed speed** (accelerator comparison): The **same** Applesoft interpreter loop (**`SN`** × empty **`FOR…NEXT`**) is timed with **`CLOCK_READ`** before/after. **iter/s = SN / E** scales with effective CPU+interpreter throughput. **MHz eq** is only meaningful after **REFI** is set from a reference run (see line **102** in **`A2SPEED.bas`**); use **iter/s** for apples-to-apples accelerator comparisons without calibration.
- **cc65** (unchanged): Uses the **60 Hz jiffy counter** at zero-page **$4E–$50** where available. One jiffy ≈ 1/60 s.
- **Reported values**:
  - **Seconds** — Applesoft primary output.
  - **Jiffies** — cc65 raw ticks (lower = faster).
  - **Iter/s** (cc65 only) — approximate iterations per second: `(iterations × 60) / jiffies`.

### What is run

| Suite | Program | Tests |
|-------|---------|--------|
| **Applesoft** | `A2SPEED.bas` | ProDOS: `BLOAD BENCHML,A$6000` then `BLOAD CLOCKDRV,A$7000`. Same tests run **twice** per line (Applesoft then ML **`CALL $6000`** with params at **`$6003..$6007`** inside the BENCHML image — not high RAM near HIMEM). See `applesoft/a2benchml.s`. MATH: int/float add **5000** iters; float mul **1500**; SQR **500**; SIN/COS **500**. The ML float add/mul path uses its own software floating-point implementation rather than Applesoft ROM routines. COMPUTE: empty loop **10000**; array fill/sum **256×10**; times in **seconds** via CLOCKDRV. |
| **cc65 (6502)** | `A2SPEED_6502` | MATH: integer add (N=1000), integer mul/add loop (N=1000). COMPUTE: empty loop (5000), array fill 256×100, array sum 256×100. Optional: MegaFlash FPU (FADD/FMUL/FSQR ×500) if card present. |
| **cc65 (65C02)** | `A2SPEED_65C02` | Same tests as 6502 build; code is 65C02-optimized. |
| **MegaFlash FPU** | (inside cc65 run) | FADD (1.0+1.0), FMUL (1.0×1.0), FSQR (√1.0), each in a loop of 500 iterations; timed in jiffies. |

Iteration counts are chosen so each test runs long enough for stable timing (Applesoft: see table; cc65: see `cc65/bench.c` defines).

### Comparison logic

- **Applesoft vs cc65**: Compare the same *kind* of test (e.g. integer add, array sum). Applesoft uses ROM and interpreter; cc65 uses compiled C. Expect cc65 to be much faster for equivalent work.
- **6502 vs 65C02**: Run `A2SPEED_6502` and `A2SPEED_65C02` on the same machine. Same tests; 65C02 build uses extra opcodes and addressing modes. Expect 65C02 to show fewer jiffies (faster) and higher iter/s.
- **MegaFlash FPU vs software**: When MegaFlash is present, the FPU test runs. Compare FADD/FMUL/FSQR jiffies to Applesoft SIN/COS/SQR or to cc65 integer loops to see the benefit of hardware float.

---

## Expected results

### Relative expectations

- **Applesoft**: Slowest for math (interpreted BASIC + ROM float). Integer add and empty loop are faster than float/SIN/COS/SQR. Array ops are slower than cc65 due to interpreter and variable lookup.
- **cc65 6502**: Noticeably faster than Applesoft for the same conceptual work (integer add, loops, array fill/sum). No floating point in this build, so no direct comparison to Applesoft float/SQR.
- **cc65 65C02**: Same tests as 6502 build; typically **~10–30%** fewer jiffies (faster) depending on test and compiler optimizations. Loop and array tests often benefit most.
- **MegaFlash FPU**: FADD/FMUL/FSQR ×500 in a few jiffies; **much** faster per operation than Applesoft SIN/COS/SQR for the same number of operations, because work is offloaded to the card.

### Units and interpretation

| Output | Meaning |
|--------|--------|
| **Jiffies** | Elapsed time in 1/60 s. **Lower = faster.** Convert to seconds: `jiffies / 60`. |
| **~N iter/s** | Throughput. **Higher = faster.** Only printed when jiffies &gt; 0. |

Very short runs (0–1 jiffy) have high granularity error; the “~iter/s” may be noisy or omitted. Runs that span several jiffies are more reliable.

### Typical outcome by machine

- **Stock Apple II / II+ (6502, 1 MHz)**: Applesoft math in tens of jiffies; cc65 integer/compute in single digits to low tens. No 65C02 or MegaFlash.
- **IIe (6502 or 65C02)**: Same as above; if 65C02, run both binaries and compare.
- **IIc / IIc+ (65C02, possibly MegaFlash)**: 65C02 build faster than 6502 build. If MegaFlash present, FPU section appears and FADD/FMUL/FSQR are very fast relative to Applesoft float.

### What “pass” means

There is no single pass/fail threshold. The suite is for **comparison**:

- Compare Applesoft to cc65 (same machine).
- Compare 6502 vs 65C02 builds (same machine).
- Compare with/without MegaFlash FPU when the card is present.

Consistent, repeatable jiffy counts (within a small range across runs) indicate a stable clock and meaningful relative results.
