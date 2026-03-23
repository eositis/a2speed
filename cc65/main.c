/* A2SPEED - Apple II performance test (cc65)
 * Base 6502 or 65C02-optimized build; optional MegaFlash FPU benchmark.
 */

#include <stdio.h>
#include <conio.h>
#include "a2speed.h"

int main(void)
{
    clrscr();
    print_banner(
#ifdef A2SPEED_65C02
        1
#else
        0
#endif
    );
    run_math_benchmarks();
    run_compute_benchmarks();
#ifdef A2SPEED_MEGAFLASH
    if (megaflash_detect()) {
        printf("\n--- MegaFlash FPU ---\n");
        run_megaflash_fpu_benchmark();
    } else {
        printf("\n(MegaFlash not detected, skipping FPU test)\n");
    }
#endif
    printf("\nDone.\n");
    return 0;
}
