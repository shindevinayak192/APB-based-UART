module uart_transmitter(PCLK, PRESETn, PWDATA, tx_fifo_push, enable, LCR, tx_fifo_count, busy, tx_fifo_empty, tx_fifo_full, TXD);

	input PCLK; 
	input PRESETn; 
	input tx_fifo_push;
	input enable;
	input [7:0]PWDATA;
	input [7:0]LCR;
	output reg [4:0]tx_fifo_count;
	output reg busy;
	output tx_fifo_empty, tx_fifo_full;
	output reg TXD;
	
	//states
	localparam			IDLE	= 4'b0000;	//waiting for data to transmit.
	localparam			START	= 4'b0001;	//start bit transmission state.
	localparam			BIT0	= 4'b0010;	//states for transmitting data bits 0 to 7.
	localparam			BIT1	= 4'b0011;
	localparam			BIT2	= 4'b0100;
	localparam			BIT3	= 4'b0101;
	localparam			BIT4	= 4'b0110;
	localparam			BIT5	= 4'b0111;
	localparam			BIT6	= 4'b1000;
	localparam			BIT7	= 4'b1001;
	localparam			PARITY	= 4'b1010;	//parity bit transmission state.
	localparam			STOP1	= 4'b1011;	//first stop bit transmission state.
	localparam			STOP2	= 4'b1100;	//second stop bit transmission state.	
	
	//Internal registers and wires
	reg [3:0]tx_state;		//register representing the current state of the transmit fsm.
	reg [3:0]bit_counter;	//counter for tracking the number of clock cycles or bits transmitted in the current state.	
	reg [7:0]tx_buffer;		//register holding the current byte to be transmitted.
	wire [7:0]tx_fifo_out;	//wire for reading data from the transmit FIFO.
	reg pop_tx_fifo;		//signal to pop data from the transmit FIFO. Active high.
	reg TXD_tmp;			//temporary register holding the current value to be transmitted on the TXD line.
	reg parity;				//register holding the parity value.
	reg parity_data;		//register holding temporary parity value based on number of bits in a character.
	
	//uart_fifo instantiation
	uart_fifo tx_fifo(	.clk_in(PCLK), 
						.rstn(PRESETn), 
						.data_in(PWDATA), 
						.push(tx_fifo_push), 
						.pop(pop_tx_fifo), 
						.data_out(tx_fifo_out), 
						.fifo_empty(tx_fifo_empty), 
						.fifo_full(tx_fifo_full), 
						.count(tx_fifo_count));
	
	//baud pulse logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				bit_counter	<=	4'd0;
			else if(enable)
				begin
					if(bit_counter == 4'hf)
						bit_counter <= 4'd0;
					else
						bit_counter	<=	bit_counter	+ 1'b1;
				end
		end
		
	//internal FIFO input 'pop' logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				pop_tx_fifo	<=	1'b0;
			else if(!tx_fifo_empty	&&	tx_state == START	&&	(bit_counter == 4'h7)	&&	enable)
				pop_tx_fifo	<=	1'b1;
			else
				pop_tx_fifo	<=	1'b0;
		end
	
	//FSM logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				tx_state	<=	IDLE;
			else if(enable)
				begin
					case(tx_state)
						IDLE: 	begin	
									if(!tx_fifo_empty && bit_counter == 4'hf)
										begin
											tx_state <= START;
										end
								end
						START: 	begin
									if(bit_counter == 4'hf) 		//here 4'hf represents value '15' in hexadecimal format.
										begin
											tx_state <= BIT0;
										end
								end
						BIT0: 	begin
									if(bit_counter == 4'hf) 
										begin
											tx_state <= BIT1;
										end
								end
						BIT1:	begin
									if(bit_counter == 4'hf) 
										begin
											tx_state <= BIT2;
										end
								end
						BIT2: 	begin
									if(bit_counter == 4'hf)
										begin
											tx_state <= BIT3;
										end
								end
						BIT3: 	begin
									if(bit_counter == 4'hf)
										begin
											tx_state <= BIT4;
										end
									end
						BIT4: 	begin
									if(bit_counter == 4'hf)  
										begin
											if(LCR[1:0] != 2'b00)	//here LCR[1:0] == 00 means the number of bits per character are '5 bits'.
												begin
													tx_state <= BIT5;
												end
											else
												begin
													if(LCR[3] == 1)	//here when LCR[3] == 1 means 'Parity Enabled'.
														begin
															tx_state <= PARITY;
														end
													else
														begin
															tx_state <= STOP1;
														end
												end
										end
								end		
						BIT5: 	begin
									if(bit_counter == 4'hf) 
										begin
											if(LCR[1:0] > 2'b01)	//here the number of bits per character are more than 6-bits.
												begin
													tx_state <= BIT6;
												end
											else
												begin
													if(LCR[3] == 1)
														begin
															tx_state <= PARITY;
														end
													else
														begin
															tx_state <= STOP1;
														end
												end
										end
								end
						BIT6: 	begin
									if(bit_counter == 4'hf) 
										begin
											if(LCR[1:0] == 2'b11)
												begin
													tx_state <= BIT7;
												end
											else
												begin
													if(LCR[3] == 1)
														begin
															tx_state <= PARITY;
														end
													else
														begin
															tx_state <= STOP1;
														end
												end
										end
								end	
						BIT7: 	begin
									if(bit_counter == 4'hf) 
										begin
											if(LCR[3] == 1)
												begin
													tx_state <= PARITY;
												end
											else
												begin
													tx_state <= STOP1;
												end
										end
								end
						PARITY:	begin
									if(bit_counter == 4'hf) 
										begin
											if(LCR[2] == 1'b1)
												tx_state <= STOP2;
											else
												tx_state <=	STOP1;
										end
								end
						STOP1:	begin
									if(bit_counter == 4'hf) 
										begin
											if(LCR[2] == 1'b1)
												begin
													tx_state <= STOP2;
												end
											else	
												begin
													tx_state <= IDLE;
												end
										end
								end
						STOP2: 	begin
									if(bit_counter == 4'hf) 
										begin
											tx_state <= IDLE;
										end
								end
						default: tx_state <= IDLE;
					endcase
				end
		end
		
	//TXD_tmp logic
	always@(*)
		begin
			case(tx_state)
				IDLE: 		TXD_tmp = 1'b1;
				START: 		TXD_tmp = 1'b0;
				BIT0: 		TXD_tmp = tx_buffer[0];
				BIT1: 		TXD_tmp = tx_buffer[1];
				BIT2: 		TXD_tmp = tx_buffer[2];
				BIT3: 		TXD_tmp = tx_buffer[3];
				BIT4: 		TXD_tmp = tx_buffer[4];
				BIT5: 		TXD_tmp = tx_buffer[5];
				BIT6: 		TXD_tmp = tx_buffer[6];
				BIT7: 		TXD_tmp = tx_buffer[7];
				PARITY: 	TXD_tmp = parity;
				STOP1: 		TXD_tmp = 1'b1;
				STOP2: 		TXD_tmp = 1'b1;
				default: 	TXD_tmp = 1'b1;
			endcase
		end
	
	//busy logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				busy <= 1'b0;
			else if(tx_state == IDLE)
				busy <= 1'b0;
			else
				busy <= 1'b1;
		end
	
	//tx_buffer logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				begin
					tx_buffer	<=	8'd0;
				end
			else if(enable)
				begin
					if(tx_state == START && bit_counter == 4'd0)
						begin
							case(tx_state)
								2'b00: 	begin	
											tx_buffer[4:0]	<=	tx_fifo_out[4:0];
											tx_buffer[7:5]	<=	3'd0;
										end
								2'b01:	begin
											tx_buffer[5:0]	<=	tx_fifo_out[5:0];
											tx_buffer[7:6]	<=	2'd0;
										end
								2'b10:	begin
											tx_buffer[6:0]	<=	tx_fifo_out[6:0];
											tx_buffer[7]	<=	1'b1;
										end
								2'b11:	tx_buffer	<=	tx_fifo_out;
								default:	tx_buffer	<=	tx_fifo_out;
							endcase
						end
					else if((	tx_state == BIT0 ||
								tx_state == BIT1 || 
								tx_state == BIT2 || 
								tx_state == BIT3 || 
								tx_state == BIT4 || 
								tx_state == BIT5 || 
								tx_state == BIT6 || 
								tx_state == BIT7) 
								&& bit_counter == 4'hf)
						begin
							tx_buffer <= tx_buffer >> 1;
						end
				end
		end
				
	//parity logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				parity <= 1'b0;
			else if(enable && tx_state == START && bit_counter == 4'd0)
				begin	
					if(LCR[3])		//checking parity enable
						begin
							//compute parity only over active characters
							case(LCR[1:0])		//defines the number of bits per character
								2'b00: parity_data = ^tx_buffer[4:0];		//blocking assignment '=' : used for temporary combinational variables used immediately
								2'b01: parity_data = ^tx_buffer[5:0];
								2'b10: parity_data = ^tx_buffer[6:0];
								2'b11: parity_data = ^tx_buffer[7:0];
								default: parity_data = ^tx_buffer[7:0];
							endcase
							
							//parity type decode: even or odd
							case({LCR[5:4]})
								//LCR[3]: 0--no parity, and 1--parity enabled.
								//LCR[4]: 0--odd parity, and 1--even parity.
								//LCR[5]: 0--stick parity disabled, and 1--the inverse of bit '4' is 
								//			transmitted as parity bit.
								2'b00: parity <= ~(parity_data);	//odd PARITY
								2'b01: parity <= 	parity_data;	//even PARITY
								2'b10: parity <= 1'b1;			//odd PARITY but LCR[4] inverse
								2'b11: parity <= 1'b0;			//even PARITY but LCR[4] inverse
								default: parity <= 1'b0;
							endcase
						end
					else
						parity	<=	1'b0;		//disable PARITY
				end
		end
		
	//TXD and LCR[6] checking
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				TXD <= 1'b1;
			//LCR[6]: break control bit.
			//		: '0'--break disabled, and '1'--the TX serial data line is forced to logic '0' 
			//			   to indicate break condition.
			else if(LCR[6])
				TXD	<= 1'b0;
			else
				TXD <= TXD_tmp;
		end
endmodule
