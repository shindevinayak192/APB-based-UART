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
	//state registers
	reg [3:0] next_state;
	
	//next_state logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				tx_state <= IDLE;
			else
				tx_state <= next_state;
		end
	
	//combinational block
	always@(*)
		begin
			busy <= 1'b0;
			tx_buffer <= 8'b0;		
			TXD_tmp <= 1'b1;		//the transmission line TX is normally held at high voltage when it is not transmitting data.
			pop_tx_fifo <= 1'b0;
			bit_counter <= 4'b0;
			
			case(tx_state)
				IDLE: 	begin	
							if(!tx_fifo_empty && enable)
								begin
									next_state <= START;
									tx_buffer <= tx_fifo_out;
									pop_tx_fifo <= 1'b1;
									busy <= 1'b1;
									bit_counter <= 4'b0;
								end
							else
								busy <= 1'b0;
						end
				START: 	begin
							pop_tx_fifo <= 1'b0;
							TXD_tmp <= 1'b0;
							if(	enable)
								begin
									if(bit_counter == 4'hf) 		//here 4'hf represents value '15' in hexadecimal format.
										begin
											bit_counter <= 4'b0;
											next_state <= BIT0;
										end
									else
										begin
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				BIT0: 	begin
							TXD_tmp <= tx_buffer[0];
							if(enable)
								begin
									if(bit_counter == 4'hf) 
										begin
											bit_counter <= 4'b0;
											next_state <= BIT1;
										end
									else
										begin
											next_state <= BIT0;
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				BIT1:	begin
							TXD_tmp <= tx_buffer[1];
							if(enable)
								begin
									if(bit_counter == 4'hf) 
										begin
											bit_counter <= 4'b0;
											next_state <= BIT2;
										end
									else
										begin
											next_state <= BIT1;
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				BIT2: 	begin
							TXD_tmp <= tx_buffer[2];
							if(enable)
								begin
									if(bit_counter == 4'hf)
										begin
											bit_counter <= 4'b0;
											next_state <= BIT3;
										end
									else
										begin
											next_state <= BIT2;
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				BIT3: 	begin
							TXD_tmp <= tx_buffer[3];
							if(enable)
								begin
									if(bit_counter == 4'hf)
										begin
											bit_counter <= 4'b0;
											next_state <= BIT4;
										end
									else
										begin
											next_state <= BIT3;
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				BIT4: 	begin
							TXD_tmp <= tx_buffer[4];
							if(enable)
								begin
									if(bit_counter == 4'hf)  
										begin
											bit_counter <= 4'b0;
											if(LCR[1:0] != 2'b00))	//here LCR[1:0] == 00 means the number of bits per character are '5 bits'.
												begin
													next_state <= BIT5;
												end
											else
												begin
													if(LCR[3] == 1))	//here when LCR[3] == 1 means 'Parity Enabled'.
														begin
															tx_buffer[7:5] <= 3'b0; //as per above consideration we are considering a 5-bits character so the remaining
																					//bits will not be considered.
															next_state <= PARITY;
														end
													else
														begin
															next_state <= STOP1;
														end
												end
										end
									else
										begin
											next_state <= BIT4;
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end		
				BIT5: 	begin
							TXD_tmp <= tx_buffer[5];
							if(enable)
								begin
									if(bit_counter == 4'hf) 
										begin
											bit_counter <= 4'b0;
											if(LCR[1:0] == 2'b01)	//here the number of bits per character are 6-bits.
												begin
													next_state <= BIT6;
												end
											else
												begin
													if(LCR[3] == 1)
														begin
															tx_buffer[7:6] <= 2'b00;
															next_state <= PARITY;
														end
													else
														begin
															next_state <= STOP1;
														end
												end
										end
									else
										begin
											next_state <= BIT5;
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				BIT6: 	begin
							TXD_tmp <= tx_buffer[6];
							if(enable)
								begin
									if(bit_counter == 4'hf) 
										begin
											bit_counter <= 4'b0;
											if(LCR[1:0] == 2'b11)
												begin
													next_state <= BIT7;
												end
											else
												begin
													if(LCR[3] == 1)
														begin
															tx_buffer[7] <= 1'b0;
															next_state <= PARITY;
														end
													else
														begin
															next_state <= STOP1;
														end
												end
										end
									else
										begin
											next_state <= BIT6;
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end	
				BIT7: 	begin
							TXD_tmp <= tx_buffer[7];
							if(enable)
								begin
									if(bit_counter == 4'hf) 
										begin
											bit_counter <= 4'b0;
											if(LCR[3] == 1)
												begin
													next_state <= PARITY;
												end
											else
												begin
													next_state <= STOP1;
												end
										end
									else
										begin
											next_state <= BIT7;
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				PARITY:	begin
							case(LCR[5:3])
							//LCR[3]: 0--no parity, and 1--parity enabled.
							//LCR[4]: 0--odd parity, and 1--even parity.
							//LCR[5]: 0--stick parity disabled, and 1--the inverse of bit '4' is 
							//			transmitted as parity bit.
								3'b001: TXD_tmp <= ~(^tx_buffer);	//odd PARITY
								3'b011: TXD_tmp <= ^(tx_buffer);	//even PARITY
								3'b101: TXD_tmp <= 1;
								3'b111: TXD_tmp <= 0;
								default: TXD_tmp <= 0;
							endcase
							if(enable)
								begin
									if(bit_counter == 4'hf) 
										begin
											bit_counter <= 4'b0;
											next_state <= STOP1;
										end
									else
										begin
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				STOP1:	begin
							TXD_tmp <= 1'b1;
							if(enable)
								begin
									if(bit_counter == 4'hf) 
										begin
											bit_counter <= 4'b0;
											if(LCR[2] == 1)
												begin
													next_state <= STOP2;
												end
											else	
												begin
													next_state <= IDLE;
												end
										end
									else
										begin
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				STOP2: 	begin
							TXD_tmp <= 1'b1;
							if(enable)
								begin
									if(bit_counter == 4'hf) 
										begin
											bit_counter <= 4'b0;
											if(!tx_fifo_empty)
												begin
													next_state <= START;
												end
											else
												begin
													next_state <= IDLE;
												end
										end
									else
										begin
											bit_counter <= bit_counter + 1'b1;
										end
								end
						end
				default: next_state <= IDLE;
			endcase
		end
		
	assign TXD = LCR[6] ? 1'b0: TXD_tmp;	//LCR[6]: break control bit.
											//		: '0'--break disabled, and '1'--the TX serial data line is forced to logic '0' 
											//			   to indicate break condition.
endmodule
