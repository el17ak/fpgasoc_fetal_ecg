module collect_adc_data(
	input logic SDATA,
	input logic CASCOUT,
	output logic CASCIN,
	output logic SCLK,
	output logic RFS,
	output logic[31:0] mat_out[4]
);

	initial begin
		CASCIN = 1'd0;
		RFS = 1'd1;
		CASCIN = 1'd1;
		//t23 = 1/fCLKIN = 1/8 = 0.125 ns min?
		CASCIN = 1'd0;
		//t26 setup time = 1/fCLKIN + 30 = 0.125 + 30 = 0.425 ns min?
		RFS = 1'd0;
		//wait t27 = 30 ns min, before taking SCLK into account
	end
	
	int i, c = 0;
	
	//Every falling edge of SCLK indicates that valid data can be read from SDATA
	always @(negedge SCLK) begin
		//First, check whether the bit is the last one of all 128
		if((CASCOUT == 0) && (RFS == 0)) begin
			//Assign the bit to its respective place in the correct channel
			mat_out[c][31 - i] = SDATA;
			i++; //Increment the bit counter for every bit reading
			if(((i+1)%32) == 0) begin
				c++; //Increment the channel counter every 32 bits
			end
		end
		else if((CASCOUT == 1) && (RFS == 0)) begin
			mat_out[3][31] = SDATA;
		end
	end

	//For end of each transmission, the next rising edge of SCLK triggers RFS to HIGH.
	always @(posedge SCLK) begin
		//First, check whether the last bit pulse is activated.
		if(CASCOUT == 1) begin
			//wait t29 = 50 ns min
			RFS = 1'd1;
			
		end
	end
	
endmodule
