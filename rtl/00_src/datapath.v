module datapath #(
    parameter DATA_WIDTH = 32
) (
    input  wire                         clk_i,    
    input  wire                         rstn_i,

    // From Controller
    input  wire                         execute_i,

    // From Matrix Memory
    input  wire signed [DATA_WIDTH-1:0] M_data0_i,
    input  wire signed [DATA_WIDTH-1:0] M_data1_i,
    input  wire signed [DATA_WIDTH-1:0] M_data2_i,
    input  wire signed [DATA_WIDTH-1:0] M_data3_i,

    // From Vector Memory in
    input  wire signed [DATA_WIDTH-1:0] VI_data0_i,
    input  wire signed [DATA_WIDTH-1:0] VI_data1_i,
    input  wire signed [DATA_WIDTH-1:0] VI_data2_i,
    input  wire signed [DATA_WIDTH-1:0] VI_data3_i,

    // To Vector Memory out
    output reg  signed [DATA_WIDTH-1:0] VO_data_o,
    output reg                          VO_data_valid_o
);

    //----------------------------------------------//
    //              Wire declaration                //
    //----------------------------------------------//
    wire signed [DATA_WIDTH*2-1:0]      product_0_w;
    wire signed [DATA_WIDTH*2-1:0]      product_1_w;
    wire signed [DATA_WIDTH*2-1:0]      product_2_w;
    wire signed [DATA_WIDTH*2-1:0]      product_3_w;

    wire signed [DATA_WIDTH-1:0]        sum_0_w;
    wire signed [DATA_WIDTH-1:0]        sum_1_w;
    wire signed [DATA_WIDTH-1:0]        sum_2_w;

    //----------------------------------------------//
    //          Combinational circuits              //
    //----------------------------------------------//
    assign product_0_w = M_data0_i * VI_data0_i;
    assign product_1_w = M_data1_i * VI_data1_i;
    assign product_2_w = M_data2_i * VI_data2_i;
    assign product_3_w = M_data3_i * VI_data3_i;

    assign sum_0_w = {product_0_w[DATA_WIDTH*2-1:DATA_WIDTH*2-1], product_0_w[DATA_WIDTH-2:0]} + {product_1_w[DATA_WIDTH*2-1:DATA_WIDTH*2-1], product_1_w[DATA_WIDTH-2:0]};

    assign sum_1_w = {product_2_w[DATA_WIDTH*2-1:DATA_WIDTH*2-1], product_2_w[DATA_WIDTH-2:0]} + {product_3_w[DATA_WIDTH*2-1:DATA_WIDTH*2-1], product_3_w[DATA_WIDTH-2:0]};
    
    assign sum_2_w = sum_0_w + sum_1_w;

    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            VO_data_o       <= 0;
            VO_data_valid_o <= 0;
        end else begin
            if (execute_i) begin
                VO_data_o       <= sum_2_w;
                VO_data_valid_o <= 1;
            end else begin
                VO_data_o       <= 0;
                VO_data_valid_o <= 0;
            end
        end
    end
endmodule