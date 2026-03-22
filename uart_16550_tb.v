module uart_16550_tb();
	
	//signals declaration for UART1
	//APB signals
	reg PCLK;
	reg PRESETn;
	reg [31:0] PADDR;
	reg [31:0] PWDATA;
	reg PWRITE;
	reg PENABLE;
	reg PSEL;
	wire [31:0] PRDATA;
	wire PREADY;
	wire PSLVERR;
	
	//UART specific signals
	wire TXD;
	wire RXD;
	wire baud_o;
	wire IRQ;
	
	//signals declaration for UART2
	//APB signals
	reg PCLK1;
	reg PRESETn1;
	reg [31:0] PADDR1;
	reg [31:0] PWDATA1;
	reg PWRITE1;
	reg PENABLE1;
	reg PSEL1;
	wire [31:0] PRDATA1;
	wire PREADY1;
	wire PSLVERR1;
	
	//UART specific signals
	wire TXD1;
	wire RXD1;
	wire baud_o1;
	wire IRQ1;
	
	//Buad related signals
	parameter UART1_CLK = 50_000_000;
	parameter UART2_CLK = 100_000_000;
	parameter BAUD_RATE = 115200;			//9600,115200
	
	integer uart1_divisor = UART1_CLK / (16 * BAUD_RATE);
	integer uart2_divisor = UART2_CLK / (16 * BAUD_RATE);
	
	//Bit time signals
	time uart1_bit_time = 1000_000_000 / BAUD_RATE;		//calculation is in terms of nanoseconds
	time uart2_bit_time = 1000_000_000 / BAUD_RATE;		//calculation is in terms of nanoseconds
	
	//Instantiate DUT1
	uart_16550 DUT1(
						.PCLK(PCLK),
						.PRESETn(PRESETn),
						.PADDR(PADDR),
						.PWDATA(PWDATA),
						.PWRITE(PWRITE),
						.PENABLE(PENABLE),
						.PSEL(PSEL),
						.PRDATA(PRDATA),
						.PREADY(PREADY),
						.PSLVERR(PSLVERR),
						.TXD(TXD),
						.RXD(RXD),
						.baud_o(baud_o),
						.IRQ(IRQ)
						);
	
	//Instantiate DUT2
	uart_16550 DUT2(
						.PCLK(PCLK1),
						.PRESETn(PRESETn1),
						.PADDR(PADDR1),
						.PWDATA(PWDATA1),
						.PWRITE(PWRITE1),
						.PENABLE(PENABLE1),
						.PSEL(PSEL1),
						.PRDATA(PRDATA1),
						.PREADY1(PREADY1),
						.PSLVERR(PSLVERR1),
						.TXD(TXD1),
						.RXD(RXD1),
						.baud_o(baud_o1),
						.IRQ(IRQ1)
						);
	
	//UART Cross connection
	assign RXD = TXD1;
	assign RXD1 = TXD;
	
	//Clock Generation					
	initial
		begin
			PCLK = 1'b0;
			PCLK1 = 1'b0;
		end
		
	always #10 PCLK = ~PCLK;		//50MHz
	always #5 PCLK1 = ~PCLK1;		//100MHz		
	
	//task reset
	task reset;
		begin
			//assert active low reset
			PRESETn = 1'b0;
			PRESETn1 = 1'b0;
			//hold reset for both clocks
			fork
				repeat(20) @(posedge PCLK);
				repeat(20) @(posedge PCLK1);
			join
			//avoid edge race
			#1;
			//deassert reset
			PRESETn = 1'b1;
			PRESETn1 = 1'b1;
			//stabilization time
			fork
				repeat(10) @(posedge PCLK);
				repeat(10) @(posedge PCLK1);
			join
		end
	endtask
	
	//APB Transaction Driver
	//1. UART1
	//APB Write task
	task apb_write;
		input [4:0] addr;
		input [31:0] data;
		
		begin	
			//Setup Phase
			@(posedge PCLK);
			PADDR = addr;
			PWDATA = data;
			PWRITE = 1'b1;
			PSEL = 1'b1;
			PENABLE = 1'b0;
			
			//Access Phase
			@(posedge PCLK);
			PENABLE = 1'b1;
			
			//wait for ready
			wait(PREADY == 1'b1)
			
			//complete transfer
			@(posedge PCLK)
			PSEL = 1'b0;
			PENABLE = 1'b0;
			PWRITE = 1'b0;
		end
	endtask
	
	//APB Read task
	task apb_read;
		input [4:0] addr;
		output [31:0] data;
		
		begin	
			//Setup Phase
			@(posedge PCLK);
			PADDR = addr;
			PWRITE = 1'b0;
			PSEL = 1'b1;
			PENABLE = 1'b0;
			
			//Access Phase
			@(posedge PCLK);
			PENABLE = 1'b1;
			
			//wait for ready
			wait(PREADY == 1'b1)
			
			data = PRDATA;
			
			//complete transfer
			@(posedge PCLK)
			PSEL = 1'b0;
			PENABLE = 1'b0;
		end
	endtask
	
	//2. UART2
	//APB Write task
	task apb_write1;
		input [4:0] addr;
		input [31:0] data;
		
		begin	
			//Setup Phase
			@(posedge PCLK1);
			PADDR1 = addr;
			PWDATA1 = data;
			PWRITE1 = 1'b1;
			PSEL1 = 1'b1;
			PENABLE1 = 1'b0;
			
			//Access Phase
			@(posedge PCLK1);
			PENABLE1 = 1'b1;
			
			//wait for ready
			wait(PREADY1 == 1'b1)
			
			//complete transfer
			@(posedge PCLK1)
			PSEL1 = 1'b0;
			PENABLE1 = 1'b0;
			PWRITE1 = 1'b0;
		end
	endtask
	
	//APB Read task
	task apb_read1;
		input [4:0] addr;
		output [31:0] data;
		
		begin	
			//Setup Phase
			@(posedge PCLK1);
			PADDR1 = addr;
			PWRITE1 = 1'b0;
			PSEL1 = 1'b1;
			PENABLE1 = 1'b0;
			
			//Access Phase
			@(posedge PCLK1);
			PENABLE1 = 1'b1;
			
			//wait for ready
			wait(PREADY1 == 1'b1)
			
			data = PRDATA1;
			
			//complete transfer
			@(posedge PCLK1)
			PSEL1 = 1'b0;
			PENABLE1 = 1'b0;
		end
	endtask
	
	//UART Configuration task
	//1. UART1
	task uart_configure1;	
		begin
			//enable TX and RXD
			apb_write(`UART_CTRL_ADDR, 32'h3);
			//configure line control (8N1)
			apb_write(`LCR_ADDR, 32'h03);
			//set baud divisor
			apb_write(`DIV1, uart1_divisor[7:0]);
			apb_write(`DIV2, uart1_divisor[15:8]);
			//clear fifo
			apb_write(`FCR, 32'h06);
		end 
	endtask: uart_configure1
	
	//2. UART2
	task uart_configure2;
		begin
			//enable TX and RXD
			apb_write1(`UART_CTRL_ADDR, 32'h3);
			//configure line control (8N1)
			apb_write1(`LCR_ADDR, 32'h03);
			//set baud divisor
			apb_write1(`DIV1, uart2_divisor[7:0]);
			apb_write1(`DIV2, uart2_divisor[15:8]);
			//clear fifo
			apb_write1(`FCR, 32'h06);
		end 
	endtask: uart_configure2
	
	//Data Transmit task
	//1. UART1
	task uart1_send_byte;
		input [7:0] data;		//the byte we want UART1 to Transmit
		reg [31:0] lsr;			//temporary variable to store the line status register value
		integer timeout;
		begin
			timeout = 0;
			//wait until TX fifo is not full
			while(timeout < 100)
					begin
						apb_read(`LSR, lsr);
						if(lsr[5])				//TX fifo empty 
							break;
						
						timeout = timeout + 1;
						
						@(posedge PCLK);		//without this the loop will execute at 0s simulation time
					end
			//Timeout protection
			if(timeout == 100)
				begin
					$display("[%0t] ERROR: UART1 TX FIFO not ready", $time);
					$finish;
				end
			//write data to data register DR
			apb_write(`DR, {24'd0, data});
			
			$display("[%0t] UART1 TX: %h", $time, data);
		end
	endtask: uart1_send_byte
	
	//2. UART2
	task uart2_send_byte;
		input [7:0] data;		//the byte we want UART1 to Transmit
		reg [31:0] lsr;			//temporary variable to store the line status register value
		integer timeout;
		begin
			timeout = 0;
			//wait until TX fifo is not full
			while(timeout < 100)
					begin
						apb_read1(`LSR, lsr);
						if(lsr[5])				//TX fifo empty 
							break;
						
						timeout = timeout + 1;
						
						@(posedge PCLK1);		//without this the loop will execute at 0s simulation time
					end
			//Timeout protection
			if(timeout == 100)
				begin
					$display("[%0t] ERROR: UART2 TX FIFO not ready", $time);
					$finish;
				end
			//write data to data register DR
			apb_write1(`DR, {24'd0, data});
			
			$display("[%0t] UART2 TX: %h", $time, data);
		end
	endtask: uart2_send_byte
	
	//Data receive task
	//1. UART1
	task uart1_receive_byte;
		output [7:0] data;
		reg [31:0] lsr;
		reg [31:0] dr;
		integer timeout;
		
		begin
			timeout = 0;
			//wait until RX data available
			while(timeout < 100)
				begin
					apb_read(`LSR, lsr);
					if(lsr[0])				//RX data ready
						break;
					
					timeout = timeout + 1;
					
					@(posedge PCLK);
				end
			//Timeout protection
			if(timeout == 100)
				begin
					$display("[%0t] ERROR: UART1 RX FIFO not ready", $time);
					$finish;
				end
			//Read received data
			apb_read(`DR, dr);
			
			data = dr[7:0];
			
			$display("[%0t] UART1 RX: %h", $time, data);
		end
	endtask: uart1_receive_byte
	
	//2. UART2
	task uart2_receive_byte;
		output [7:0] data;
		reg [31:0] lsr;
		reg [31:0] dr;
		integer timeout;
		
		begin
			timeout = 0;
			//wait until RX data available
			while(timeout < 100)
				begin
					apb_read1(`LSR, lsr);
					if(lsr[0])				//RX data ready
						break;
					
					timeout = timeout + 1;
					
					@(posedge PCLK1);
				end
			//Timeout protection
			if(timeout == 100)
				begin
					$display("[%0t] ERROR: UART2 RX FIFO not ready", $time);
					$finish;
				end
			//Read received data
			apb_read1(`DR, dr);
			
			data = dr[7:0];
			
			$display("[%0t] UART2 RX: %h", $time, data);
		end
	endtask: uart2_receive_byte
	
	//Data comparison task
	//1. UART1 to UART2
	task uart1_to_uart2_check;
		input [7:0] tx_data;
		reg [7:0] rx_data;
		
		begin
			uart2_receive_byte(rx_data);
			if(rx_data == tx_data)
				$display("[%0t] PASS: UART1 to UART2 TX = %h, Rx = %h", $time, tx_data, rx_data);
			else
				begin
					$display("[%0t] FAIL: UART1 to UART2 TX = %h, Rx = %h", $time, tx_data, rx_data);
					$finish;
				end
		end
	endtask: uart1_to_uart2_check
	
	//2. UART2 to UART1
	task uart2_to_uart1_check;
		input [7:0] tx_data;
		reg [7:0] rx_data;
		
		begin
			uart1_receive_byte(rx_data);
			if(rx_data == tx_data)
				$display("[%0t] PASS: UART2 to UART1 TX = %h, Rx = %h", $time, tx_data, rx_data);
			else
				begin
					$display("[%0t] FAIL: UART2 to UART1 TX = %h, Rx = %h", $time, tx_data, rx_data);
					$finish;
				end
		end
	endtask: uart2_to_uart1_check
	
	//Multi-byte transmission task
	//1. UART1
	task uart1_send_packet;
		input integer length;
		input [7:0] data_array[0:255];
		integer i;
		
		begin
			for(i = 0; i < length; i = i+ 1)
				begin
					uart1_send_byte(data_array[i]);
				end
		end
	endtask: uart1_send_packet
	
	//2. UART2
	task uart2_send_packet;
		input integer length;
		input [7:0] data_array[0:255];
		integer i;
		
		begin
			for(i = 0; i < length; i = i+ 1)
				begin
					uart2_send_byte(data_array[i]);
				end
		end
	endtask: uart2_send_packet
	
	//Packet data check
	//1. UART1
	task uart1_to_uart2_packet_check;
		input integer length;
		input [7:0] data_array[0:255];
		integer i;
		reg [7:0] rx_data;
		
			begin
				for(i = 0; i < length; i = i + 1)
					begin
						uart2_receive_byte(rx_data);
						if(rx_data == data_array[i])
							$display("Pass byte %0d: %0h", i, rx_data);
						else
							begin
								$display("Fail byte %0d: expected = %0h, received = %0h", i, data_array[i], rx_data);
								$finish;
							end
					end
			end
	endtask: uart1_to_uart2_packet_check
	
	//2. UART2
	task uart2_to_uart1_packet_check;
		input integer length;
		input [7:0] data_array[];
		integer i;
		reg [7:0] rx_data;
		
			begin
				for(i = 0; i < length; i = i + 1)
					begin
						uart1_receive_byte(rx_data);
						if(rx_data == data_array[i])
							$display("Pass byte %0d: %0h", i, rx_data);
						else
							begin
								$display("Fail byte %0d: expected = %0h, received = %0h", i, data_array[i], rx_data);
								$finish;
							end
					end
			end
	endtask: uart2_to_uart1_packet_check
	
	//Serial monitor to verify serial protocol check
	//1. UART1
	task uart1_serial_monitor;
		reg [7:0] data;
		integer i;
		
		begin
			forever 
				begin
					@(negedge TXD);		//detect start Bit
					
					#(uart1_bit_time/2);
					
					for(i = 0; i < 8; i = i + 1)
						begin
							#(uart1_bit_time);
							data[i] = TXD;
						end
					
					#(uart1_bit_time);		//stop Bit
					if(TXD !== 1'b1)
						$display("[%0t] UART1 Framing Error: Stop bit incorrect", $time);
						
					$display("[%0t] UART1 Serial Byte = %h", $time, data);
				end
		end
	endtask: uart1_serial_monitor
	
	//2. UART2
	task uart2_serial_monitor;
		reg [7:0] data;
		integer i;
		
		begin
			forever 
				begin
					@(negedge TXD1);		//detect start Bit
					
					#(uart2_bit_time/2);
					
					for(i = 0; i < 8; i = i + 1)
						begin
							#(uart2_bit_time);
							data[i] = TXD1;
						end
					
					#(uart2_bit_time);		//stop Bit
					if(TXD1 !== 1'b1)
						$display("[%0t] UART2 Framing Error: Stop bit incorrect", $time);
						
					$display("[%0t] UART2 Serial Byte = %h", $time, data);
				end
		end
	endtask: uart2_serial_monitor
	
	//Inter-Byte Delay task
	task uart_idle_delay;
		input integer cycles;
		integer i;

		begin
			for(i = 0; i < cycles; i = i + 1)
				@(posedge PCLK);
		end
	endtask: uart_idle_delay

	//Waveform Dump
	initial
		begin
			$dumpfile("uart_16550_tb.vcd");
			$dumpvars(0. uart_16550_tb);
		end
	
	//Main Test Sequence
	initial
		begin
			reg [7:0] packet1[0:255];
			reg [7:0] packet2[0:255];
			integer i;
			integer length;
			
			//Initialize APB signals
			//1. UART1
			PADDR 	= 	0;
			PWDATA 	= 	0;
			PWRITE 	= 	0;
			PENABLE = 	0;
			PSEL 	= 	0;
			//2. UART2
			PADDR1		=	0;
			PWDATA1		=	0;
			PWRITE1		=	0;
			PENABLE1	=	0;
			PSEL1		=	0;
			
			//Reset DUTs
			$display("[%0t] Applying Reset...", $time);
			reset();
			
			//Configure UARTs
			$display("[%0t] Configuring UARTs..." $time);
			uart_configure1();
			uart_configure2();
			
			//Start Serial Monitors
			fork
				uart1_serial_monitor();
				uart2_serial_monitor();
			join_none
			
			//Test1: Single byte UART1 to UART2
			$display("TEST1: UART1 to UART2 Single Byte...");
			uart1_send_byte(8'hA5);
			uart1_to_uart2_check(8'hA5);
			
			//Test2: Single byte UART2 to UART1
			$display("TEST2: UART2 to UART1 Single Byte...")
			uart2_send_byte(8'h3C);
			uart2_to_uart1_check(8'h3C);
			
			//Test3: Random Single byte transfers
			$display("TEST3: Random Byte Transfers...");
			for(i = 0; i < 20; i = i + 1)
				begin
					reg [7:0] data;
					data = $random;
					uart1_send_byte(data);
					uart1_to_uart2_check(data);
					uart_idle_delay(10);
				end
				
			//Test4: Packet transfer UART1 to UART2
			$display("TEST4: Packet Transfer UART1 to UART2...");
			length = 16;
			for(i = 0; i < length; i = i + 1)
				begin
					packet1[i] = $random;
				end
			
			uart1_send_packet(length, packet1);
			uart1_to_uart2_packet_check(length, packet1);
			
			//Test5: Packet transfer UART2 to UART1
			$display("TEST5: Packet Transfer UART2 to UART1...")
			length = 16;
			for((i = 0; i < length; i = i + 1)
				begin
					packet2[i] = $random;
				end
			
			uart2_send_packet(length, packet2);
			uart2_to_uart1_packet_check(length, packet2);
			
			//Test6: Stress/Multiple Byte Transfers task
			$display("TEST6: Stress Test...");
			for(i = 0; i < 2000; i = i + 1)
				begin
					reg [7:0] data;
					data = $random;
					uart1_send_byte(data);
					uart1_to_uart2_check(data);
				end
					
			//Test PASS
			$display("=============================================");
			$display("All Tests are Passed...");
			$display("=============================================");
			
			#2000;
			$finish;
		end
		
endmodule
		
					
