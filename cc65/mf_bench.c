/* A2SPEED - MegaFlash FPU benchmark (only built when A2SPEED_MEGAFLASH is defined)
 * Uses MegaFlash cc65 library; MBF format for Applesoft-compatible FPU ops.
 */

#ifdef A2SPEED_MEGAFLASH

#include <stdio.h>
#include <stdint.h>
#include "a2speed.h"
#include "megaflash.h"

/* Timeout for MegaFlash busy wait (avoid hang if card absent) */
#define MF_TIMEOUT 65535u

static uint8_t mf_wait_busy_timeout(void)
{
    uint16_t n = 0;
    while ((MF_STATUS & MF_BUSYFLAG) && (n < MF_TIMEOUT))
        ++n;
    return (n < MF_TIMEOUT) ? 0 : 1;
}

uint8_t megaflash_detect(void)
{
    MF_CMDREG = MF_CMD_GETDEVSTATUS;
    if (mf_wait_busy_timeout())
        return 0;
    if (MF_STATUS & MF_ERRORFLAG)
        return 0;
    return 1;
}

/* MBF representation of 1.0 for FAC/ARG (Applesoft format)
 * Sign 0, exponent $81, mantissa $80 $00 $00 $00
 * Layout: [0]=FACSIGN [1]=ARGSIGN [2]=FACMANT4 [3]=ARGMANT4 ... [10]=FACEXP [11]=ARGEXP [12]=FACEXT
 */
static void mf_set_one(mf_fpu_args_t* args)
{
    uint8_t* b = args->bytes;
    b[0] = 0;
    b[1] = 0;
    b[2] = 0;
    b[3] = 0;
    b[4] = 0;
    b[5] = 0;
    b[6] = 0;
    b[7] = 0;
    b[8] = 0x80;
    b[9] = 0x80;
    b[10] = 0x81;
    b[11] = 0x81;
    b[12] = 0;
}

/* Run many FPU ops and report jiffies (using Apple II jiffy clock) */
#define MF_ITER 500

void run_megaflash_fpu_benchmark(void)
{
    mf_fpu_args_t args;
    mf_fpu_result_t res;
    uint32_t t1, t2;
    unsigned long i;

    mf_set_one(&args);

    /* FADD: 1.0 + 1.0 in a loop (fixed operands) */
    t1 = jiffy_read();
    for (i = 0; i < MF_ITER; ++i) {
        mf_set_one(&args);
        mf_fadd(&args, &res);
        if (mf_failed() || res.bytes[0])
            break;
    }
    t2 = jiffy_read();
    if (mf_failed())
        printf("MegaFlash FADD: error %u\n", mf_last_error);
    else
        printf("MegaFlash FADD x%lu: %lu jiffies\n", (unsigned long)MF_ITER, (unsigned long)jiffy_elapsed(t1, t2));

    mf_set_one(&args);

    /* FMUL: 1.0 * 1.0 in a loop (fixed operands) */
    t1 = jiffy_read();
    for (i = 0; i < MF_ITER; ++i) {
        mf_set_one(&args);
        mf_fmul(&args, &res);
        if (mf_failed() || res.bytes[0])
            break;
    }
    t2 = jiffy_read();
    if (mf_failed())
        printf("MegaFlash FMUL x%lu: error %u\n", (unsigned long)MF_ITER, mf_last_error);
    else
        printf("MegaFlash FMUL x%lu: %lu jiffies\n", (unsigned long)MF_ITER, (unsigned long)jiffy_elapsed(t1, t2));

    mf_set_one(&args);

    /* FSQR: sqrt(1.0) in a loop (fixed operand) */
    t1 = jiffy_read();
    for (i = 0; i < MF_ITER; ++i) {
        mf_set_one(&args);
        mf_fsqr(&args, &res);
        if (mf_failed() || res.bytes[0])
            break;
    }
    t2 = jiffy_read();
    if (mf_failed())
        printf("MegaFlash FSQR x%lu: error %u\n", (unsigned long)MF_ITER, mf_last_error);
    else
        printf("MegaFlash FSQR x%lu: %lu jiffies\n", (unsigned long)MF_ITER, (unsigned long)jiffy_elapsed(t1, t2));
}

#endif /* A2SPEED_MEGAFLASH */
