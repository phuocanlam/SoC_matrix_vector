module vector_input_bank_mem #(
    parameter ADDR_WIDTH = 2,
    parameter DATA_WIDTH = 32
) (
    input  wire                     clk_i,

    // From Arbiter
    input  wire        [ADDR_WIDTH-1:0] Arbiter_VIBM_waddr_i,
    input  wire                         Arbiter_VIBM_awvalid_i,
    input  wire        [DATA_WIDTH-1:0] Arbiter_VIBM_wdata_i,

    // From controller
    input  wire                         CTRL_VIBM_rd_en_i,

    // To datapath
    output wire signed [DATA_WIDTH-1:0] VI_data0_o,
    output wire signed [DATA_WIDTH-1:0] VI_data1_o,
    output wire signed [DATA_WIDTH-1:0] VI_data2_o,
    output wire signed [DATA_WIDTH-1:0] VI_data3_o
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

    //----------------------------------------------//
    //              Reg declaration                 //
    //----------------------------------------------//
    reg [DATA_WIDTH-1:0]  mem_bank_0_r;
    reg [DATA_WIDTH-1:0]  mem_bank_1_r;
    reg [DATA_WIDTH-1:0]  mem_bank_2_r;
    reg [DATA_WIDTH-1:0]  mem_bank_3_r;

    //----------------------------------------------//
    //         Combinational circuits               //
    //----------------------------------------------//
    assign bank_select_w = Arbiter_VIBM_waddr_i[1:0];

    //----------------------------------------------//
    //            Sequential circuits               //
    //----------------------------------------------//

    always @(posedge clk_i) begin
        if (Arbiter_VIBM_awvalid_i && bank_select_w == MEM_BANK_0_SELECT) begin
            mem_bank_0_r <= Arbiter_VIBM_wdata_i;
        end

        if (Arbiter_VIBM_awvalid_i && bank_select_w == MEM_BANK_1_SELECT) begin
            mem_bank_1_r <= Arbiter_VIBM_wdata_i;
        end

        if (Arbiter_VIBM_awvalid_i && bank_select_w == MEM_BANK_2_SELECT) begin
            mem_bank_2_r <= Arbiter_VIBM_wdata_i;
        end
        
        if (Arbiter_VIBM_awvalid_i && bank_select_w == MEM_BANK_3_SELECT) begin
            mem_bank_3_r <= Arbiter_VIBM_wdata_i;
        end
    end

    assign VI_data0_o = (CTRL_VIBM_rd_en_i) ? mem_bank_0_r : {DATA_WIDTH{1'b0}};
    assign VI_data1_o = (CTRL_VIBM_rd_en_i) ? mem_bank_1_r : {DATA_WIDTH{1'b0}};
    assign VI_data2_o = (CTRL_VIBM_rd_en_i) ? mem_bank_2_r : {DATA_WIDTH{1'b0}};
    assign VI_data3_o = (CTRL_VIBM_rd_en_i) ? mem_bank_3_r : {DATA_WIDTH{1'b0}};

endmodule