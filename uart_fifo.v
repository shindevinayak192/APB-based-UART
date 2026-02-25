module uart_fifo (clk_in, rstn, data_in, push, pop, data_out, fifo_empty, fifo_full, count);

    parameter depth = 16,
              width = 8;

    // -------------------------------------------------
    // Port Declarations
    // -------------------------------------------------
    input clk_in;
    input rstn; //active low synchronous reset
    input push; //similar to write_en
    input pop;  //similar to read_en
    input [(width-1):0] data_in;

    output fifo_empty; //high when fifo is empty
    output fifo_full;  //high when fifo is full
    output reg [width-1:0] data_out;
    output reg [$clog2(depth+1)-1:0] count; //$clog2 is same as log2[N] that means log of N to the base 2.

    // -------------------------------------------------
    // Internal Signals
    // -------------------------------------------------
    reg [$clog2(depth)-1:0] ip_count;
    reg [$clog2(depth)-1:0] op_count;

    reg [width-1:0] mem [0:depth-1];

    wire push_valid;
    wire pop_valid;

    // -------------------------------------------------
    // Valid Operation Logic : Provides boundary protection. Prevents overflow and underflow.
    // -------------------------------------------------
    assign push_valid = push && (!fifo_full || pop);
    assign pop_valid  = pop  && (!fifo_empty || push);

    // -------------------------------------------------
    // Sequential Logic
    // -------------------------------------------------
    always @(posedge clk_in or negedge rstn) 
		begin
			if (!rstn) 	//here we are not resetting the whole memory to '0' bcoz it is not needed. FIFO correctness does NOT depend on memory being 'zero'.
						//We use fifo_empty == (count == 0). So if FIFO is empty we will never allow 'pop'. So we never read uninitialized memory.
				begin
					ip_count <= 0;
					op_count <= 0;
					count    <= 0;
					data_out <= 0;
				end
			else 
				begin

					// Write Operation
					if (push_valid) begin
						mem[ip_count] <= data_in;
						ip_count <= ip_count + 1'b1;
					end

					// Read Operation
					if (pop_valid) begin
						data_out <= mem[op_count];
						op_count <= op_count + 1'b1;
					end

					// Count Update
					if (push_valid && !pop_valid)
						count <= count + 1'b1;
					else if (!push_valid && pop_valid)
						count <= count - 1'b1;
					else
						count <= count;

				end
		end
	
	  //-------------------------------------------------
    // Status Flags
    // -------------------------------------------------
    assign fifo_empty = (count == 0);
    assign fifo_full  = (count == depth);

endmodule
