//===========================================
// ADC DATA ACCUMULATOR
// Ingests two 4-channel vectors of 22-bit samples repeatedly and registers this
// data into a larger matrix of size (N mixed signals x M samples).
// Should update for every positive edge of CASCOUT + some delay for validity.
//===========================================

module accumulate_adc_data(
	input logic[31:0] mat_a[4], //ADC-1 output
	input logic[31:0] mat_b[4], //ADC-2 output
	input logic CASCOUT,
	output integer mat[8][512], //Accumulated output of both ADCs
	output logic ready
);

	int j = 32'd512; //Set j to the number M of columns we want in the matrix
	import data_conversion::*;

	initial begin
		mat = '{default:0};
		ready = 1'd0;
	end
	
//==================================
// Accumulation loop: starts adding the data to a larger matrix sample by sample
// (N times). Will only start updating once entire word has been read by the
// collect_adc_data module.
//==================================
	
	always @(posedge CASCOUT) begin
		if(j > 0) begin //Check whether it is last sample of 512 to avoid overflow
			//wait some time
			for(int i = 0; i < 4; i++) begin //Copy each channel
				//Copy the adjusted data (removed info bits) into the final matrix
				mat[i][j] <= to_integer((mat_a[i] & 32'hfffffc00) >>> 10);
				//In this case, copy it to the same index + 4 for the second ADC
				mat[i+4][j] <= to_integer((mat_b[i] & 32'hfffffc00) >>> 10);
			end
			j--; //Switch to next sample
		end
		else begin //If it is last sample, pulse ready signal HIGH
			ready = 1'd1;
			#3; //This pulse identifies the end of matrix filling process
			ready = 1'd0; //Other modules can then retrieve the entire matrix
			mat = '{default:0}; //We need to ensure other modules read before reset
			j = 512;
		end
	end

endmodule
