module phy_top #(
	parameter int WIDTH      = 8,
    parameter int FIFO_DEPTH = 16,
    parameter int CLK_HZ            = 480_000_000,
    parameter int BAD_LIMIT         = 8,
    parameter int HS_SYNC_MIN_ALT   = 11,    // HS: 12-symbol minimum SYNC (hubs may truncate 4 bits each)
    parameter int HS_SYNC_MAX_ALT   = 31,    // HS: max alternating symbols (full 32-symbol SYNC)
    parameter int FSLS_SYNC_MIN_ALT = 7,     // FS/LS: 8-symbol SYNC
    parameter int FSLS_SYNC_MAX_ALT = 15,    // FS/LS: max alternating symbols (up to 4 extra KJ pairs tolerated)
    parameter int SYNC_ERR_MIN      = 5,
    parameter int EOP_SE0_MIN       = 1,     // FS/LS EOP: SE0 samples before J (spec: accept SE0 down to ~1 bit)
    parameter int EOP_SE0_MAX       = 3,
    parameter int HS_HOLDOFF_MAX    = 16384, // HS: SYNC search off after EOP until line idle (safety limit)
    parameter int RESET_SE0_NS      = 2500,  // LS/FS bus reset: SE0 longer than 2.5 us
    parameter bit ALIGN_IN_RXERROR  = 1'b0

)(
	input  logic             clk,
    input  logic             rst_n,
    input  speed_t           usb_speed,      // keep static while tx is busy
	
	// to analog drivers
    output logic             dp,
    output logic             dm,
	output logic 			 tx_valid,

	// analog front end inputs to CDR block
   	input logic 			 analog_d_plus,
	input logic 			 analog_d_minus,
	input logic 			 analog_enable,
	input logic 			 analog_serial,

	// SIE <-> PHY interface 
    input  logic             sof_packet,     // HS: use 40-bit SOF EOP
    input  logic [WIDTH-1:0] sie_data,
    input  logic             sie_valid,
    input  logic             sie_sop,
    input  logic             sie_eop,
    output logic             sie_ready,
    output logic [WIDTH-1:0] DataOut,
    output logic             RxValid,
    output logic             RxActive,
    output logic             RxError,
    output logic [1:0]       LineState,

    // packet markers, qualified by RxValid: first and last byte of a packet
    output logic             rx_sop,
    output logic             rx_eop,

    // optional status / debug (not part of the UTMI interface; may be left open)
    output logic             rx_stuff_err,
    output logic             rx_align_err,
    output logic             rx_line_err,
    output logic             rx_sync_err,
    output logic             rx_bus_reset     // LS/FS: SE0 held > 2.5 us (always 0 in HS)
);
	// from CDR / sampler block output
    logic             d_plus;
    logic             d_minus;
	logic recovered_bit_clk;
	speed_t speed;
	always_comb begin
		case(usb_speed)
			LS:speed = LS;
			FS:speed = FS;
			HS:speed = HS;
			default: speed=FS;
		endcase
	end

	// phy Tx path
	phy_tx_top #(
				.WIDTH      (WIDTH),
				.FIFO_DEPTH (FIFO_DEPTH),
				.CLK_HZ     (CLK_HZ)
				) dut_tx(
    				.clk         (clk),
    				.rst_n       (rst_n),
    				.usb_speed   (speed),     
    				.sof_packet  (sof_packet),     
    				.sie_data    (sie_data),
    				.sie_valid   (sie_valid),
    				.sie_sop     (sie_sop),
    				.sie_eop     (sie_eop),
    				.sie_ready   (sie_ready),
    				.dp          (dp),
    				.dm          (dm),
					.tx_valid    (tx_valid)
	);
	// phy Rx path
	phy_rx_top #(
    			.WIDTH				(WIDTH),             
    			.CLK_HZ 			(CLK_HZ),           
    			.BAD_LIMIT  		(BAD_LIMIT),       
    			.HS_SYNC_MIN_ALT 	(HS_SYNC_MIN_ALT),     
    			.HS_SYNC_MAX_ALT 	(HS_SYNC_MAX_ALT),     
    			.FSLS_SYNC_MIN_ALT	(FSLS_SYNC_MIN_ALT),    
    			.FSLS_SYNC_MAX_ALT	(FSLS_SYNC_MAX_ALT),    
    			.SYNC_ERR_MIN		(SYNC_ERR_MIN),      
    			.EOP_SE0_MIN		(EOP_SE0_MIN),         
    			.EOP_SE0_MAX		(EOP_SE0_MAX),       
    			.HS_HOLDOFF_MAX		(HS_HOLDOFF_MAX),    
    			.RESET_SE0_NS		(RESET_SE0_NS),        
    			.ALIGN_IN_RXERROR	(ALIGN_IN_RXERROR)  
				) dut_rx(
    			.clk			(clk),
    			.rst_n			(rst_n),
    			.usb_speed		(speed),
    			.d_plus			(d_plus),
    			.d_minus		(d_minus),
    			.sample_valid	(recovered_bit_clk),
    			.DataOut		(DataOut),
    			.RxValid		(RxValid),
    			.RxActive		(RxActive),
    			.RxError		(RxError),
    			.LineState		(LineState),
    			.rx_sop			(rx_sop),
    			.rx_eop			(rx_eop),
    			.rx_stuff_err	(rx_stuff_err),
    			.rx_align_err	(rx_align_err),
    			.rx_line_err	(rx_line_err),
    			.rx_sync_err	(rx_sync_err),
    			.rx_bus_reset	(rx_bus_reset)     
	);
	//clock and data recovery block
	usb2_cdr_top dut_cdr(
    			.clk_sys			(clk),
    			.rstn				(rst_n),
    			.enable				(tx_valid),
    			.speed				(speed),
    			.rx_serial			(dp),
    			.dp					(dp),
    			.dm					(dm),
    			.dp_out				(d_plus),
    			.dm_out				(d_minus),
    			.recovered_bit_clk	(recovered_bit_clk)
    );
	
endmodule
