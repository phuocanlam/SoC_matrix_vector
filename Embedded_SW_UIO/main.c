#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "FPGA_Driver.h"
#include "FPGA_Driver.c"

#define TEST_COUNT              100
#define INPUT_WORDS_PER_TEST    20
#define GOLDEN_WORDS_PER_TEST   4

// Write address map (from testbench)
#define LOAD_FLAG_ADDR_BASE     0 
#define START_FLAG_ADDR_BASE    16
#define DONE_FLAG_ADDR_BASE     32
#define MATRIX_MEM_ADDR_BASE    48
#define VECTOR_MEM_ADDR_BASE    64

// Read address map (from testbench)
#define COMPLETE_ADDR_BASE      0
#define OVECTOR_MEM_ADDR_BASE   4

#define MAX_POLL                100000

// Read hex data from file (same format as $readmemh)
static int read_hex_file(const char *filename, uint32_t *buf, int count)
{
    FILE *fp = fopen(filename, "r");
    int i = 0;

    if (fp == NULL) {
        printf("Cannot open file: %s\n", filename);
        return 0;
    }

    while (i < count && fscanf(fp, "%x", &buf[i]) == 1) {
        i++;
    }

    fclose(fp);

    if (i != count) {
        printf("File %s does not contain enough data (%d/%d)\n", filename, i, count);
        return 0;
    }

    return 1;
}

// Write to IP register
static void write_reg(uint32_t addr, uint32_t data)
{
    *(MY_IP_info.pio_mmap + addr) = data;
}

// Read from IP register
static uint32_t read_reg(uint32_t addr)
{
    return *(MY_IP_info.pio_mmap + addr);
}

// Poll until complete flag is set
static int wait_complete(void)
{
    int poll = 0;
    uint32_t status;

    do {
        status = read_reg(COMPLETE_ADDR_BASE);
        if (status & 0x1)
            return 1;
        poll++;
    } while (poll < MAX_POLL);

    return 0;
}

int main(void)
{
    uint32_t input_mem[TEST_COUNT * INPUT_WORDS_PER_TEST];
    uint32_t golden_mem[TEST_COUNT * GOLDEN_WORDS_PER_TEST];
    uint32_t actual, expected;
    int tc, i;
    int pass_count = 0;
    int fail_count = 0;
    int base_in, base_golden;

    if (my_ip_open() != 1) {
        printf("my_ip_open() failed\n");
        return 1;
    }

    // Load input and golden data from files
    if (!read_hex_file("/home/ubuntu/SoC_Can_Ban/Luan/Class_2/Buoi_8/Code_C/input.txt", input_mem, TEST_COUNT * INPUT_WORDS_PER_TEST)) {
        return 1;
    }

    if (!read_hex_file("/home/ubuntu/SoC_Can_Ban/Luan/Class_2/Buoi_8/Code_C/golden.txt", golden_mem, TEST_COUNT * GOLDEN_WORDS_PER_TEST)) {
        return 1;
    }

    printf("========================================\n");
    printf(" Start Matrix_Vector_4x4 file-based test\n");
    printf(" TEST_COUNT = %d\n", TEST_COUNT);
    printf("========================================\n");

    for (tc = 0; tc < TEST_COUNT; tc++) {
        base_in     = tc * INPUT_WORDS_PER_TEST;
        base_golden = tc * GOLDEN_WORDS_PER_TEST;

        // Assert load flag
        write_reg(LOAD_FLAG_ADDR_BASE, 0x00000001);

        // Write 4x4 matrix (16 elements)
        for (i = 0; i < 16; i++) {
            write_reg(MATRIX_MEM_ADDR_BASE + i, input_mem[base_in + i]);
        }

        // Write vector (4 elements)
        for (i = 0; i < 4; i++) {
            write_reg(VECTOR_MEM_ADDR_BASE + i, input_mem[base_in + 16 + i]);
        }

        // Start computation
        write_reg(START_FLAG_ADDR_BASE, 0x00000001);

        // Wait for completion
        if (!wait_complete()) {
            printf("[ERROR] Timeout waiting complete at TC=%d\n", tc);
            return 1;
        }

        // Read output vector and compare with golden
        for (i = 0; i < 4; i++) {
            actual   = read_reg(OVECTOR_MEM_ADDR_BASE + i);
            expected = golden_mem[base_golden + i];

            if (actual == expected) {
                pass_count++;
                printf("[PASS] TC=%03d IDX=%d ACT=%08x EXP=%08x\n",
                       tc, i, actual, expected);
            } else {
                fail_count++;
                printf("[FAIL] TC=%03d IDX=%d ACT=%08x EXP=%08x\n",
                       tc, i, actual, expected);
            }
        }

        // Assert done flag
        write_reg(DONE_FLAG_ADDR_BASE, 0x00000001);
    }

    printf("========================================\n");
    printf(" TEST DONE\n");
    printf(" PASS = %d\n", pass_count);
    printf(" FAIL = %d\n", fail_count);
    printf("========================================\n");

    if (fail_count == 0)
        printf("RESULT: ALL TESTS PASSED\n");
    else
        printf("RESULT: TEST FAILED\n");

    return 0;
}