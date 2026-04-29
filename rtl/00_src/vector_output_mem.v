module vector_output_mem #(
    parameter ADDR_WIDTH = 2,
    parameter DATA_WIDTH = 32
) (
    input  wire                     clk_i,
    input  wire                     rstn_i,

    // From Arbiter
    input  wire        [ADDR_WIDTH-1:0] Arbiter_VOM_raddr_i,
    input  wire                         Arbiter_VOM_arvalid_i,
    output reg         [DATA_WIDTH-1:0] Arbiter_VOM_rdata_o,

    // From Datapath
    input  wire signed [DATA_WIDTH-1:0] VO_data_i,
    input  wire                         VO_data_valid_i
);
    //----------------------------------------------//
    //              Local Parameter                 //
    //----------------------------------------------//
   
    //----------------------------------------------//
    //              Wire declaration                //
    //----------------------------------------------//

    //----------------------------------------------//
    //              Reg declaration                 //
    //----------------------------------------------//
    reg [1:0] mem_addr_r;
    reg [DATA_WIDTH-1:0]  mem_r [0:3];
    //----------------------------------------------//
    //         Combinational circuits               //
    //----------------------------------------------//


    //----------------------------------------------//
    //            Sequential circuits               //
    //----------------------------------------------//
    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            mem_addr_r <= 0;
        end else begin
            if (VO_data_valid_i) begin
                mem_addr_r <= mem_addr_r + 1;
            end else begin
                mem_addr_r <= mem_addr_r;
            end
        end
    end

    always @(posedge clk_i) begin
        if (VO_data_valid_i) begin
            mem_r[mem_addr_r] <= VO_data_i;
        end
    end

    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            Arbiter_VOM_rdata_o <= 0;
        end else begin
            if (Arbiter_VOM_arvalid_i) begin
                Arbiter_VOM_rdata_o <= mem_r[Arbiter_VOM_raddr_i];
            end else begin
                Arbiter_VOM_rdata_o <= 0;
            end
        end
    end

endmodule