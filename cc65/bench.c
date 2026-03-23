/* A2SPEED - Math and compute benchmarks (cc65) */

#include <stdio.h>
#include <stdlib.h>
#include "a2speed.h"

/* Apple II 60 Hz jiffy counter at zero-page $4E-$50 */
uint32_t jiffy_read(void)
{
    unsigned char* p = (unsigned char*)0x4E;
    uint32_t lo  = p[0];
    uint32_t mid = p[1];
    uint32_t hi  = p[2];
    return lo | (mid << 8) | (hi << 16);
}

uint32_t jiffy_elapsed(uint32_t start, uint32_t end)
{
    uint32_t d = end - start;
    if (end < start)
        d += (uint32_t)16777216;
    return d;
}

#define N_ADD   1000
#define N_LOOP  5000
#define N_ARR   100
#define ARR_LEN 256

static unsigned char arr_buf[ARR_LEN];

static void run_one(const char* name, uint32_t j_start, uint32_t j_end, unsigned long iterations)
{
    uint32_t jiff = jiffy_elapsed(j_start, j_end);
    printf("%-24s %5lu jiffies", name, (unsigned long)jiff);
    if (jiff > 0)
        printf("  (~%lu iter/s)", (unsigned long)((iterations * 60ul) / jiff));
    printf("\n");
}

void print_banner(int is_65c02_build)
{
    printf("A2SPEED - Apple II Benchmarks (cc65)\n");
    printf("====================================\n");
    printf("Build: %s\n\n", is_65c02_build ? "65C02 optimized" : "6502 base");
}

void run_math_benchmarks(void)
{
    uint32_t t1, t2;
    unsigned long i;
    int a;
    long m;

    printf("--- MATH (integer; float via Applesoft or MegaFlash FPU) ---\n");

    /* Integer add */
    t1 = jiffy_read();
    a = 0;
    for (i = 0; i < N_ADD; ++i)
        a = a + 1;
    t2 = jiffy_read();
    run_one("Integer add (1 to N)", t1, t2, N_ADD);

    /* Integer mul (simulate repeated mul) */
    t1 = jiffy_read();
    m = 1;
    for (i = 0; i < N_ADD; ++i)
        m = m * 3 + 1;  /* avoid overflow with small factor */
    t2 = jiffy_read();
    run_one("Integer mul/add loop", t1, t2, N_ADD);
}

void run_compute_benchmarks(void)
{
    uint32_t t1, t2;
    unsigned long i, j;
    unsigned long s;

    printf("\n--- COMPUTE ---\n");

    /* Empty loop */
    t1 = jiffy_read();
    for (i = 0; i < N_LOOP; ++i)
        ;
    t2 = jiffy_read();
    run_one("Empty loop N", t1, t2, N_LOOP);

    /* Array fill */
    t1 = jiffy_read();
    for (j = 0; j < N_ARR; ++j)
        for (i = 0; i < ARR_LEN; ++i)
            arr_buf[i] = (unsigned char)i;
    t2 = jiffy_read();
    run_one("Array fill 256 x N", t1, t2, (unsigned long)N_ARR * ARR_LEN);

    /* Array sum */
    s = 0;
    t1 = jiffy_read();
    for (j = 0; j < N_ARR; ++j) {
        s = 0;
        for (i = 0; i < ARR_LEN; ++i)
            s += arr_buf[i];
    }
    t2 = jiffy_read();
    run_one("Array sum 256 x N", t1, t2, (unsigned long)N_ARR * ARR_LEN);

    printf("\nTimes in 60 Hz jiffies (1 jiffy = 1/60 s)\n");
}
