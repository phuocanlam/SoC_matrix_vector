module matrix_bank_mem #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 32
) (
    input  wire                     clk_i,

    // From Arbiter
    input  wire        [ADDR_WIDTH-1:0] Arbiter_MBM_waddr_i,
    input  wire                         Arbiter_MBM_awvalid_i,
    input  wire        [DATA_WIDTH-1:0] Arbiter_MBM_wdata_i,

    // From controller
    input  wire        [1:0]            CTRL_MBM_raddr_i,
    input  wire                         CTRL_MBM_rd_en_i,

    // To datapath
    output wire signed [DATA_WIDTH-1:0] M_data0_o,
    output wire signed [DATA_WIDTH-1:0] M_data1_o,
    output wire signed [DATA_WIDTH-1:0] M_data2_o,
    output wire signed [DATA_WIDTH-1:0] M_data3_o
);
    //----------------------------------------------//
    //              Local Parameter                 //
    //----------------------------------------------//
    localparam MEM_BANK_0_SELECT = 0;
    localparam MEM_BANK_1_SELECT = 1;
    localparam MEM_BANK_2_SELECT = 2;
    localparam MEM_BANK_3_SELECT = 3;
    //----------------------------------------------//
    //              Wire declaration                //
    //----------------------------------------------//
    wire [1:0]      bank_select_w;
    wire [1:0]      mem_bank_addr_w;

    //----------------------------------------------//
    //              Reg declaration                 //
    //----------------------------------------------//
    reg [DATA_WIDTH-1:0]  mem_bank_0_r [0:3];
    reg [DATA_WIDTH-1:0]  mem_bank_1_r [0:3];
    reg [DATA_WIDTH-1:0]  mem_bank_2_r [0:3];
    reg [DATA_WIDTH-1:0]  mem_bank_3_r [0:3];

    //----------------------------------------------//
    //         Combinational circuits               //
    //----------------------------------------------//
    assign bank_select_w   = Arbiter_MBM_waddr_i[1:0];
    assign mem_bank_addr_w = Arbiter_MBM_waddr_i[ADDR_WIDTH-1:2];

    //----------------------------------------------//
    //            Sequential circuits               //
    //----------------------------------------------//
    always @(posedge clk_i) begin
        if (Arbiter_MBM_awvalid_i && bank_select_w == MEM_BANK_0_SELECT) begin
            mem_bank_0_r[mem_bank_addr_w] <= Arbiter_MBM_wdata_i;
        end

        if (Arbiter_MBM_awvalid_i && bank_select_w == MEM_BANK_1_SELECT) begin
            mem_bank_1_r[mem_bank_addr_w] <= Arbiter_MBM_wdata_i;
        end

        if (Arbiter_MBM_awvalid_i && bank_select_w == MEM_BANK_2_SELECT) begin
            mem_bank_2_r[mem_bank_addr_w] <= Arbiter_MBM_wdata_i;
        end

        if (Arbiter_MBM_awvalid_i && bank_select_w == MEM_BANK_3_SELECT) begin
            mem_bank_3_r[mem_bank_addr_w] <= Arbiter_MBM_wdata_i;
        end
    end

    assign M_data0_o = (CTRL_MBM_rd_en_i) ? mem_bank_0_r[CTRL_MBM_raddr_i] : {DATA_WIDTH{1'b0}};
    assign M_data1_o = (CTRL_MBM_rd_en_i) ? mem_bank_1_r[CTRL_MBM_raddr_i] : {DATA_WIDTH{1'b0}};
    assign M_data2_o = (CTRL_MBM_rd_en_i) ? mem_bank_2_r[CTRL_MBM_raddr_i] : {DATA_WIDTH{1'b0}};
    assign M_data3_o = (CTRL_MBM_rd_en_i) ? mem_bank_3_r[CTRL_MBM_raddr_i] : {DATA_WIDTH{1'b0}};

endmodule