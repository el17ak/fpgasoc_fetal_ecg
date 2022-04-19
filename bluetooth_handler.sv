module bluetooth_handler #(
	parameter N_SAMPLES = 256,
	parameter N_BITS = 32
)
(
	input logic start,
	input logic[31:0] in_data[N_SAMPLES],
	output logic TX
);

	import fsm_bluetooth::*;

	state_global state, next;

	logic tx_start[2], tx_active[2], tx_serial[2], tx_done[2];
	logic[7:0] tx_cmd;
	logic[N_BITS-1:0] tx_data;
	integer count, next_count = 0;

	bluetooth_cmd commander(
		.clk(clk),
		.in_tx_start(tx_start[0]),
		.in_tx_cmd(tx_cmd), //8-bit ASCII command character
		.out_tx_active(tx_active[0]),
		.out_tx_serial(tx_serial[0]),
		.out_tx_done(tx_done[0])
	);
	
	bluetooth_tx transmitter(
		.clk(clk),
		.in_tx_start(tx_start[1]),
		.in_tx_data(tx_data), //32-bit data sample (single channel)
		.out_tx_active(tx_active[1]),
		.out_tx_serial(tx_serial[1]),
		.out_tx_done(tx_done[1])
	);
	
	
	always_comb begin
		next = state; //Default loopback
		case(state)
			
			WAIT: begin
				tx_start[1] = 1'b0;
				if(start) begin
					next = TRANSMIT;
				end
			end
			
			TRANSMIT: begin
				if(!tx_active[1] || tx_done[1]) begin
					if(count < N_SAMPLES) begin
						tx_data = in_data[count];
						tx_start[1] = 1'b1;
						next_count = count + 1;
					end
					else begin
						next = DONE;
					end
				end
			end
			
			DONE: begin
				tx_start[1] = 1'b0;
			end
		
		endcase
	end
	
	
	always_ff @(posedge clk or posedge rst) begin
		if(rst) begin
			state <= WAIT;
			count <= 0;
		end
		else begin
			state <= next;
			count <= next_count;
		end
	end
	

endmodule
