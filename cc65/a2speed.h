/* A2SPEED - Apple II performance test
 * Timing and detection helpers.
 */

#ifndef A2SPEED_H
#define A2SPEED_H

#include <stdint.h>

/* 60 Hz jiffy clock on Apple II (zero-page $4E-$50, 24-bit LSB first) */

/* Read 24-bit jiffy count (1/60 s per tick); implemented in bench.c */
uint32_t jiffy_read(void);

/* Elapsed jiffies (handles 24-bit wrap); implemented in bench.c */
uint32_t jiffy_elapsed(uint32_t start, uint32_t end);

void print_banner(int is_65c02_build);
void run_math_benchmarks(void);
void run_compute_benchmarks(void);

#ifdef A2SPEED_MEGAFLASH
void run_megaflash_fpu_benchmark(void);
uint8_t megaflash_detect(void);
#endif

#endif /* A2SPEED_H */
