module bluetooth_cmd #(
	parameter N_BITS = 8,
	parameter CLKS_PER_BIT = 55
)
(
	input logic clk,
	input logic in_tx_start,
	input logic[N_BITS-1:0] in_tx_cmd, 
	output logic out_tx_active,
	output logic out_tx_serial,
	output logic out_tx_done
);

	import fsm_bluetooth::*;
   
	state_tx state = IDLE;
	logic[N_BITS-1:0] count = 0;
	logic[2:0] bit_index = 0;
	logic[N_BITS-1:0] loc_tx_data = 0;
	logic loc_tx_done = 0;
	logic loc_tx_active = 0;
     
	always_ff @(posedge clk) begin
		case (state)
		 
		IDLE: begin
			out_tx_serial <= 1'b1;
			loc_tx_done <= 1'b0;
			count <= 0;
			bit_index <= 0;
             
			if(in_tx_start == 1'b1) begin
				loc_tx_active <= 1'b1;
				loc_tx_data <= in_tx_data;
				state <= TX_START_BIT;
			end
			else
				state <= IDLE;
		end // case: s_IDLE
         
         
      //Prompt to send start bit
		TX_START_BIT: begin
			out_tx_serial <= 1'b0;
             
			// Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
			if (count < CLKS_PER_BIT-1) begin
				count <= count + 1;
				state <= TX_START_BIT;
			end
			else begin
				count <= 0;
				state <= TX_DATA_BITS;
			end
		end // case: s_TX_START_BIT
         
         
      //Prompt to send N data bits         
		TX_DATA_BITS: begin
			out_tx_serial <= loc_tx_data[bit_index];
             
			if (count < CLKS_PER_BIT-1) begin
				count++;
				state <= TX_DATA_BITS;
			end
			else begin
				count <= 0;
                 
				// Check if we have sent out all bits
				if (bit_index < N_BITS-1) begin
					bit_index++;
					state <= TX_DATA_BITS;
				end
				else begin
					bit_index <= 0;
					state <= TX_STOP_BIT;
				end
			end
		end // case: s_TX_DATA_BITS
         
         
      //Prompt to send stop bit
		TX_STOP_BIT: begin
			out_tx_serial <= 1'b1;
             
			// Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
			if (count < CLKS_PER_BIT-1) begin
				count++;
				state <= TX_STOP_BIT;
			end
			else begin
				loc_tx_done <= 1'b1;
				count <= 0;
				state <= CLEANUP;
				loc_tx_active <= 1'b0;
			end
		end // case: s_Tx_STOP_BIT
         
         
        // Stay here 1 clock
		CLEANUP: begin
			loc_tx_done <= 1'b1;
			state <= IDLE;
		end
         
         
		default :
			state <= IDLE;
         
		endcase
	end
 
	assign out_tx_active = loc_tx_active;
	assign out_tx_done = loc_tx_done;
   
endmodule
