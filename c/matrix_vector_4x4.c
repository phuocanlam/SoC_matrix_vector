
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

/*
 * 4x4 matrix Å~ 4x1 vector test generator
 *
 * Purpose:
 *   - Generate random signed 32-bit input data
 *   - Write input vectors/matrices to input.txt
 *   - Write golden results to golden.txt
 *   - Keep file format simple for Verilog/SystemVerilog testbench reading
 *
 * File format:
 *   input.txt
 *     Each testcase is 20 hex words, one word per line:
 *       line  0..15 : matrix[0][0] ... matrix[3][3]
 *       line 16..19 : vector[0] ... vector[3]
 *
 *   golden.txt
 *     Each testcase is 4 hex words, one word per line:
 *       line 0..3 : result[0] ... result[3]
 *
 * Recommended Verilog reading:
 *   reg [31:0] input_mem  [0:TEST_COUNT*20-1];
 *   reg [31:0] golden_mem [0:TEST_COUNT*4-1];
 *
 *   initial begin
 *       $readmemh("input.txt",  input_mem);
 *       $readmemh("golden.txt", golden_mem);
 *   end
 *
 * Notes:
 *   - Data is written in 8-digit hexadecimal, two's complement form.
 *   - Computation uses int64_t internally, then truncates to int32_t.
 *   - Random range is intentionally limited to reduce overflow frequency.
 */

#define TEST_COUNT 100
#define MAT_DIM 4
#define VEC_DIM 4
#define INPUT_WORDS_PER_TEST 20
#define GOLDEN_WORDS_PER_TEST 4
#define RANDOM_MIN (-1000)
#define RANDOM_MAX (1000)
#define FIXED_SEED 12345u

static int32_t rand_i32_limited(void)
{
    int span = RANDOM_MAX - RANDOM_MIN + 1;
    return (int32_t)(RANDOM_MIN + (rand() % span));
}

static void mat_vec_mul_4x4(
    const int32_t matrix[MAT_DIM][MAT_DIM],
    const int32_t vector[VEC_DIM],
    int32_t result[VEC_DIM]
)
{
    int i, j;

    for (i = 0; i < MAT_DIM; i++) {
        int64_t sum = 0;

        for (j = 0; j < MAT_DIM; j++) {
            sum += (int64_t)matrix[i][j] * (int64_t)vector[j];
        }

        /* Keep only the lower 32 bits as signed int32_t result */
        result[i] = (int32_t)sum;
    }
}

static void write_hex32(FILE *fp, int32_t value)
{
    /*
     * Write exactly 8 hex digits so the file is easy to read with $readmemh.
     * Casting to uint32_t preserves the raw two's complement bit pattern.
     */
    fprintf(fp, "%08x\n", (uint32_t)value);
}

int main(void)
{
    FILE *fin;
    FILE *fgolden;
    int tc, i, j;

    fin = fopen("input.txt", "w");
    fgolden = fopen("golden.txt", "w");

    if (fin == NULL || fgolden == NULL) {
        perror("Failed to open output files");
        if (fin != NULL) {
            fclose(fin);
        }
        if (fgolden != NULL) {
            fclose(fgolden);
        }
        return 1;
    }

    /* Fixed seed for reproducible test vectors */
    srand(FIXED_SEED);

    for (tc = 0; tc < TEST_COUNT; tc++) {
        int32_t matrix[MAT_DIM][MAT_DIM];
        int32_t vector[VEC_DIM];
        int32_t result[VEC_DIM];

        /* Generate random matrix */
        for (i = 0; i < MAT_DIM; i++) {
            for (j = 0; j < MAT_DIM; j++) {
                matrix[i][j] = rand_i32_limited();
            }
        }

        /* Generate random vector */
        for (i = 0; i < VEC_DIM; i++) {
            vector[i] = rand_i32_limited();
        }

        /* Compute golden result */
        mat_vec_mul_4x4(matrix, vector, result);

        /*
         * input.txt layout per testcase:
         *   m00
         *   m01
         *   m02
         *   m03
         *   m10
         *   ...
         *   m33
         *   v0
         *   v1
         *   v2
         *   v3
         */
        for (i = 0; i < MAT_DIM; i++) {
            for (j = 0; j < MAT_DIM; j++) {
                write_hex32(fin, matrix[i][j]);
            }
        }
        for (i = 0; i < VEC_DIM; i++) {
            write_hex32(fin, vector[i]);
        }

        /*
         * golden.txt layout per testcase:
         *   y0
         *   y1
         *   y2
         *   y3
         */
        for (i = 0; i < VEC_DIM; i++) {
            write_hex32(fgolden, result[i]);
        }
    }

    fclose(fin);
    fclose(fgolden);

    printf("Generated input.txt and golden.txt for %d testcases.\n", TEST_COUNT);
    printf("Each testcase uses %d input words and %d golden words.\n",
           INPUT_WORDS_PER_TEST, GOLDEN_WORDS_PER_TEST);

    return 0;
}
