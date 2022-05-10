//===================================================
// Matrix multiplication hardware accelerator
//===================================================
// Tied to Avalon MM Master interface for communication with SRAM block in FPGA on-chip memory

module matrix_multiplier #(
	parameter GEN_MULTIPLIERS = 16, // Number of multipliers to generate
	parameter GEN_ACCUMULATORS = 4, // Number of accumulators to generate
	parameter MAX_SIZE_MAT = 8*512
)
(
	input logic clk,
	input logic reset,
	input logic clk_en,
	input logic[31:0] read_data, //Input matrix A (32-bit)
	output logic[31:0] write_data, //Output matrix (32-bit)
	output logic[13:0] address, // Address of data to read/write
	output logic chip_select,
	output logic[3:0] byte_enable,
	output logic read,
	output logic write,
	output logic valid
);

	// Avalon Memory-Mapped Interface states
	localparam IDLE_MM = 2'b00;
	localparam WAIT_MM = 2'b01;
	localparam DONE_MM = 2'b10;
	
	logic[1:0] state_mm, next_mm;
	
	// Avalon Memory-Mapped local storage registers
	logic[13:0] address_mm;
	logic rnw; // Read = 1 and Write = 0
	logic[31:0] write_data_mm;
	logic[31:0] read_data_mm;
	
	// Fast access to Avalon MM state
	logic start_mm;
	logic state_active_mm, done_mm;
	assign state_active_mm = (state_mm != STATE_IDLE);
	assign done_mm = (state_mm == STATE_DONE);
	
	// Common state for multiplier and accumulator states
	localparam WAIT = 3'b000;
	
	// Multiplier states
	localparam MULTIPLY = 3'b001;
	localparam DONE_MULTIPLYING = 3'b010;
	localparam FINISHED = 3'b100;
	
	logic[2:0] state, next;
	
	// Accumulator states
	localparam ACCUMULATE = 3'b001;
	localparam DONE_ACCUMULATING = 3'b010;
	
	logic[2:0] state_bis, next_bis;
	
	// Storage for products of matrix multiplication
	logic[31:0] products[MAX_SIZE_MAT*512];

	// Local variables for parallelism and pipelining
	logic unsigned[31:0] multiplications;
	logic unsigned[31:0] accumulations;
	logic unsigned[16:0] iterations_mult, iterations_acc;
	
	// Variables to iterate over entire result matrix, cell by cell
	logic[31:0] count_x, count_y, count_iteration;
	logic next_cell, next_iteration;
	logic rst_counter_cells, rst_counter_iterations;
	
	// Result matrix x counter (row select)
	up_counter counter_x(
		.clk(clk),
		.rst(rst || rst_counter_cells),
		.enable(next_cell),
		.increment(x_increment),
		.count(count_x),
		.max(sizes[0] - 1)
	);
	
	// Result matrix y counter (column select)
	up_counter counter_y(
		.clk(clk),
		.rst(rst || rst_counter_cells),
		.enable(next_cell && (count_cell_x == sizes[0] - 1)),
		.increment(1),
		.count(count_y),
		.max(sizes[2] - 1)
	);

	// Multiplication iterations counter per cell
	up_counter counter_iterations(
		.clk(clk),
		.rst(rst || rst_counter_iterations),
		.enable(next_iteration),
		.increment(1),
		.count(count_iteration),
		.max(iterations_per_cell)
	);
	
	// Accumulation counter per cell
	up_counter counter_accumulations(
		.clk(clk),
		.rst(rst || rst_counter_accumulations),
		.enable(start_accumulating),
		.increment(1),
		.count(count_accumulation),
		.max(sizes[1] - 1)
	);
	
	// Validity registers
	logic valid_mult;
	logic valid_acc;
	
	// Feeding vectors for multipliers and accumulators
	logic[31:0] line_a[GEN_MULTIPLIERS], line_b[GEN_MULTIPLIERS], line_accumulator[GEN_ACCUMULATORS];
	logic[31:0] result_line[GEN_MULTIPLIERS], result_accumulator[GEN_ACCUMULATORS];
	
	wire new_set; // Pulse to begin new accumulation
	
	genvar i;
	generate
		for(i = 0; i < GEN_MULTIPLIERS; i++) begin: loop
			fp_multiply multiplier(
				.aclr(rst),
				.clk_en(state & MULTIPLY),
				.clock(clk),
				.dataa(line_a[i]), // Feed in one value at a time
				.datab(line_b[i]),
				.result(result_line[i]) // Output one value at a time as well
			);
		end
		for(i = 0; i < GEN_ACCUMULATORS; i++) begin: second_loop
			fp_accumulate accumulator(
				.clk(clk),
				.areset(rst),
				.x(line_accumulator[i]), // Line to accumulate on, at every pos clock edge
				.n(new_set),
				.r(result_accumulator[i]), // Updates progressively
				.xo(xo),
				.xu(xu),
				.ao(ao),
				.en(state_bis & ACCUMULATE)
			);
		end
	endgenerate
	
	
	logic[15:0] SIZE_A, SIZE_B, SIZE_C;
	
	// Pipelining and parallelism registers
	logic small_mode;
	logic[15:0] iterations_per_cell, cells_per_iteration, remainder_cells;
	logic[31:0] total_iterations, n_cells;
	
	// Iteration calculator
	always @(SIZE_A or SIZE_B or SIZE_C) begin
		n_cells = SIZE_A * SIZE_C;
		
		// If we have generated more multiplier instances than there are multiplications
		// to perform per cell of the result matrix
		if(SIZE_B < GEN_MULTIPLIERS) begin
			// Find number of cells that can be calculated in one iteration
			cells_per_iteration = GEN_MULTIPLIERS / SIZE_B;
			total_iterations = n_cells / cells_per_iteration;
			small_mode = 1'b1;
		end
		
		// If there are more multiplications to perform per cell of the result matrix
		// than there are multiplier instances
		else begin
			iterations_per_cell = SIZE_B / GEN_MULTIPLIERS;
			remainder_cells = SIZE_B - (iterations_per_cell * GEN_MULTIPLIERS);
			iterations_per_cell = remainder_cells > 0 ? iterations_per_cell + 1 : iterations_per_cell;
			total_iterations = n_cells * iterations_per_cell;
			cells_per_iteration = 16'd1;
			small_mode = 1'b0;
		end
	end
	
	
	integer j, k, l;
	
