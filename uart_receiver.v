module uart_receiver(PCLK, PRESETn, RXD, pop_rx_fifo, enable, LCR, rx_idle, 
					rx_fifo_out, rx_fifo_count, push_rx_fifo, rx_fifo_empty,
					rx_fifo_full, rx_overrun, parity_error, framing_error, 
					break_error, time_out);
					
	//Port declarations
	input PCLK;
	input PRESETn;
	input RXD;								//Pin to receive serial data.
	input pop_rx_fifo;
	input enable;							//Baud pulse for serial data transmission.
	input [7:0]LCR;
	input clear_fifo;
	output reg rx_idle;
	output [7:0]rx_fifo_out;
	output [4:0]rx_fifo_count;
	output reg push_rx_fifo;
	output rx_fifo_empty;
	output rx_fifo_full;
	output reg rx_overrun;					//overrrun flag
	output reg parity_error;
	output reg framing_error;
	output break_error;
	output time_out;
	
	//States
	localparam			IDLE	= 4'b0000;	//waiting for start bit.
	localparam			START	= 4'b0001;	//validating the start bit.
	localparam			BIT0	= 4'b0010;	//states for receiving data bits 0 to 7.
	localparam			BIT1	= 4'b0011;
	localparam			BIT2	= 4'b0100;
	localparam			BIT3	= 4'b0101;
	localparam			BIT4	= 4'b0110;
	localparam			BIT5	= 4'b0111;
	localparam			BIT6	= 4'b1000;
	localparam			BIT7	= 4'b1001;
	localparam			PARITY	= 4'b1010;	//checking the parity bit.
	localparam			STOP1	= 4'b1011;	//checking first stop bit.
	localparam			STOP2	= 4'b1100;	//checking second stop bit.	
	
	//Internal signals and registers
	reg [3:0]rx_state;						//current state of the FSM.
	reg [3:0]bit_counter;					//counter for tracking bits received.
	reg [7:0]rx_buffer;						//buffer to store received bits.
	wire [7:0]brc_value;					//break counter value.
	reg framing_error_temp;					//to check the break error then update the framing error.
	reg [9:0]toc_value;						//timeout counter value.
	reg [7:0]counter_b;						//break counter.
	reg [9:0]counter_t;						//timeout counter.
	reg parity_bit;
	reg temp_RXD;							//used for rx synchronization
	reg stable_RXD;							//used for rx synchronization
	
	//Break logic
	reg break_error_reg;
	assign break_error 	= break_error_reg;
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				break_error_reg	<=	1'b0;
			//Break detected when counter_b reaches '0'.
			else if(enable && (counter_b == 8'd1) && !stable_RXD)
				break_error_reg	<= 	1'b1;
			//Clear break when line goes high again.
			else if(stable_RXD)
				break_error_reg	<=	1'b0;
		end
	
	//Timeout logic
	reg time_out_reg;
	assign time_out 	= time_out_reg;
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				time_out_reg	<=	1'b0;
			//Timeout event: counter just reached '0'.
			else if(enable && (counter_t == 10'd1) && !rx_fifo_empty)
				time_out_reg	<=	1'b1;
			else if(push_rx_fifo || pop_rx_fifo || rx_fifo_empty)
				time_out_reg	<=	1'b0;
		end
	
	//uart_fifo instantiation
	uart_fifo rx_fifo(	.clk_in(PCLK), 
						.rstn(PRESETn), 
						.data_in(rx_buffer), 
						.push(push_rx_fifo), 
						.pop(pop_rx_fifo),
						.clear(clear_fifo),
						.data_out(rx_fifo_out), 
						.fifo_empty(rx_fifo_empty), 
						.fifo_full(rx_fifo_full), 
						.count(rx_fifo_count));
						
	//Dual Clock Sync (DCS) or Dual Flop Cros Domain.
	//RX Synchronizer block.
	always@(posedge PCLK)
		begin
			temp_RXD	<=	RXD;
			stable_RXD	<=	temp_RXD;
		end
	
	//FSM logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				begin
					rx_state		<= IDLE;
					bit_counter 	<= 4'd0;
					rx_buffer 		<= 8'd0;
					push_rx_fifo 	<= 1'b0;
					rx_overrun		<= 1'b0;
					parity_error	<= 1'b0;
					framing_error	<= 1'b0;
					rx_idle			<= 1'b0;
					parity_bit		<= 1'b0;
				end
			else
				begin
					push_rx_fifo	<= 1'b0;
					case(rx_state)
						IDLE: 	begin
									bit_counter	<= 4'd0;
									rx_buffer	<= 8'd0;
									rx_idle		<= 1'b1;
									if(!stable_RXD && !break_error)
										begin
											rx_state 	<= START;
											rx_idle		<= 1'b0;
										end
								end
						START: 	begin	
									if(enable)
										begin
											if(bit_counter == 4'h7)
												begin
													if(!stable_RXD)
														begin
															rx_state	<= BIT0;
															bit_counter	<= 4'd0;
														end
													else
														begin
															rx_state	<= IDLE;
														end
												end
											else
												begin
													bit_counter	<= bit_counter + 1'b1;
												end
										end
								end
						BIT0:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter		<= 4'd0;
													rx_state		<= BIT1;
													rx_buffer[0]	<= stable_RXD;
												end
											else
												begin
													bit_counter		<= bit_counter + 1'b1;
												end
										end
								end
						BIT1:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter		<= 4'd0;
													rx_state		<= BIT2;
													rx_buffer[1]	<= stable_RXD;
												end
											else
												begin
													bit_counter		<= bit_counter + 1'b1;
												end
										end
								end
						BIT2:	begin
									if(enable)
										begin	
											if(bit_counter == 4'hf)
												begin
													bit_counter		<= 4'd0;
													rx_state		<= BIT3;
													rx_buffer[2]	<= stable_RXD;
												end
											else
												begin
													bit_counter		<= bit_counter + 1'b1;
												end
										end
								end
						BIT3:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter		<= 4'd0;
													rx_state		<= BIT4;
													rx_buffer[3]	<= stable_RXD;
												end
											else
												begin
													bit_counter		<= bit_counter + 1'b1;
												end
										end
								end
						BIT4:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter		<= 4'd0;
													rx_buffer[4]	<= stable_RXD;
													if(LCR[1:0] != 0)
														begin
															rx_state	<= BIT5;
														end
													else
														begin
															if(LCR[3] == 1)
																begin
																	rx_state	<= PARITY;
																end
															else
																begin
																	rx_state	<= STOP1;
																end
														end
												end
											else
												begin
													bit_counter	<= bit_counter + 1'b1;
												end
										end
								end
						BIT5:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter		<= 4'd0;
													rx_buffer[5]	<= stable_RXD;
													if(LCR[1:0] > 2'b01)
														begin
															rx_state		<= BIT6;
														end
													else
														begin
															if(LCR[3] == 1)
																begin
																	rx_state	<= PARITY;
																end
															else
																begin
																	rx_state	<= STOP1;
																end
														end
												end
											else
												begin
													bit_counter	<= bit_counter + 1'b1;
												end
										end
								end
						BIT6:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter		<= 4'd0;
													rx_buffer[6]	<= stable_RXD;
													if(LCR[1:0] == 2'b11)
														begin
															rx_state	<= BIT7;
														end
													else
														begin
															if(LCR[3] == 1)
																begin
																	rx_state	<= PARITY;
																end
															else
																begin
																	rx_state	<= STOP1;
																end
														end
												end
											else
												begin
													bit_counter	<= bit_counter + 1'b1;
												end
										end
								end
						BIT7:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter		<= 4'd0;
													rx_buffer[7]	<= stable_RXD;
													if(LCR[3] == 1)
														begin
															rx_state	<= PARITY;
														end
													else
														begin
															rx_state	<= STOP1;
														end
												end
											else
												begin
													bit_counter	<= bit_counter + 1'b1;
												end
										end
								end
						PARITY:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter	<= 4'd0;
													rx_state	<= STOP1;
													//Calculate expected parity from data only.
													case(LCR[5:3])
														3'b001:	parity_bit	<=	~(^rx_buffer);	//odd PARITY
														3'b011:	parity_bit	<=   ^rx_buffer; 	//even PARITY
														3'b101:	parity_bit	<=	1'b1;			//stick 1
														3'b111:	parity_bit	<=	1'b0;			//stick 0
														default: parity_bit	<=	1'b0;
													endcase
													//Compare with received parity bit.
													parity_error	<=	(parity_bit	!=	stable_RXD);
												end
											else
												begin
													bit_counter	<=  bit_counter + 1'b1;
												end
										end
								end
						STOP1:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter	<=	4'd0;
													framing_error_temp	<=	~stable_RXD;
													rx_state	<=	STOP2;
												end
											else
												begin
													bit_counter	<=	bit_counter + 1'b1;
												end
										end
								end
						STOP2:	begin
									if(enable)
										begin
											if(bit_counter == 4'hf)
												begin
													bit_counter	<=	4'd0;
													//Framing error check
													if(break_error)
														framing_error		<=	1'b0;
													else
														framing_error		<=	framing_error_temp;
													//Overrun check
													if(rx_fifo_full)
														rx_overrun			<=	1'b1;
													else
														begin
															rx_overrun		<=	1'b0;
															push_rx_fifo	<=	1'b1;
														end
														
													rx_state				<=	IDLE;
												end
											else
												begin
													bit_counter	<=	bit_counter + 1'b1;
												end
										end
								end
					endcase
				end
		end
		
	//Timeout value logic
	always@(*)
		begin
			case(LCR[3:0])
				4'b0000:							toc_value	=	10'd447;	//7 bits
				4'b0100:							toc_value	=	10'd479;	//7.5 bits
				4'b0001, 4'b1000:					toc_value	=	10'd511;	//8 bits
				4'b1100:							toc_value	=	10'd543;	//8.5 bits
				4'b0010, 4'b0101, 4'b1001:			toc_value	=	10'd575;	//9 bits
				4'b0011, 4'b0110, 4'b1010, 4'b1101:	toc_value	=	10'd639;	//10 bits
				4'b0111, 4'b1011, 4'b1110:			toc_value	=	10'd703;	//11bits
				4'b1111:							toc_value	=	10'd767;	//12bits
				default:							toc_value	=	10'd639;
			endcase
		end
	
	assign	brc_value	=	toc_value[9:2];		//the same as timeout but 1 instead of 4 character times.
	
	//Break counter logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				counter_b	<=	brc_value;	//8'd159
			else if(stable_RXD)
				counter_b	<=	brc_value;	//character time length - 1
			else if(enable && (counter_b != 8'd0))
				counter_b	<=	counter_b	-	1'b1;
		end
	
	//Timeout counter logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				counter_t	<=	toc_value;		//10'd639	//10 bits for the default 8N1
			else
				begin
					if(rx_fifo_empty)
						counter_t	<=	toc_value;
					else if (push_rx_fifo || pop_rx_fifo)		//counter is reset when RX FIFO is empty, accessed or above trigger level
						counter_t	<=	toc_value;		
					else if(enable && (counter_t != 10'd0))
						counter_t	<= 	counter_t	-	1'b1;
				end
		end
		
endmodule
