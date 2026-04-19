A2SPEED README
Developed by Elmars Ositis
Version: 1.0
Build Date: 2026-04-19
Build Number: 21
GitHub: https://github.com/eositis/a2speed


What this disk is for
---------------------
A2SPEED is an Apple II benchmark disk. It is mainly intended to compare
how fast the same machine runs similar work in three different ways:

1. Applesoft BASIC
2. A small machine-language helper used by the Applesoft program
3. Separate cc65 native binaries (built outside the Applesoft app)

The Applesoft program is the main entry point on this disk.


Files used by the Applesoft benchmark
-------------------------------------
A2SPEED
  The Applesoft BASIC benchmark program.

BENCHML
  The machine-language helper loaded by A2SPEED at $6000.

CLOCKDRV
  The clock support driver loaded by A2SPEED at $7000.

Only these three files are needed by the Applesoft benchmark.


What A2SPEED measures
---------------------
The Applesoft benchmark has two sections:

MATH
  Integer add
  Float add
  Float multiply
  SIN/COS
  SQR

COMPUTE
  Empty loop
  Array fill
  Array sum

For each row, the Applesoft program runs the test once in interpreted
Applesoft and once in the BENCHML helper, using the same iteration count.


How the output works
--------------------
The Applesoft display uses 80-column output and shows:

TEST
  The benchmark name

AppleSoft
  Elapsed wall-clock time for the interpreted Applesoft version

ML
  Elapsed wall-clock time for the BENCHML machine-language version

A Ref%
  Current Applesoft result compared with the stock Apple IIc reference

M Ref%
  Current ML result compared with the stock Apple IIc ML reference

Percent interpretation:
  100%  = same speed as the reference
  >100% = faster than the reference
  <100% = slower than the reference

The percentages are calculated as:
  reference time / measured time * 100


Timed speed line
----------------
Near the top of the run, A2SPEED prints a "Timed speed" line.

This is based on timing a fixed Applesoft empty FOR/NEXT loop and is meant
to give a quick overall speed comparison for the current machine.

The important value is:
  iter/s

The "~MHz eq" value is just an estimate based on a measured reference
machine and should be treated as a rough comparison number, not a true
hardware clock reading.


Clock support
-------------
A2SPEED uses CLOCKDRV for wall-clock timing.

Supported backends, in detection order:
  1. Apple IIgs built-in clock
  2. ROMX
  3. MegaFlash
  4. No-Slot Clock
  5. TimeMaster II H.O.

Thunderclock is not selected for A2SPEED timing because its 1-second
resolution is too coarse for this benchmark.

Clock meanings:
  K=0 none found
  K=1 IIgs
  K=2 ROMX
  K=3 MegaFlash
  K=4 No-Slot Clock
  K=5 TimeMaster

The clock driver fills a 4-byte time structure:
  hours, minutes, seconds, hundredths

MegaFlash and No-Slot Clock support hundredths. A2SPEED uses those
hundredths when available.

Emulators (e.g. Ample / MAME): Wall-clock timings assume the RTC advances
with emulated machine time. If you run with speed not throttled to real
time, or the emulator ties the No-Slot Clock to host wall time while the
CPU runs faster, reported seconds can look wrong. Prefer normal
(real-time) speed when you want true wall-clock seconds.

A2SPEED can auto-switch to VBL jiffy timing ($4E-$50, NTSC JP=60.096) if a
short calibration detects RTC vs jiffy mismatch; then it prints
"Timing: VBL jiffies (RTC skew)" and uses emulated-time seconds for
benchmarks. See doc/CLOCKDRV.md.


How timing is calculated
------------------------
A2SPEED reads the clock before and after each test and computes:

  elapsed = end - start

Displayed values are rounded to the nearest 0.01 second.

If the elapsed value comes back slightly negative, A2SPEED treats that as
a small clock-read quirk and flips the sign. If the time crosses midnight,
it adds 86400 seconds.


Math behavior in BENCHML
------------------------
BENCHML mirrors the Applesoft test counts, but not always the same internal
implementation.

Float add and float multiply:
  These now use BENCHML's own positive software floating-point format with a
  32-bit normalized mantissa and binary exponent. Applesoft remains the
  reference behavior, but the ML implementation is independent.

SIN, COS, and SQR:
  These do not call Applesoft ROM math. They use direct high-precision
  fixed results for the benchmark operands:
    SIN(1)
    COS(1)
    SQR(2)

This keeps the ML benchmark fast while still matching the benchmark inputs
used by the Applesoft side.


Memory layout and safety
------------------------
The Applesoft program loads:
  BENCHML  at $6000
  CLOCKDRV at $7000

After the BLOADs complete, the program lowers HIMEM to $6000 so Applesoft
string/heap space cannot overwrite the machine-language image.

At program end it restores HIMEM, sends PR#0, and closes files so the next
RUN works cleanly under ProDOS.

If you STOP the program partway through, HIMEM may remain lowered. If that
happens, leave BASIC and restart, or restore the normal HIMEM pointer before
running again.


What the reference numbers mean
-------------------------------
The reference percentages are based on a tested stock Apple IIc result set.
They are there to make it easy to compare your current machine to a known
baseline.

They are not pass/fail limits.


Expected runtime
----------------
Very roughly, on an unaccelerated 1 MHz class Apple II:

  Applesoft benchmark: about 1 to 3 minutes

The Applesoft run is usually the slowest part because interpreter overhead
and ROM floating point are expensive.


Notes
-----
This benchmark is for comparison, not absolute truth.

Useful comparisons include:
  current machine vs stock reference
  accelerated vs unaccelerated
  Applesoft vs ML on the same machine

If results are stable across repeated runs, the timing is probably good.