//=================================================================
// Combinational loop for multiplication inputs/outputs
//=================================================================

	always_comb begin
		if(reset) begin
			start_mm = 1'b0;
		end
		else begin
			next = state;
			start_mm = 1'b0;
			case(state)
			
				// Not activated, waiting for start signal
				WAIT: begin
					if(enable) begin
						rst_counter_cells = 1'b0;
						rst_counter_iterations = 1'b0;
						next = LOAD_SIZES;
					end
					else begin
						rst_counter_cells = 1'b1;
						rst_counter_iterations = 1'b1;
					end
				end
				
				// Load in the sizes of the two matrices
				LOAD_SIZES: begin
					if(!sent_first) begin
						address_mm = 13'd0;
						rnw = 1'b1;
						start_mm = 1'b1;
						sent_first = 1'b1;
					end
					else begin
						if(done_mm) begin
							if(!sent_second) begin
								SIZE_A = read_data_mm[15:0];
								SIZE_B = read_data_mm[31:16];
								address_mm = 4 * 1;
								start_mm = 1'b1;
								sent_second = 1'b1;
							end
							else begin
								SIZE_c = read_data_mm[15:0];
								load_iteration = 16'd0;
								next = LOAD_MAT_A;
							end
						end
					end
				end
				
				// Load values from matrix A memory into multipliers
				LOAD_MAT_A: begin
					if(load_iteration < GEN_MULTIPLIERS) begin
						if(!sent) begin // Send address to memory interface
							address_mm = (((count_cell_x) * SIZE_B) + (count_iteration * GEN_MULTIPLIERS) + j) * 4;
							sent = 1'b1;
						end
						else if(done_mm) begin // If the output is ready, copy
							line_a[load_iteration] = read_data_mm;
							load_iteration = load_iteration + 1;
						end
					end
					else begin
						sent = 1'b0;
						next = LOAD_MAT_B;
						load_iteration = 16'd0;
					end
				end
				
				// Load values from matrix B memory into multipliers
				LOAD_MAT_B: begin
					if(load_iteration < GEN_MULTIPLIERS) begin
						if(!sent) begin // Send address to memory interface
							address_mm = (4096 + (((count_cell_x) * SIZE_B) + (count_iteration * GEN_MULTIPLIERS) + j) * 4);
							sent = 1'b1;
						end
						else if(done_mm) begin // If the output is ready, copy
							line_b[load_iteration] = read_data_mm;
							load_iteration = load_iteration + 1;
						end
					end
					else begin
						sent = 1'b0;
						load_iteration = 16'd0;
						next = MULTIPLY;
					end
				end
				
				
				// Performing multiplication
				MULTIPLY: begin
					if(valid_mult) begin // If the multipliers have run enough cycles
						next = DONE_MULTIPLYING;
					end
				end
				
				
				// Multiplication has ended
				DONE_MULTIPLYING: begin
					// Retrieve current results of the multiplier instances into memory
					if(small_mode) begin
						for(j = 0; j < cells_per_iteration; j++) begin
							for(k = 0; k < SIZE_B; k++) begin
								products[((((count_cell_x + j) * SIZE_C) + count_cell_y) * 512) + (count_iteration * GEN_MULTIPLIERS) + k] = result_line[(j * SIZE_B) + k];
							end
						end
					end
					
					else begin
						for(j = 0; j < GEN_MULTIPLIERS; j++) begin
								products[(((count_cell_x * SIZE_C) + count_cell_y) * 512) + (count_iteration * GEN_MULTIPLIERS) + j] = result_line[j];
						end
					end
					
					// If there are still iterations to complete for this cell
					if(count_iteration < iterations_per_cell) begin
						next_iteration = 1'b1;
						next = LOAD_MAT_A; // Restart multiplication with new values
					end
				
					// If the current cell is NOT the very last one in the result matrix
					else if(count_cell_y < SIZE_C || count_cell_x < SIZE_A) begin
						x_increment = cells_per_iteration; // Account for pipelined
						next_cell = 1'b1;
						rst_counter_iterations = 1'b1;
						next = LOAD_MAT_A; // Restart multiplication with new values
					end
					
					// If it is the last cell
					else begin
						next = FINISHED;
					end
				end
				
				// Final state
				FINISHED: begin
					valid <= 1'b1;
				end
				
			endcase
		end
	end
	
