module tb_phy_tx_top;
	parameter int WIDTH=8;
	parameter int FIFO_DEPTH=16;
	parameter int CLK_HZ = 480_000_000;
    parameter int MAX_PKT_SYMBOLS   = 12288;
    parameter int BAD_LIMIT         = 8;
    parameter int HS_SYNC_MIN_ALT   = 11;    
    parameter int HS_SYNC_MAX_ALT   = 31;    
    parameter int FSLS_SYNC_MIN_ALT = 7;    
    parameter int FSLS_SYNC_MAX_ALT = 15;    
    parameter int SYNC_ERR_MIN      = 5;
    parameter int EOP_SE0_MIN       = 1;     
    parameter int EOP_SE0_MAX       = 3;
    parameter int HS_HOLDOFF_MAX    = 16384; 
    parameter int RESET_SE0_NS      = 2500;  
    parameter bit ALIGN_IN_RXERROR  = 1'b0;
	
	logic             clk;
    logic             rst_n;
    speed_t           usb_speed;     
    logic             sof_packet;     
    logic [WIDTH-1:0] sie_data;
    logic             sie_valid;
    logic             sie_sop;
    logic             sie_eop;
    logic             sie_ready;
    logic             dp;
    logic             dm;
	logic 			 tx_valid;
    logic             sample_valid;
    logic [WIDTH-1:0] DataOut;
    logic             RxValid;
    logic             RxActive;
    logic             RxError;
    logic [1:0]       LineState;
    logic             rx_sop;
    logic             rx_eop;
    logic             rx_stuff_err;
    logic             rx_align_err;
    logic             rx_line_err;
    logic             rx_babble_err;
    logic             rx_sync_err;
    logic             rx_bus_reset; 
   	logic 			 analog_d_plus;
	logic 			 analog_d_minus;
	logic 			 analog_enable;
	logic 			 analog_serial;
	phy_top #(
			  .WIDTH    		 (WIDTH)  ,
    		  .FIFO_DEPTH 		 (FIFO_DEPTH),
    		  .CLK_HZ          	 (CLK_HZ) ,
    		  .MAX_PKT_SYMBOLS 	 (MAX_PKT_SYMBOLS),
    		  .BAD_LIMIT         (BAD_LIMIT),
    		  .HS_SYNC_MIN_ALT   (HS_SYNC_MIN_ALT),    
    		  .HS_SYNC_MAX_ALT   (HS_SYNC_MAX_ALT),    
    		  .FSLS_SYNC_MIN_ALT (FSLS_SYNC_MIN_ALT),     
    		  .FSLS_SYNC_MAX_ALT (FSLS_SYNC_MAX_ALT),    
    		  .SYNC_ERR_MIN      (SYNC_ERR_MIN),
    		  .EOP_SE0_MIN       (EOP_SE0_MIN),     
    		  .EOP_SE0_MAX       (EOP_SE0_MAX),
    		  .HS_HOLDOFF_MAX    (HS_HOLDOFF_MAX), 
    		  .RESET_SE0_NS      (RESET_SE0_NS),  
    		  .ALIGN_IN_RXERROR  (ALIGN_IN_RXERROR)

	) dut_phy_top(
				 .clk(clk),
    			 .rst_n(rst_n),
    			 .usb_speed(usb_speed),      
    			 .sof_packet(sof_packet),     
    			 .sie_data(sie_data),
    			 .sie_valid(sie_valid),
    			 .sie_sop(sie_sop),
    			 .sie_eop(sie_eop),
    			 .sie_ready(sie_ready),
    			 .dp(dp),
    			 .dm(dm),
				 .tx_valid(tx_valid),
    			 .DataOut(DataOut),
    			 .RxValid(RxValid),
    			 .RxActive(RxActive),
    			 .RxError(RxError),
    			 .LineState(LineState),
    			 .rx_sop(rx_sop),
    			 .rx_eop(rx_eop),
				 .analog_enable(analog_enable),
				 .analog_serial(analog_serial),
				 .analog_d_plus(analog_d_plus),
				 .analog_d_minus(analog_d_minus),
    			 .rx_stuff_err(rx_stuff_err),
    			 .rx_align_err(rx_align_err),
    			 .rx_line_err(rx_line_err),
    			 .rx_babble_err(rx_babble_err),
    			 .rx_sync_err(rx_sync_err),
    			 .rx_bus_reset(rx_bus_reset)    
);
	initial begin
		clk=0;
		forever #1.041667 clk=~clk;
	end
	task automatic write(input int num_bytes);
		logic [7:0] data;
		sie_valid=1'b0;
		sie_data = 'b0;
		sie_sop=1'b0;
		sie_eop = 1'b0;
		for(int i=0;i<num_bytes;i++)begin
			data = $urandom(i);
			@(negedge clk);
			sie_valid = 1'b1;
			sie_data = data;
			sie_sop =(i==0);
			sie_eop =(i==(num_bytes-1));
			//hold data until FIFO accepts it
			do begin
				@(posedge clk);
			end while(!sie_ready);
		end	
		@(negedge clk);
		sie_valid=1'b0;
		sie_data = 'b0;
		sie_sop = 1'b0;
		sie_eop = 1'b0;
	endtask
	initial begin
		rst_n=1'b0;
		sie_data='b0;
		sie_valid=1'b0;
		usb_speed=LS;
		sie_sop=1'b0;
		sie_eop=1'b0;
		sof_packet=1'b0;
		#10;
		rst_n=1'b1;
		usb_speed=FS;
		sof_packet=1'b0;
		write(10);
		write(10);
		#1000000 $finish();

	end
	initial begin
		$shm_open("wave.shm");
		$shm_probe("ACTMF");
	end

endmodule
