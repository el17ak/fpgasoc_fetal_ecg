//====================================
// ADC CONFIGURATION MODULE
// For the chosen application, we want specific ADC configuration characteristics.
//====================================

module config_adc(
	input logic word[24],
	output logic SCLK,
	output logic TFSnot,
	output logic SDATA
);
	
	int i;
	
	initial begin
		TFSnot = 1'd1;
		SDATA = 1'd0;
		i = 0;
	end
	
	//Data is read into control register on falling edge of SCLK
	always @(negedge SCLK) begin
		if(TFSnot == 0) begin
			//wait for data hold time to write new bit
			SDATA = word[23 - i];
			i++;
		end
	end

endmodule
