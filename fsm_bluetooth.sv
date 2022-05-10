package fsm_bluetooth;

	typedef enum logic[2:0]{
		WAIT = 3'b000,
		TRANSMIT = 3'b001,
		DONE = 3'b010
	} state_global;
	
	typedef enum logic[3:0]{
		IDLE = 4'b0000,
		TX_START_BIT = 4'b0001,
		TX_DATA_BITS = 4'b0010,
		TX_STOP_BIT= 4'b0100,
		CLEANUP = 4'b1000
	} state_tx;

endpackage
