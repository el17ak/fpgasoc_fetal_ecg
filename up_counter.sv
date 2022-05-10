module up_counter #(
	parameter WIDTH = 32,
	parameter MAX_VALUE = 32
)
(
	input logic clk,
	input logic rst,
	input logic enable,
	input logic[8:0] increment,
	output logic[WIDTH-1:0] count,
	output logic max
);

	always @(posedge clk or posedge rst) begin
		if(rst) begin
			max <= 1'b0;
			count <= {(WIDTH){1'b0}};
		end
		else if(enable) begin
			if(count >= MAX_VALUE) begin
				max <= 1'b1;
				count <= {(WIDTH){1'b0}};
			end
			else begin
				max <= 1'b0;
				count <= count + increment;
			end
		end
	end

endmodule
