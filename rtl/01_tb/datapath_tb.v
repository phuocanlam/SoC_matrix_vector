//`timescale 1ns/1ps

module datapath_tb;

    parameter DATA_WIDTH = 32;
    parameter MATRIX_TESTS = 100;
    parameter DP_TESTS = MATRIX_TESTS * 4;

    parameter INPUT_WORDS_PER_MATRIX  = 20;
    parameter GOLDEN_WORDS_PER_MATRIX = 4;

    reg                         CLK;
    reg                         RST;
    reg                         execute_i;

    reg  signed [DATA_WIDTH-1:0]    M_data1_i;
    reg  signed [DATA_WIDTH-1:0]    M_data2_i;
    reg  signed [DATA_WIDTH-1:0]    M_data3_i;
    reg  signed [DATA_WIDTH-1:0]    M_data4_i;

    reg  signed [DATA_WIDTH-1:0]    VI_data1_i;
    reg  signed [DATA_WIDTH-1:0]    VI_data2_i;
    reg  signed [DATA_WIDTH-1:0]    VI_data3_i;
    reg  signed [DATA_WIDTH-1:0]    VI_data4_i;

    wire signed [DATA_WIDTH-1:0]    VO_data_o;
    wire                        VO_data_valid_o;

    reg [31:0] input_mem  [0:MATRIX_TESTS*INPUT_WORDS_PER_MATRIX-1];
    reg [31:0] golden_mem [0:MATRIX_TESTS*GOLDEN_WORDS_PER_MATRIX-1];

    integer matrix_tc;
    integer row_idx;
    integer base_in;
    integer base_golden;
    integer pass_count;
    integer fail_count;

    reg signed [DATA_WIDTH-1:0] expected_out;

    // DUT
    datapath #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk_i(CLK),
        .rstn_i(RST),
        .execute_i(execute_i),

        .M_data0_i(M_data1_i),
        .M_data1_i(M_data2_i),
        .M_data2_i(M_data3_i),
        .M_data3_i(M_data4_i),

        .VI_data0_i(VI_data1_i),
        .VI_data1_i(VI_data2_i),
        .VI_data2_i(VI_data3_i),
        .VI_data3_i(VI_data4_i),

        .VO_data_o(VO_data_o),
        .VO_data_valid_o(VO_data_valid_o)
    );

    // Clock
    initial begin
        CLK = 1'b0;
        forever #5 CLK = ~CLK;
    end

    // Optional waveform dump
    initial begin
        $dumpfile("datapath_tb.vcd");
        $dumpvars(0, datapath_tb);
    end

    initial begin
        pass_count = 0;
        fail_count = 0;

        execute_i = 0;
        M_data1_i = 0; M_data2_i = 0; M_data3_i = 0; M_data4_i = 0;
        VI_data1_i = 0; VI_data2_i = 0; VI_data3_i = 0; VI_data4_i = 0;

        // Read memory files
        $readmemh("../01_tb/input.txt",  input_mem);
        $readmemh("../01_tb/golden.txt", golden_mem);

        // Reset
        RST = 1'b0;
        repeat (2) @(posedge CLK);
        RST = 1'b1;
        @(posedge CLK);

        $display("==============================================");
        $display(" Datapath file-based self-check testbench");
        $display(" MATRIX_TESTS = %0d", MATRIX_TESTS);
        $display(" DP_TESTS     = %0d", DP_TESTS);
        $display("==============================================");

        for (matrix_tc = 0; matrix_tc < MATRIX_TESTS; matrix_tc = matrix_tc + 1) begin
            base_in     = matrix_tc * INPUT_WORDS_PER_MATRIX;
            base_golden = matrix_tc * GOLDEN_WORDS_PER_MATRIX;

            // Vector is shared for all 4 rows of one matrix testcase
            VI_data1_i = input_mem[base_in + 16];
            VI_data2_i = input_mem[base_in + 17];
            VI_data3_i = input_mem[base_in + 18];
            VI_data4_i = input_mem[base_in + 19];

            for (row_idx = 0; row_idx < 4; row_idx = row_idx + 1) begin
                // Select one row of the matrix
                M_data1_i = input_mem[base_in + row_idx*4 + 0];
                M_data2_i = input_mem[base_in + row_idx*4 + 1];
                M_data3_i = input_mem[base_in + row_idx*4 + 2];
                M_data4_i = input_mem[base_in + row_idx*4 + 3];

                expected_out = golden_mem[base_golden + row_idx];

                execute_i = 1'b1;
                @(posedge CLK);
                #1;

                if ((VO_data_valid_o === 1'b1) && (VO_data_o === expected_out)) begin
                    pass_count = pass_count + 1;
                    $display("[PASS] MATRIX_TC=%0d ROW=%0d OUT=%0d EXP=%0d",
                             matrix_tc, row_idx, VO_data_o, expected_out);
                end
                else begin
                    fail_count = fail_count + 1;
                    $display("[FAIL] MATRIX_TC=%0d ROW=%0d DUT_OUT=%0d EXP_OUT=%0d VALID=%0d",
                             matrix_tc, row_idx, VO_data_o, expected_out, VO_data_valid_o);
                    $display("       M_ROW = [%0d %0d %0d %0d]",
                             M_data1_i, M_data2_i, M_data3_i, M_data4_i);
                    $display("       VEC   = [%0d %0d %0d %0d]",
                             VI_data1_i, VI_data2_i, VI_data3_i, VI_data4_i);
                    $display("       HEX   = M[%08h %08h %08h %08h] V[%08h %08h %08h %08h] DUT=%08h EXP=%08h",
                             M_data1_i, M_data2_i, M_data3_i, M_data4_i,
                             VI_data1_i, VI_data2_i, VI_data3_i, VI_data4_i,
                             VO_data_o, expected_out);
                end
            end

            // Optional idle cycle between matrix testcases
            execute_i = 1'b0;
            @(posedge CLK);
            #1;
        end

        $display("==============================================");
        $display(" TEST DONE");
        $display(" PASS = %0d", pass_count);
        $display(" FAIL = %0d", fail_count);
        $display("==============================================");

        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: TEST FAILED");

        $finish;
    end

endmodule