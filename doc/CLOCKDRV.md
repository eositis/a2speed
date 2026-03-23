# CLOCKDRV (Applesoft timing)

`applesoft/clockdrv.bin` is a small machine-language helper loaded at **`$7000`** by `A2SPEED.bas` (ProDOS `BLOAD ... A$7000`). It includes **[`gettime.asm`](https://github.com/ADTPro/spf/blob/master/src/prodos/gettime.asm)** from **SPF** (same clock protocols for the backends wired in `clockdrv.s`):

**`CLOCK_INIT` detection order** (first match wins; see `doc/clocks.md`):

1. Apple **IIgs** built-in clock  
2. **ROMX**  
3. **MegaFlash** (IIc/IIc+; `$C0C0`)  
4. **No-Slot Clock** (SPF `CheckForNoSlotClock` / `GetTimeNSC`; hundredths available)  
5. **Applied Engineering TimeMaster II H.O.** — slot ROM bytes **`$4D` `$D9`** at **`$Cn00`–`$Cn01`** (verify against your ROM rev; AE Rev 5 expected)  

**Thunderclock** is **not** selected by A2Speed: 1 s resolution is too coarse for meaningful wall-clock benchmarks. SPF’s `CheckForSlottedClocks` / standalone Thunder detection is skipped in `clockdrv.s`.

`CLOCK_INIT` (`$7000`) and `CLOCK_READ` (**`$704E`** — confirm in `applesoft/clockdrv.lst` after each build; **must** match `CD`/`RD`/`CK`/`CS`/`TN` decimals in `A2SPEED.bas` line **45**) are thin wrappers: they save/restore zero page, dispatch by **`CLOCK_KIND`**, and fill **`TimeNow`** (four bytes at the end of the binary). **`CLOCK_KIND`** values: `0` none, `1` IIgs, `2` ROMX, `3` MegaFlash, `4` No-Slot Clock, `5` TimeMaster.

**Applesoft must use the exact decimal addresses from the listing** after each rebuild (`RD` for `CLOCK_READ`, `CK` for `CLOCK_KIND`, `CS` for `ClockSlot`, `TN` for `TimeNow`). Calling the wrong address jumps into the middle of machine code and can hang the machine; poking the wrong `CK` corrupts code or leaves the kind unset.

TimeMaster time read uses SPF’s BCD slot routine (`GetTimeTimeMaster` → `GetTimeThunderclock`; the label is historical). If your card is not in Thunder-emulation mode and reads wrong, update the reader in `applesoft/clockdrv.s` using the Programmer’s Supplement.

## License

SPF’s `gettime.asm` is **GPLv2**. If you distribute `clockdrv.bin` or linked objects, comply with the GPL (e.g. offer corresponding source — the A2Speed repo + SPF `gettime.asm`).
