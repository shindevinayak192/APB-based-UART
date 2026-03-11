module uart_fifo(clk_in, rstn, data_in, push, pop, clear, data_out, fifo_empty, fifo_full, count);
	
	parameter 	depth = 16,
				width = 8;
				
	input clk_in;
	input rstn;
	input push;		//write enable 
	input pop;		//read enable
	input clear;
	input [(width - 1):0]data_in;
	output fifo_empty, fifo_full;
	output reg [(width - 1):0]data_out;
	output reg [4:0]count;
	
	//Internal signals and registers
	reg [3:0]ip_count; 		//write pointer
	reg [3:0]op_count;		//read pointer
	reg [(width - 1):0] mem [0:(depth - 1)];
	
	//Write Logic
	always@(posedge clk_in or negedge rstn)
		begin
			if(!rstn || clear)
				begin
					ip_count		<= 		4'd0;
				end
			else if(push && !fifo_full)
				begin
					mem[ip_count]	<= 		data_in;
					ip_count		<=		ip_count	+	1'b1;
				end
		end
	
	//Read Logic
	always@(posedge clk_in or negedge rstn)
		begin
			if(!rstn || clear)
				begin
					data_out	<=		0;
					op_count	<=		0;
				end
			else if(pop && !fifo_empty)
				begin
					data_out	<=		mem[op_count];
					op_count	<=		op_count	+	1'b1;
				end
			else
				data_out		<=		8'bz;
		end
	
	//count Logic
	always@(posedge clk_in or negedge rstn)
		begin
			if(!rstn || clear)
				begin
					count		<=		0;
				end
			else
				begin
					case({push, pop})
						2'b01:	if(!fifo_empty)		count	<=	count	-	1'b1;		//pop only
						2'b10:	if(!fifo_full)		count	<=	count	+	1'b1;		//push only
						2'b11:						count	<=	count;					//both push and pop
						default:					count	<=	count;
					endcase
				end
		end
	
	//Status Flags			
	assign fifo_empty = (count == 5'd0);
	assign fifo_full = (count == 5'd16);
endmodule
