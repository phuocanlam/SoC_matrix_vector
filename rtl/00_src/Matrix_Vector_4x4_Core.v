module Matrix_Vector_4x4_Core #(
    parameter   DATA_WIDTH  = 32,
    parameter   WA_WIDTH    = 7,
    parameter   RA_WIDTH    = 3,
    parameter   MA_WIDTH    = 4,
    parameter   VA_WIDTH    = 2
)(
    input  wire                     clk_i,
    input  wire                     rstn_i,

    // External write channel
    input  wire                     awvalid_i,
    input  wire [WA_WIDTH-1:0]      waddr_i,
    input  wire [DATA_WIDTH-1:0]    wdata_i,

    // External read channel
    input  wire                     arvalid_i,
    input  wire [RA_WIDTH-1:0]      raddr_i,
    output wire [DATA_WIDTH-1:0]    rdata_o
);

    //==================================================
    // Internal wires
    //==================================================

    // Arbiter <-> Controller
    wire                           load_flag_w;
    wire                           start_flag_w;
    wire                           done_flag_w;
    wire                           complete_w;
    wire [1:0]                     state_w;

    // Controller -> Matrix_Mem
	wire [1:0]						CTRL_MBM_raddr_w;
	wire 							CTRL_MBM_rd_en_w;

    // Controller -> Datapath
    wire                            execute_w;

    // Arbiter -> Matrix_Mem
    wire                            Arbiter_MBM_awvalid_w;
    wire        [MA_WIDTH-1:0]      Arbiter_MBM_waddr_w;
    wire signed [DATA_WIDTH-1:0]    Arbiter_MBM_data_w;

    // Arbiter -> Vector_Mem
    wire                            Arbiter_VIBM_awvalid_w;
    wire        [VA_WIDTH-1:0]      Arbiter_VIBM_waddr_w;
    wire signed [DATA_WIDTH-1:0]    Arbiter_VIBM_data_w;

    // Matrix_Mem -> Datapath
    wire signed [DATA_WIDTH-1:0]    M_data0_w;
    wire signed [DATA_WIDTH-1:0]    M_data1_w;
    wire signed [DATA_WIDTH-1:0]    M_data2_w;
    wire signed [DATA_WIDTH-1:0]    M_data3_w;

    // Vector_Mem -> Datapath
    wire signed [DATA_WIDTH-1:0]    VI_data0_w;
    wire signed [DATA_WIDTH-1:0]    VI_data1_w;
    wire signed [DATA_WIDTH-1:0]    VI_data2_w;
    wire signed [DATA_WIDTH-1:0]    VI_data3_w;

    // Datapath -> Vector_Out_Mem
    wire signed [DATA_WIDTH-1:0]    VO_data_w;
    wire                            VO_data_valid_w;

    // Arbiter <-> Vector_Out_Mem
    wire                            Arbiter_VOM_arvalid_w;
    wire        [VA_WIDTH-1:0]      Arbiter_VOM_raddr_w;
    wire        [DATA_WIDTH-1:0]    Arbiter_VOM_rdata_w;

    //==================================================
    // Arbiter
    //==================================================

    Arbiter #(
        .DATA_WIDTH (DATA_WIDTH),
        .WA_WIDTH   (WA_WIDTH),
        .RA_WIDTH   (RA_WIDTH),
        .MA_WIDTH   (MA_WIDTH),
        .VA_WIDTH   (VA_WIDTH)
    ) u_arbiter (
        .clk_i      (clk_i),
        .rstn_i     (rstn_i),

        .awvalid_i   (awvalid_i),
        .waddr_i     (waddr_i),
        .wdata_i     (wdata_i),

        .arvalid_i   (arvalid_i),
        .raddr_i     (raddr_i),
        .rdata_o     (rdata_o),

        .complete_i  (complete_w),
        .state_i     (state_w),

        .load_flag_o (load_flag_w),
        .start_flag_o(start_flag_w),
        .done_flag_o (done_flag_w),

        .Arbiter_MBM_awvalid_o  (Arbiter_MBM_awvalid_w),
        .Arbiter_MBM_waddr_o    (Arbiter_MBM_waddr_w),
        .Arbiter_MBM_data_o     (Arbiter_MBM_data_w),

        .Arbiter_VIBM_awvalid_o (Arbiter_VIBM_awvalid_w),
        .Arbiter_VIBM_waddr_o   (Arbiter_VIBM_waddr_w),
        .Arbiter_VIBM_data_o    (Arbiter_VIBM_data_w),

        .Arbiter_VOM_arvalid_o  (Arbiter_VOM_arvalid_w),
        .Arbiter_VOM_raddr_o    (Arbiter_VOM_raddr_w),
        .Arbiter_VOM_rdata_i    (Arbiter_VOM_rdata_w)
    );

    //==================================================
    // Controller
    //==================================================

    controller #(
        .DATA_WIDTH (DATA_WIDTH),
        .WA_WIDTH   (WA_WIDTH),
        .RA_WIDTH   (RA_WIDTH),
        .MA_WIDTH   (MA_WIDTH),
        .VA_WIDTH   (VA_WIDTH)
    ) u_controller (
        .clk_i      (clk_i),
        .rstn_i     (rstn_i),

        .load_flag_i (load_flag_w),
        .start_flag_i(start_flag_w),
        .done_flag_i (done_flag_w),

        .CTRL_MBM_raddr_o   (CTRL_MBM_raddr_w),
		.CTRL_MBM_rd_en_o	(CTRL_MBM_rd_en_w),
		.CTRL_VIBM_rd_en_o	(CTRL_VIBM_rd_en_w),
		
        .execute_o    (execute_w),

        .complete_o  (complete_w),
        .state_o     (state_w)
    );

    //==================================================
    // Matrix memory
    //==================================================

    matrix_bank_mem #(
        .ADDR_WIDTH(MA_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_matrix_mem (
        .clk_i    (clk_i),

        .Arbiter_MBM_awvalid_i(Arbiter_MBM_awvalid_w),
        .Arbiter_MBM_waddr_i(Arbiter_MBM_waddr_w),
        .Arbiter_MBM_wdata_i (Arbiter_MBM_data_w),

        .CTRL_MBM_raddr_i (CTRL_MBM_raddr_w),
		.CTRL_MBM_rd_en_i(CTRL_MBM_rd_en_w),
		
        .M_data0_o (M_data0_w),
        .M_data1_o (M_data1_w),
        .M_data2_o (M_data2_w),
        .M_data3_o (M_data3_w)
    );

    //==================================================
    // Vector memory
    //==================================================

    vector_input_bank_mem #(
        .ADDR_WIDTH(VA_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_vector_mem (
        .clk_i    (clk_i),

        .Arbiter_VIBM_awvalid_i(Arbiter_VIBM_awvalid_w),
        .Arbiter_VIBM_waddr_i  (Arbiter_VIBM_waddr_w),
        .Arbiter_VIBM_wdata_i  (Arbiter_VIBM_data_w),
		
		.CTRL_VIBM_rd_en_i(CTRL_VIBM_rd_en_w),
		
        .VI_data0_o (VI_data0_w),
        .VI_data1_o (VI_data1_w),
        .VI_data2_o (VI_data2_w),
        .VI_data3_o (VI_data3_w)
    );

    //==================================================
    // Datapath
    //==================================================

    datapath #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_datapath (
        .clk_i      (clk_i),
        .rstn_i     (rstn_i),

        .execute_i  (execute_w),

        .M_data0_i   (M_data0_w),
        .M_data1_i   (M_data1_w),
        .M_data2_i   (M_data2_w),
        .M_data3_i   (M_data3_w),

        .VI_data0_i   (VI_data0_w),
        .VI_data1_i   (VI_data1_w),
        .VI_data2_i   (VI_data2_w),
        .VI_data3_i   (VI_data3_w),

        .VO_data_o       (VO_data_w),
        .VO_data_valid_o (VO_data_valid_w)
    );

    //==================================================
    // Output vector memory
    //==================================================

    vector_output_mem #(
        .ADDR_WIDTH(VA_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_vector_out_mem (
        .clk_i      (clk_i),
        .rstn_i     (rstn_i),

        .VO_data_valid_i (VO_data_valid_w),
        .VO_data_i       (VO_data_w),

        .Arbiter_VOM_arvalid_i(Arbiter_VOM_arvalid_w),
        .Arbiter_VOM_raddr_i  (Arbiter_VOM_raddr_w),
        .Arbiter_VOM_rdata_o  (Arbiter_VOM_rdata_w)
    );

endmodule