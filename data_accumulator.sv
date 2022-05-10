module data_accumulator #(
	parameter N_SAMPLES = 512,
	parameter N_CHANNELS = 8,
	parameter BAUD_RATE = 912645
)
(
	input logic clk,
	input logic rst,
	input logic enable,
	input logic[1:0] in_data,
	output logic[(N_SAMPLES*N_CHANNELS*32)-1:0] out_data,
	output logic ready
);



	logic[31:0] store[N_SAMPLES][N_CHANNELS];
	
	wire next_count;
	logic[9:0] sample_count;
	up_counter #(.WIDTH(10), .MAX_VALUE(N_SAMPLES)) sample_counter(
		.clk(clk),
		.rst(rst),
		.enable(next_count && enable),
		.count(sample_count),
		.max(ready)
	);
	
	

endmodule
