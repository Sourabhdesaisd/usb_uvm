// file: phy_tx_top.sv
//
//  SIE -> FIFO -> PISO -> BIT STUFFER -> NRZI -> line-state conv -+
//                  ^  |                    |        |            +-> MUX -> pads
//                  |  +- sop/last tags ----+--------+--- eop_start
//                  +---------------- eop_done ---- EOP GEN -------+
//
//  Control summary
//   * One bit_tick for everything.  Every stage moves only on bit_tick.
//   * phy_bfm_sop / phy_bfm_last travel with the bit through stuffer and NRZI
//     (the 'last' tag moves onto a trailing stuffed bit if one is needed).
//   * eop_start = nrzi_valid & nrzi_last : the last data symbol is on the
//     line now; the EOP generator takes over on the very next bit_tick.
//   * While EOP runs, the PISO sits in HOLD (so stuffer/NRZI see no bits);
//     eop_done releases it.  The next packet may start any time after that.
//   * SYNC + DATA + (stuff) + EOP are therefore back-to-back symbols,
//     one per bit time, with no idle symbol inside a packet.
module phy_tx_top
#(
    parameter int WIDTH      = 8,
    parameter int FIFO_DEPTH = 16,
    parameter int CLK_HZ     = 480_000_000
)(
    input  logic             clk,
    input  logic             rst_n,

    input  speed_t           usb_speed,      // keep static while tx is busy
    input  logic             sof_packet,     // HS: use 40-bit SOF EOP

    // SIE interface
    input  logic [WIDTH-1:0] sie_data,
    input  logic             sie_valid,
    input  logic             sie_sop,
    input  logic             sie_eop,
    output logic             sie_ready,

    // USB pads
    output logic             dp,
    output logic             dm,
	output logic 			 tx_valid
);
    logic bit_tick;
    logic             tx_busy;
    logic             tx_underrun;
    logic [WIDTH-1:0] fifo_data;
    logic fifo_valid, fifo_sop, fifo_eop, fifo_pop;
    logic phy_bfm_out, phy_bfm_valid, phy_bfm_sop, phy_bfm_last;
    logic stuff_ready;
    logic stuffed_bit, stuffed_valid, stuffed_sop, stuffed_last;
    logic nrzi_bit, nrzi_valid, nrzi_last;
    logic [1:0] data_line_state;
    logic data_line_valid;
    logic eop_start, eop_valid, eop_done, eop_busy;
    logic [1:0] eop_line_state;
    logic [1:0] tx_line_state;
	logic fifo_full;
	logic fifo_empty;

	//bit enabler for usb_speed
    usb_speed_tick #(.CLK_HZ(CLK_HZ)) u_tick (
        			 .clk		(clk), 
					 .rst_n		(rst_n), 
					 .usb_speed	(usb_speed), 
					 .bit_tick	(bit_tick)
    );

	// tx byte holding register
    usb2_tx_fifo #(.DATA_WIDTH(WIDTH), 
				   .FIFO_DEPTH(FIFO_DEPTH)
				  ) u_fifo (
        		   .clk			(clk), 
				   .rst_n		(rst_n),
        		   .sie_data	(sie_data), 
				   .sie_valid	(sie_valid), 
				   .sie_sop		(sie_sop),
        		   .sie_eop		(sie_eop), 
				   .sie_ready	(sie_ready),
        		   .fifo_data	(fifo_data), 
				   .fifo_valid	(fifo_valid),
        		   .fifo_sop	(fifo_sop), 
				   .fifo_eop	(fifo_eop),
        		   .piso_ready	(fifo_pop),
        		   .fifo_full	(fifo_full), 
				   .fifo_empty	(fifo_empty)
    );
	//tx byte phy_bfmizer
    usb_piso #(.WIDTH(WIDTH)
			  ) u_piso (
        	   .clk			(clk), 
			   .rst_n		(rst_n), 
			   .bit_tick	(bit_tick), 
			   .usb_speed	(usb_speed),
        	   .fifo_valid	(fifo_valid), 
			   .fifo_data	(fifo_data),
        	   .fifo_sop	(fifo_sop), 
			   .fifo_eop	(fifo_eop), 
			   .fifo_pop	(fifo_pop),
        	   .stuff_ready	(stuff_ready), 
			   .eop_done	(eop_done),
        	   .phy_bfm_out	(phy_bfm_out), 
			   .phy_bfm_valid(phy_bfm_valid),
        	   .phy_bfm_sop	(phy_bfm_sop), 
			   .phy_bfm_last	(phy_bfm_last),
        	   .busy		(tx_busy), 
			   .underrun	(tx_underrun)
    );
	//bit stuffer 
    usb2_bit_stuffer u_stuffer (
        	   .clk				(clk), 
			   .rst_n			(rst_n), 
			   .bit_tick		(bit_tick),
        	   .bit_in			(phy_bfm_out), 
			   .bit_in_valid	(phy_bfm_valid),
        	   .bit_in_sop		(phy_bfm_sop), 
			   .bit_in_last		(phy_bfm_last),
        	   .bit_in_ready	(stuff_ready),
        	   .bit_out			(stuffed_bit), 
			   .bit_out_valid	(stuffed_valid),
        	   .bit_out_sop		(stuffed_sop), 
			   .bit_out_last	(stuffed_last)
    );
	//nrzi encoder
    usb_nrzi_encoder u_nrzi (
        	   .clk				(clk), 
			   .rst_n			(rst_n), 
			   .bit_tick		(bit_tick),
        	   .bit_in			(stuffed_bit), 
			   .bit_in_valid	(stuffed_valid),
        	   .bit_in_sop		(stuffed_sop), 
			   .bit_in_last		(stuffed_last),
        	   .nrzi_out		(nrzi_bit), 
			   .nrzi_out_valid	(nrzi_valid),
        	   .nrzi_out_last	(nrzi_last)
    );
	// data line state converter
    tx_line_state_converter u_line_conv (
        	   .nrzi_bit	(nrzi_bit), 
			   .nrzi_valid	(nrzi_valid), 
			   .usb_speed	(usb_speed),
        	   .line_state	(data_line_state), 
			   .line_valid	(data_line_valid)
    );

    // last data symbol is on the line -> EOP takes over at the next tick
    assign eop_start = nrzi_valid && nrzi_last;
	//EOP pattern generator
    usb_eop_gen u_eop (
        	   .clk				(clk), 
			   .rst_n			(rst_n), 
			   .bit_tick		(bit_tick), 
			   .usb_speed		(usb_speed),
        	   .eop_start		(eop_start), 
			   .sof_packet		(sof_packet),
        	   .last_nrzi_state	(nrzi_bit),
               .eop_line_state	(eop_line_state), 
			   .eop_valid		(eop_valid),
               .eop_done		(eop_done), 
			   .busy			(eop_busy)
    );
	//tx line state selector
    usb_tx_line_mux u_mux (
        	   .usb_speed		(usb_speed),
        	   .data_line_state	(data_line_state), 
			   .data_valid		(data_line_valid),
        	   .eop_line_state	(eop_line_state),   
			   .eop_valid		(eop_valid),
        	   .tx_line_state	(tx_line_state),     
			   .tx_valid		(tx_valid)
    );

	always_comb begin
		case(usb_speed)
			LS: begin
				dp = (tx_valid)? tx_line_state[1]:1'b0;
				dm = (tx_valid)? tx_line_state[0]:1'b1;
			end
			FS: begin
				dp = (tx_valid)? tx_line_state[1]:1'b1;
				dm = (tx_valid)? tx_line_state[0]:1'b0;
			end
			HS: begin
				dp = (tx_valid)? tx_line_state[1]:1'b0;
				dm = (tx_valid)? tx_line_state[0]:1'b0;
			end
		endcase
	end
endmodule

