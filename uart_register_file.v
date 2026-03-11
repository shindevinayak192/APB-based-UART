module uart_register_file(	PCLK, PRESETn, PSEL, PWRITE, PENABLE, PWDATA, PADDR,
							PRDATA, PREADY, PSLVERR, tx_fifo_count, tx_fifo_empty,
							tx_fifo_full, tx_busy, tx_fifo_we, tx_enable,
							rx_data_out, rx_idle, rx_overrun, parity_error,
							framing_error, break_error, time_out, rx_fifo_count,
							rx_fifo_empty, rx_fifo_full, push_rx_fifo,
							rx_enable, rx_fifo_re, irq, loopback, baud_o, LCR);
	
	//APB interface signals
	input PCLK;
	input PRESETn;
	input PSEL;
	input PWRITE;
	input PENABLE;
	input [31:0]PWDATA;
	input [4:0]PADDR;
	output reg [31:0]PRDATA;
	output PREADY;
	output reg PSLVERR;
	
	//Transmitter related signals
	input [4:0]tx_fifo_count;
	input tx_fifo_empty;
	input tx_fifo_full;
	input tx_busy;
	output reg tx_fifo_we;
	output tx_enable;
	
	//Receiver related signals
	input [7:0]rx_data_out;
	input rx_idle;
	input rx_overrun;
	input parity_error;
	input framing_error;
	input break_error;
	input time_out;
	input [4:0]rx_fifo_count;
	input rx_fifo_empty;
	input rx_fifo_full;
	input push_rx_fifo;
	output rx_enable;
	output reg rx_fifo_re;
	
	//Modem interface related signals
	output reg irq;
	output loopback;
	output reg baud_o;
	
	//FIFO Reset signals
	output reg clear_tx_fifo;
	output reg clear_rx_fifo;
	
	//Line Control Register
	output reg [7:0]LCR;
	
	//define register addresses or offsets using `define
	/* here we divide the following offsets by 4 to get the resultant adresses as defined using `define. 
	   the Data register encapsulates both RXD and TXD, but it changes the direction based on write or read.
		Register Offset Width Access Description 
		RXD 	0x0 	8 	RO 		Receive FIFO output register 
		TXD 	0x0 	8 	WO 		Transmit FIFO input register 
		IER 	0x4 	8 	R/W 	Interrupt Enable Register 
		IIR 	0x8 	8 	RO 		Interrupt Identification Register 
		FCR 	0x8 	8 	WO 		FIFO Control Register 
		LCR 	0xc 	8 	R/W 	Line Control Register 
		MCR 	0x10 	8 	R/W 	Modem Control Register 
		LSR 	0x14 	8 	RO 		Line Status Register 
		MSR 	0x18 	8 	RO 		Modem Status Register 
		DIV1 	0x1c 	8 	R/W 	16 bit Baud Rate divider – least significant byte 
		DIV2 	0x20 	8 	R/W 	16 bit Baud Rate divider – most significant byte
	*/
	`define DR 				5'h0
	`define IER				5'h1
	`define IIR				5'h2
	`define FCR				5'h2
	`define LCR_ADDR		5'h3
	`define MCR				5'h4
	`define LSR				5'h5
	`define MSR				5'h6
	`define DIV1			5'h7
	`define DIV2			5'h8
	`define TXFTLR			5'h9		//TX FIFO Threshold Level Register
	`define UART_CTRL_ADDR	5'hA		//UART Control Register
	
	//states for APB FSM
	localparam	IDLE 	= 	2'b00;
	localparam	SETUP	=	2'b01;
	localparam	ENABLE	=	2'b10;
	
	//APB internal signals or registers
	wire wr_enb;
	wire rd_enb;
	
	//interrupt signals
	reg tx_int;					//TX FIFO becomes empty interrupt
	wire rx_int;					//RX FIFO has received data Interrupt
	wire ls_int;					//Line error occurs interrupt 
	//reg last_tx_fifo_empty;		//Store previous cycle value
	reg tx_threshold_last;
	
	//RX FIFO Interrupt threshold
	wire rx_fifo_interrupt_threshold;
	
	//TX FIFO Interrupt threshold
	wire tx_fifo_interrupt_threshold;
	
	//baud generator internal signals
	reg [15:0]baud_cnt;
	
	//RX timeout counter signals
	reg [5:0] rx_timeout_cnt;
	reg rx_timeout_int;
	
	//Read enable pulse for RX FIFO signals
	reg [7:0] rx_data_reg;
	
	//UART Registers
	reg [3:0]	IER;	//[7:4] Reserved, will always read back as ‘0’
	reg [3:0]	IIR;	//Bits [7:4] are unused and are always read back as 0xC
	reg [7:0]	FCR;
	reg [4:0]	MCR;	//[7:5] Reserved
	reg [7:0]	MSR;
	reg [7:0]	LSR;
	reg	[15:0]	DIVISOR;
	
	//Transmit FIFO Threshold Level Register
	reg [4:0]	TXFTLR;
	
	//UART Control Register
	reg [1:0] 	UART_CTRL;
	//logic for APB States 
	reg [1:0] 	STATE, next_state;
	
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				STATE <= IDLE;
			else
				STATE <= next_state;
		end
       
	//logic for APB States 
	always@(*)
		begin
			case(STATE)
				IDLE  : begin
							if(PSEL && !PENABLE)
								next_state = SETUP;
							else
								next_state = IDLE;
						end

				SETUP : begin
							if(PSEL && PENABLE)
								next_state = ENABLE;
							else if(PSEL && !PENABLE)
								next_state = SETUP;
							else
								next_state = IDLE;
						end

				ENABLE: begin
							if(PSEL)
								next_state = SETUP;
							else 
								next_state = IDLE;
							end

				default: next_state = IDLE;
			endcase
		end

	//Logic to up date the PREADY 
	assign PREADY = (STATE==ENABLE)?1'b1:1'b0;

	//Logic to generate the Write Enable and Read Enable
	assign wr_enb = PWRITE && (STATE == ENABLE);
	assign rd_enb = !PWRITE && (STATE == ENABLE);
	
	//Write Logic for registers
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				begin
					IER	<=	0;
					FCR	<=	0;
					LCR	<=	3;
					MCR	<=	0;
					DIVISOR	<=	0;
					TXFTLR	<=	1;		//Default Threshold
				end
			else if(wr_enb)
				begin
					case(PADDR)
						`IER:				IER				<=	PWDATA[3:0];
						`FCR:				FCR				<=	PWDATA[7:0];
						`LCR_ADDR:			LCR				<=	PWDATA[7:0];
						`MCR:				MCR				<=	PWDATA[4:0];
						`DIV1:				DIVISOR[7:0]	<=	PWDATA[7:0];
						`DIV2:				DIVISOR[15:8]	<= 	PWDATA[7:0];
						`TXFTLR:			TXFTLR			<=	((PWDATA[4:0] > 5'd15) ? 5'd15 : PWDATA[4:0]);
						`UART_CTRL_ADDR:	UART_CTRL		<=	PWDATA[1:0];
						default: ;	//ignore invalid writes
					endcase
				end
		end
		
	//Write enable pulse for TX FIFO
	//Control signal
	always@(*)
		begin
			tx_fifo_we	=	1'b0;
			if(wr_enb && (PADDR	==	`DR) && !tx_fifo_full)
				tx_fifo_we	=	1'b1;
		end
		
	//Read logic
	always@(*)
		begin
			PRDATA	=	32'h0;
			PSLVERR	=	1'b0;
			if(rd_enb)
				begin
					case(PADDR)
						`DR:			PRDATA	=	{24'h0, rx_data_reg};
						`IER:			PRDATA	=	{28'h0, IER};
						`IIR:			PRDATA	=	{24'h0, 4'hc, IIR};
						`LCR_ADDR:		PRDATA	=	{24'h0, LCR};
						`MCR:			PRDATA	=	{27'h0, MCR};
						`LSR:			PRDATA	=	{24'h0, LSR};
						`MSR:			PRDATA	=	{24'h0, MSR};
						`DIV1:			PRDATA	=	{24'h0, DIVISOR[7:0]};
						`DIV2:			PRDATA	=	{24'h0, DIVISOR[15:8]};
						`TXFTLR:		PRDATA = {27'h0, TXFTLR};
						default:	begin
										PRDATA	=	32'h0;
										PSLVERR	=	(STATE == ENABLE);
									end
					endcase
				end
		end
	
	//loopback logic
	assign loopback	=	MCR[4];		//Loopback mode: ‘0’ – Normal mode, ‘1’ – Loopback mode enabled
	
	//TX/RX Enable
	assign tx_enable = UART_CTRL[0];
	assign rx_enable = UART_CTRL[1];
	
	//LSR: Line status register
	always@(*)
		begin
			LSR[0]	= 	!rx_fifo_empty;
			LSR[1] 	= 	rx_overrun;
			LSR[2] 	=	parity_error;
			LSR[3]	=	framing_error;
			LSR[4]	=	break_error;
			LSR[5]	=	tx_fifo_empty;
			LSR[6]	=	!tx_busy;		//transmitter is empty bcoz it is not transmitting anything so 'busy' signal is LOW
			LSR[7] 	=	1'b0;
		end
	
	//Read enable pulse for RX FIFO
	//Control signal
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				begin
					rx_data_reg <= 8'h0;
					rx_fifo_re <= 1'b0;
				end
			else 
				begin
					rx_fifo_re <= 1'b0;
					if(rd_enb && (PADDR == `DR) && !rx_fifo_empty)
					begin
						rx_data_reg <= rx_data_out;
						rx_fifo_re <= 1'b1;
					end
				end
		end
	
	//Modem Status Register
	always@(*)
		begin
			MSR = 8'h00;
		end	
	
	//Interrupt Line or IRQ generation
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				irq	<=	1'b0;
			else if(rd_enb && (PADDR == `IIR))
				irq	<=	1'b0;
			else
				begin
					irq	<=	(IER[0] & rx_int) |
							(IER[1] & tx_int) |
							(IER[2] & ls_int);
				end
		end
	
	//Interrupt Identification register
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				IIR	<=	4'h1;
			else
				begin
					if(ls_int && (IER[2]))
						IIR	<=	4'h6;
					else if(rx_fifo_interrupt_threshold && (IER[0]))
						IIR	<=	4'h4;
					else if(rx_timeout_int && (IER[0]))
						IIR	<=	4'hc;
					else if(tx_int && (IER[1]))
						IIR	<=	4'h2;
					else
						IIR	<=	4'h1;
				end
		end
	
	//Baud Rate Generator logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				begin
					baud_cnt <=	0;
					baud_o	<=	0;
				end
			//protect against illegaal divisor values
			else if(DIVISOR != 0 && DIVISOR < 16'd2)
				begin
					baud_cnt <= 0;
					baud_o <= 0;
				end
			//divisor reached
			else if(baud_cnt == (DIVISOR - 1))
				begin
					baud_cnt <= 0;
					baud_o <= 1;
				end
			else
				begin
					baud_cnt <= baud_cnt + 1;
					baud_o <= 0;
				end
		end
		
	//RX Timeout logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				begin
					rx_timeout_cnt	<=	0;
					rx_timeout_int	<=	0;
				end
			//new byte arrived: reset timeout timer
			else if(push_rx_fifo)
				begin
					rx_timeout_cnt	<= 	0;
					rx_timeout_int	<=	0;
				end
			//increment timeout counter when data exists in RX FIFO
			else if(!rx_fifo_empty && baud_o)
				begin
					if(rx_timeout_cnt >= 6'd40)
						begin
							rx_timeout_int	<= 1'b1;
						end
					else
						begin
							rx_timeout_cnt	<= rx_timeout_cnt	+	1'b1;
						end
				end
			//FIFO empty: no timeout condition	
			else if(rx_fifo_empty)
				begin
					rx_timeout_cnt	<=	0;
					rx_timeout_int	<=	0;
				end
		end
	
	//FIFO Reset logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				begin
					clear_tx_fifo	<= 	0;
					clear_rx_fifo	<=	0;
				end
			else if(wr_enb	&& (PADDR == `FCR))
				begin
					clear_rx_fifo	<=	PWDATA[1];
					clear_tx_fifo	<=	PWDATA[2];
				end
			else
				begin
					clear_tx_fifo	<=	0;
					clear_rx_fifo	<=	0;
				end
		end
			
	
	//Interrupts
	//TX Interrupt
	assign tx_fifo_interrupt_threshold	=	(tx_fifo_count	<=	TXFTLR)	&& (tx_fifo_count	!=	0);
	
	/*Following approach is also correct and is commonly used in uart 16550:
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				begin
					tx_int	<=	1'b0;
					last_tx_fifo_empty	<=	1'b1;	
				end
			else
				begin
					last_tx_fifo_empty	<=	tx_fifo_empty;
					if(rd_enb && (PADDR == `IIR) && (IIR == 4'h2))		//PRDATA[3:0] == 4'h2: The transmit FIFO and the transmit shift register is empty
						tx_int	<=	1'b0;
					else
						tx_int	<=	(tx_fifo_empty & ~last_tx_fifo_empty) | tx_int;
						// 	tx_fifo_empty & ~last_tx_fifo_empty: Interrupt should trigger when TX FIFO becomes empty, not when it stays empty.
						//	| tx_int: This creates a latched interrupt.
						//	Meaning: event occurs → tx_int = 1
						//	and it stays 1 until cleared.
						//	Without this:interrupt pulse might disappear
				end
		end*/
				
	//RX Interrupt
	assign rx_int = rx_fifo_interrupt_threshold	| rx_timeout_int;
		
	//Line Status Interrupt
	assign ls_int = parity_error | framing_error | rx_overrun | break_error;
	
	//TX FIFO Interrupt generation logic
	always@(posedge PCLK or negedge PRESETn)
		begin
			if(!PRESETn)
				begin
					tx_int	<=	1'b0;
					tx_threshold_last	<=	1'b0;
				end
			else 
				begin
					tx_threshold_last	<=	tx_fifo_interrupt_threshold;
					//CPU clears interrupt by reading IIR
					if(rd_enb && (PADDR == `IIR) && (IIR == 4'h2))
						tx_int 	<= 	1'b0;
					//generate Interrupt when FIFO below Threshold
					else if(tx_fifo_interrupt_threshold & ~tx_threshold_last)
						tx_int	<=	1'b1;
				end
		end
	
	//RX FIFO interrupt threshold logic
	always@(*)
		begin
			case(FCR[7:6])
				2'b00: rx_fifo_interrupt_threshold = (rx_fifo_count >= 1);
				2'b01: rx_fifo_interrupt_threshold = (rx_fifo_count >= 4);
				2'b10: rx_fifo_interrupt_threshold = (rx_fifo_count >= 8);
				2'b11: rx_fifo_interrupt_threshold = (rx_fifo_count >= 14);
				default: rx_fifo_interrupt_threshold = 0;
			endcase
		end
endmodule
