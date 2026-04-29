module controller #(
    parameter   DATA_WIDTH  = 32,
    parameter   WA_WIDTH    = 7,
    parameter   RA_WIDTH    = 3,
    parameter   MA_WIDTH    = 4,
    parameter   VA_WIDTH    = 2
) (
    input  wire                     clk_i,
    input  wire                     rstn_i,

	// From Controller
	input  wire 				    load_flag_i,
	input  wire 				    start_flag_i,
	input  wire 				    done_flag_i,

	// To Controller
	output wire 				    complete_o,
	output wire [1:0]			    state_o,
	
	// To Matrix Bank Memory
    output wire [1:0]               CTRL_MBM_raddr_o,
    output wire                     CTRL_MBM_rd_en_o,
		
	// To Vector Input Bank Memory
	output wire 				    CTRL_VIBM_rd_en_o,
	
	// To Datapath
    output wire                     execute_o
);
    //----------------------------------------------//
    //              Local Parameter                 //
    //----------------------------------------------//
    // State
    localparam s_IDLE               = 0;
    localparam s_LOAD               = 1;
    localparam s_EXEC               = 2;
    localparam s_READ               = 3;

    //----------------------------------------------//
    //                    Wires                     //
    //----------------------------------------------//
    wire                last_row_w;

    //----------------------------------------------//
    //                   Register                   //
    //----------------------------------------------//
    reg [1:0]           current_state_r, next_state_r;
    reg [1:0]           CTRL_MBM_raddr_r;
    //----------------------------------------------//
    //                     FSM                      //
    //----------------------------------------------// 
    always @(posedge clk_i or negedge rstn_i) begin
		if (!rstn_i) begin
			current_state_r <= s_IDLE;
        end else begin
			current_state_r <= next_state_r;
		end		
	end

    always @(*) begin
        case (current_state_r)
            // Checking load_flag_i
            s_IDLE: begin
                if (load_flag_i) begin
                    next_state_r <= s_LOAD;
                end else begin
                    next_state_r <= s_IDLE;
                end
            end
            // Checking start_flag_i
            s_LOAD: begin
                if (start_flag_i) begin
                    next_state_r <= s_EXEC;
                end else begin
                    next_state_r <= s_LOAD;
                end
            end
            // Checking last_row_w
            s_EXEC: begin
                if (last_row_w) begin
                    next_state_r <= s_READ;
                end else begin
                    next_state_r <= s_EXEC;
                end
            end
            // Checking done_flag_i
            s_READ: begin
                if (done_flag_i) begin
                    next_state_r <= s_IDLE;
                end else begin
                    next_state_r <= s_READ;
                end
            end

            default: begin
                next_state_r <= s_IDLE;
            end
        endcase
    end

    //----------------------------------------------//
    //           State Execute                      //
    //----------------------------------------------//
    assign last_row_w = (current_state_r == s_EXEC && CTRL_MBM_raddr_r == 2'd3) ? 1'b1 : 1'b0;
    
    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            CTRL_MBM_raddr_r <= 0;
        end else begin
            if (current_state_r == s_EXEC) begin
                CTRL_MBM_raddr_r <= CTRL_MBM_raddr_r + 1;
            end else begin
                CTRL_MBM_raddr_r <= 0;
            end
        end
    end

    // To matrix bank memory
    assign CTRL_MBM_raddr_o  = CTRL_MBM_raddr_r;
    assign CTRL_MBM_rd_en_o  = (current_state_r == s_EXEC) ? 1'b1 : 1'b0;
    // To vector bank memory
    assign CTRL_VIBM_rd_en_o = CTRL_MBM_rd_en_o;
    // To datapath
    assign execute_o         = CTRL_MBM_rd_en_o;
    assign state_o           = current_state_r;
    //----------------------------------------------//
    //           State READ                         //
    //----------------------------------------------//
    assign complete_o = (current_state_r == s_READ) ? 1'b1 : 1'b0;


endmodule