//=================================================================
// Combinational loop for accumulation inputs/outputs
//=================================================================

	logic[31:0] coord_x, coord_y;
	
	always_comb begin
		next_bis = state_bis;
		coord_x = coord_x;
		coord_y = coord_y;
		new_set = 1'b0;
		start_accumulating = 1'b0;
		case(state_bis)
		
			WAIT: begin
				if(count_cell_x > 0) begin
					coord_x = 32'd0;
					coord_y = 32'd0;
					next_bis = ACCUMULATE;
				end
			end
			
			// Active accumulation stage
			ACCUMULATE: begin
				// Retrieve product to accumulate
				
				for(j = 0; j < GEN_ACCUMULATORS; j++) begin
					line_accumulator[j] = products[((((coord_x) * SIZE_C) + coord_x + j) * 512) + count_accumulation];
				end
				
				start_accumulating = 1'b1;
				if(valid_acc) begin
					next_bis = DONE_ACCUMULATING;
				end
			end
			
			
			// Once the accumulation has been completed
			DONE_ACCUMULATING: begin
				if(retrieve_iteration < GEN_ACCUMULATORS) begin
				
				end
			end
			
			// Output of accumulators ready
			SEND_OUTPUT: begin
				if(!active_mm) begin
					
					next = FINISHED;
					// If this the last item in the result matrix
					if((coord_x == SIZE_C - 1) && (coord_y == sizes[0] - 1)) begin
						next_bis = FINISHED;
					end
					
					// If this is the last item in the column
					else if((coord_x == SIZE_C - 1) && (coord_x < count_cell_x || coord_y < count_cell_y)) begin
						new_set = 1'b1; // Reset the accumulator for a new set
						coord_x = 32'd0;
						coord_y = coord_y + 1;
						next_bis = ACCUMULATE;
					end
					
					// Otherwise (with verification that multiplication has finished for cell)
					else if(coord_x < count_cell_x || coord_y < count_cell_y) begin
						new_set = 1'b1; // Reset the accumulator for a new set
						coord_x = coord_x + 1;
						next_bis = ACCUMULATE;
						
					end
				end
			end
			
			FINISHED: begin
				valid = 1'b1;
			end
			
		endcase
	end
	
//===============================================
// Avalon Memory-Mapped Interface state loop
//===============================================	
	
	always_comb begin
		if(reset) begin
			address = 13'd0; // defaults
			read = 1'b0;
			write = 1'b0;
			write_data = 32'd0;
			read_data_mm = 32'd0;
		end
		else begin
			case(state_mm)
				// Waiting for request to access SRAM
				IDLE_MM: begin
					if(start_mm) begin // If triggered
						address = address_mm;
						if(rnw) begin // READ
							read = 1'b1;
							write = 1'b0;
						end
						else begin // WRITE
							read = 1'b0;
							write = 1'b1;
							write_data = write_data_mm;
						end
						next = DONE_MM;
					end
					else begin
						address = 13'd0; // defaults
						read = 1'b0;
						write = 1'b0;
						write_data = 32'd0;
						read_data_mm = 32'd0;
						next_mm = IDLE_MM;
					end
				end
				
				// Valid output on read_data from SRAM
				DONE_MM: begin
					// Retrieve requested data if READ
					if(rnw) begin
						read_data_mm = read_data;
					end
					next_mm = IDLE_MM;
				end
				
			endcase
		end
	end
	
	
//=================================================================
// Flip-flop to keep track of three parallel states
//=================================================================
	
	always_ff @(posedge clk or posedge rst) begin
		if(rst) begin
			state <= WAIT; // defaults
			state_bis <= WAIT;
			state_mm <= WAIT_MM;
		end
		else begin
			state <= next;
			state_bis <= next_bis;
			state_mm <= next_mm;
		end
	end

endmodule
