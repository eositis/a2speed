# Clocks supported (reference: SPF)

A2Speed uses timing for benchmarks. The following clock protocols are the same set supported by [SPF](https://github.com/ADTPro/spf); SPF’s implementation lives in `src/prodos/gettime.asm` and detects clocks in this order:

| Order | Clock | Machine / hardware | Notes |
|-------|--------|-------------------|--------|
| 1 | **IIgs built-in** | Apple IIgs | `CheckForGS` → `GetTimeGS`; uses GS time API. |
| 2 | **ROMX** | Apple II with ROMX (e.g. CFFA, ROM-in-RAM) | `CheckForROMX` → `GetTimeROMX`; signature at `$DFFE/$DFFF` ($4A/$CD); time via `$D8F0`, result in zero-page. |
| 3 | **MegaFlash** | IIc/IIc+ with [MegaFlash](https://github.com/ThomasFok/MegaFlash) | `CheckForMegaFlash` → `GetTimeMegaFlash`; I/O at $C0C0–$C0C3; `CMD_GETDEVINFO` signature $88,$74; `CMD_GETPRODOS25TIME` for time with seconds. See also `doc/MegaFlash_Clock.md` in SPF. |
| 4 | **No-Slot Clock** | Apple II with No-Slot Clock card | `CheckForNoSlotClock` → `GetTimeNSC`; signature in `L0304` after probe; hundredths in `TimeNow+3`. |
| 5 | **TimeMaster II H.O.** (slot) | Applied Engineering; ROM id **$4D,$D9** at **$Cn00–$Cn01** (AE ROM Rev 5 — verify against your ROM) | A2Speed: `GetTimeTimeMaster` → SPF `GetTimeThunderclock` (BCD slot path; name is historical). |

**Thunderclock** is not used as an A2Speed backend (1 s granularity). SPF still links unused Thunder helpers from `gettime.asm`; A2Speed does not call `CheckForSlottedClocks` during `CLOCK_INIT`.

SPF’s `InitTime` order differs slightly (NSC before ROMX in the original patch vector). **A2Speed** `CLOCK_INIT` (in `applesoft/clockdrv.s`) follows the table above through TimeMaster only.

SPF uses these to fill **TimeNow** (hours, minutes, seconds, hundredths) for elapsed time. ProDOS’s standard clock interface only provides minute resolution, so SPF (and A2Speed) use this compatibility layer for benchmarking.

## A2Speed timing today

- **Applesoft**: Uses the **60 Hz jiffy counter** at zero-page **$4E–$50** (24-bit, LSB first). Same on all 6502 machines with standard ROM.
- **cc65**: Also uses **$4E–$50** jiffy for elapsed time in the C benchmarks.

To align with SPF on machines that have no jiffy counter or where second-resolution is preferred, A2Speed can later extend the same GetTime-style API; Thunderclock-only hardware is excluded due to 1 s resolution.
