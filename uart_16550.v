module uart_16550(PCLK, PRESETn, PADDR, PWDATA, PRDATA, PWRITE, PENABLE, PSEL, PREADY,
				  PSLVERR, IRQ, TXD, RXD, baud_o);

	//Port Declarations
	//APB signals
	input PCLK;
	input PRESETn;
	input [31:0] PADDR;
	input [31:0] PWDATA;
	input PWRITE;
	input PENABLE;
	input PSEL;
	output [31:0] PRDATA;
	output PREADY;
	output PSLVERR;
	
	//UART specific signals
	output TXD;
	input RXD;
	output baud_o;
	output IRQ;
	
	//Internal signals
	//Transmitter related
	wire tx_fifo_we;
	wire tx_enable;
	wire [4:0] tx_fifo_count;
	wire tx_fifo_empty;
	wire tx_fifo_full;
	wire tx_busy;
	
	//Receiver related
	wire [7:0] rx_data_out;
	wire rx_idle;
	wire rx_overrun;
	wire parity_error;
	wire framing_error;
	wire break_error;
	wire time_out;
	wire [4:0] rx_fifo_count;
	wire rx_fifo_empty;
	wire rx_fifo_full;
	wire push_rx_fifo;
	wire rx_enable;
	wire rx_fifo_re;
	wire loopback;
	
	wire [7:0] LCR;
	wire RXD_in, TXD_out;
	wire clear_tx_fifo;
	wire clear_rx_fifo;
	
	//Instantiate modules
	//uart_register_file
	uart_register_file control(
									.PCLK(PCLK), 
									.PRESETn(PRESETn),
									.PSEL(PSEL),
									.PWRITE(PWRITE), 
									.PENABLE(PENABLE), 
									.PWDATA(PWDATA), 
									.PADDR(PADDR[6:2]),
									.PRDATA(PRDATA), 
									.PREADY(PREADY), 
									.PSLVERR(PSLVERR), 
									.tx_fifo_count(tx_fifo_count), 
									.tx_fifo_empty(tx_fifo_empty),
									.tx_fifo_full(tx_fifo_full), 
									.tx_busy(tx_busy), 
									.tx_fifo_we(tx_fifo_we), 
									.tx_enable(tx_enable),
									.rx_data_out(rx_data_out), 
									.rx_idle(rx_idle), 
									.rx_overrun(rx_overrun), 
									.parity_error(parity_error),
									.framing_error(framing_error), 
									.break_error(break_error), 
									.time_out(time_out), 
									.rx_fifo_count(rx_fifo_count),
									.rx_fifo_empty(rx_fifo_empty), 
									.rx_fifo_full(rx_fifo_full), 
									.push_rx_fifo(push_rx_fifo),
									.rx_enable(rx_enable), 
									.rx_fifo_re(rx_fifo_re), 
									.irq(IRQ), 
									.loopback(loopback), 
									.baud_o(baud_o), 
									.clear_tx_fifo(clear_tx_fifo),
									.clear_rx_fifo(clear_rx_fifo), 
									.LCR(LCR)
									);
								
	//uart_transmitter
	uart_transmitter tx_channel(
									.PCLK(PCLK),
									.PRESETn(PRESETn),
									.PWDATA(PWDATA[7:0]), 
									.tx_fifo_push(tx_fifo_we), 
									.enable(tx_enable), 
									.LCR(LCR), 
									.clear_fifo(clear_tx_fifo), 
									.tx_fifo_count(tx_fifo_count), 
									.busy(tx_busy), 
									.tx_fifo_empty(tx_fifo_empty), 
									.tx_fifo_full(tx_fifo_full), 
									.TXD(TXD_out)
									);
	
	//uart_receiver
	uart_receiver rx_channel(	
									.PCLK(PCLK), 
									.PRESETn(PRESETn), 
									.RXD(RXD_in), 
									.pop_rx_fifo(rx_fifo_re), 
									.enable(rx_enable), 
									.LCR(LCR), 
									.clear_fifo(clear_rx_fifo), 
									.rx_idle(rx_idle), 
									.rx_fifo_out(rx_data_out), 
									.rx_fifo_count(rx_fifo_count), 
									.push_rx_fifo(push_rx_fifo), 
									.rx_fifo_empty(rx_fifo_empty),
									.rx_fifo_full(rx_fifo_full), 
									.rx_overrun(rx_overrun), 
									.parity_error(parity_error), 
									.framing_error(framing_error), 
									.break_error(break_error), 
									.time_out(time_out)
									);
	
	//handle loopback
	assign RXD_in = loopback ? TXD_out : RXD;
	assign TXD	  = loopback ? 1'b1    : TXD_out;

endmodule
