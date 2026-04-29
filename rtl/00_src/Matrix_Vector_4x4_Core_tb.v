// `timescale 1ns/1ps

module Matrix_Vector_4x4_Core_tb;

    parameter DWIDTH  = 32;
    parameter WAWIDTH = 7;
    parameter RAWIDTH = 3;
    parameter MAWIDTH = 4;
    parameter VAWIDTH = 2;

    parameter TEST_COUNT = 100;
    parameter INPUT_WORDS_PER_TEST  = 20;
    parameter GOLDEN_WORDS_PER_TEST = 4;

    reg                     CLK;
    reg                     RST;

    reg                     awvalid_i;
    reg  [WAWIDTH-1:0]      waddr_i;
    reg  [DWIDTH-1:0]       wdata_i;

    wire                    arvalid_i;
    wire [RAWIDTH-1:0]      raddr_i;
    wire [DWIDTH-1:0]       rdata_o;

    reg [31:0] input_mem  [0:TEST_COUNT*INPUT_WORDS_PER_TEST-1];
    reg [31:0] golden_mem [0:TEST_COUNT*GOLDEN_WORDS_PER_TEST-1];

    integer tc;
    integer i;
    integer base_in;
    integer base_golden;
    integer pass_count;
    integer fail_count;

    reg [31:0] expected;
    reg [31:0] actual;

    // -------------------------------------------------
    // Registered read request signals in TB
    // -------------------------------------------------
    reg                  arvalid_req_r;
    reg [RAWIDTH-1:0]    raddr_req_r;

    reg                  arvalid_ff_r;
    reg [RAWIDTH-1:0]    raddr_ff_r;

    assign arvalid_i = arvalid_ff_r;
    assign raddr_i   = raddr_ff_r;

    localparam [WAWIDTH-1:0] LOAD_FLAG_ADDR_BASE   = 7'd0;
    localparam [WAWIDTH-1:0] START_FLAG_ADDR_BASE  = 7'd16;
    localparam [WAWIDTH-1:0] DONE_FLAG_ADDR_BASE   = 7'd32;
    localparam [WAWIDTH-1:0] MATRIX_MEM_ADDR_BASE  = 7'd48;
    localparam [WAWIDTH-1:0] VECTOR_MEM_ADDR_BASE  = 7'd64;

    localparam [RAWIDTH-1:0] COMPLETE_ADDR_BASE    = 3'd0;
    localparam [RAWIDTH-1:0] OVECTOR_MEM_ADDR_BASE = 3'd4;

    Matrix_Vector_4x4_Core #(
        .DATA_WIDTH (DWIDTH),
        .WA_WIDTH(WAWIDTH),
        .RA_WIDTH(RAWIDTH),
        .MA_WIDTH(MAWIDTH),
        .VA_WIDTH(VAWIDTH)
    ) dut (
        .clk_i      (CLK),
        .rstn_i     (RST),
        .awvalid_i  (awvalid_i),
        .waddr_i    (waddr_i),
        .wdata_i    (wdata_i),
        .arvalid_i  (arvalid_i),
        .raddr_i    (raddr_i),
        .rdata_o    (rdata_o)
    );

    // Clock
    initial begin
        CLK = 1'b0;
        forever #5 CLK = ~CLK;
    end

    // Read-channel FF
    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            arvalid_ff_r <= 1'b0;
            raddr_ff_r   <= {RAWIDTH{1'b0}};
        end
        else begin
            arvalid_ff_r <= arvalid_req_r;
            raddr_ff_r   <= raddr_req_r;
        end
    end

    initial begin
        $dumpfile("Matrix_Vector_4x4_Core_tb.vcd");
        $dumpvars(0, Matrix_Vector_4x4_Core_tb);
    end

    task write_reg;
        input [WAWIDTH-1:0] addr;
        input [DWIDTH-1:0]  data;
        begin
            @(negedge CLK);
            awvalid_i = 1'b1;
            waddr_i  = addr;
            wdata_i  = data;

            @(negedge CLK);
            awvalid_i = 1'b0;
            waddr_i  = {WAWIDTH{1'b0}};
            wdata_i  = {DWIDTH{1'b0}};
        end
    endtask

    // Read request goes through FF before entering DUT
    task read_reg;
        input  [RAWIDTH-1:0] addr;
        output [DWIDTH-1:0]  data;
        begin
            // drive request side
            @(negedge CLK);
            arvalid_req_r = 1'b1;
            raddr_req_r   = addr;

            // 1st posedge: request is captured into FF by <=
            @(posedge CLK);

            // 2nd posedge: DUT sees stable registered arvalid_i/raddr_i
            @(posedge CLK);
            #1;
            data = rdata_o;

            // deassert request
            @(negedge CLK);
            arvalid_req_r = 1'b0;
            raddr_req_r   = {RAWIDTH{1'b0}};

            @(posedge CLK);
        end
    endtask

    task wait_complete;
        reg [DWIDTH-1:0] status;
        integer watchdog;
        begin
            status   = 0;
            watchdog = 0;

            while (status[0] !== 1'b1 && watchdog < 200) begin
                read_reg(COMPLETE_ADDR_BASE, status);
                watchdog = watchdog + 1;
            end

            if (watchdog >= 200) begin
                $display("[ERROR] Timeout waiting complete flag");
                $finish;
            end
        end
    endtask

    initial begin
        pass_count   = 0;
        fail_count   = 0;

        awvalid_i     = 0;
        waddr_i      = 0;
        wdata_i      = 0;

        arvalid_req_r = 0;
        raddr_req_r   = 0;

        expected = 0;
        actual   = 0;

        // $readmemh("/home/ubuntu/SoC_Can_Ban/Luan/Class_2/Buoi_8/Code_C/input.txt",  input_mem);
        // $readmemh("/home/ubuntu/SoC_Can_Ban/Luan/Class_2/Buoi_8/Code_C/golden.txt", golden_mem);
        $readmemh("../01_tb/input.txt",  input_mem);
        $readmemh("../01_tb/golden.txt", golden_mem);

        RST = 1'b0;
        repeat (3) @(posedge CLK);
        RST = 1'b1;
        repeat (2) @(posedge CLK);

        $display("==============================================");
        $display(" Start Matrix_Vector_4x4_Top file-based test ");
        $display(" TEST_COUNT = %0d", TEST_COUNT);
        $display("==============================================");

        for (tc = 0; tc < TEST_COUNT; tc = tc + 1) begin
            base_in     = tc * INPUT_WORDS_PER_TEST;
            base_golden = tc * GOLDEN_WORDS_PER_TEST;

            write_reg(LOAD_FLAG_ADDR_BASE, 32'h0000_0001);

            for (i = 0; i < 16; i = i + 1) begin
                write_reg(MATRIX_MEM_ADDR_BASE + i[WAWIDTH-1:0], input_mem[base_in + i]);
            end

            for (i = 0; i < 4; i = i + 1) begin
                write_reg(VECTOR_MEM_ADDR_BASE + i[WAWIDTH-1:0], input_mem[base_in + 16 + i]);
            end

            write_reg(START_FLAG_ADDR_BASE, 32'h0000_0001);

            wait_complete();

            for (i = 0; i < 4; i = i + 1) begin
                read_reg(OVECTOR_MEM_ADDR_BASE + i[RAWIDTH-1:0], actual);
                expected = golden_mem[base_golden + i];

                if (actual === expected) begin
                    pass_count = pass_count + 1;
                    $display("[PASS] TC=%0d IDX=%0d ACT=%08h EXP=%08h",
                             tc, i, actual, expected);
                end
                else begin
                    fail_count = fail_count + 1;
                    $display("[FAIL] TC=%0d IDX=%0d ACT=%08h EXP=%08h",
                             tc, i, actual, expected);
                end
            end

            write_reg(DONE_FLAG_ADDR_BASE, 32'h0000_0001);
            repeat (2) @(posedge CLK);
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