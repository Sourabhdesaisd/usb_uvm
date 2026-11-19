// file: phy_rx_top.sv
//
// Digital PHY receive path with the UTMI-style SIE interface
// (DataOut, RxValid, RxActive, RxError, LineState).
//
//  CDR sampler block (separate design)               phy_rx_top
//   d_plus, d_minus, sample_valid -->  [u_line] -> [u_sync] -> [u_ctrl] -> RxActive / RxError
//                                                     |            |
//                                      [u_nrzi] -> [u_unstuff] -> [u_sipo] -> DataOut / RxValid
//   LineState = {d_minus, d_plus}
//
// Packet markers (valid with RxValid, not part of UTMI):
//   rx_sop : 1 clk, together with the FIRST byte of the packet on DataOut
//   rx_eop : 1 clk, together with the LAST byte of the packet on DataOut
//   (both are high on a 1-byte packet).  Bytes are released one byte late so the last byte
//   can be recognised; see usb2_rx_ctrl.
//
// Contract with the CDR / sampler block
//   * d_plus / d_minus : line levels, synchronous to clk (already synchronized).
//   * sample_valid     : 1-clk pulse once per received bit time, at the middle of
//                        the bit (HS: asserted every clk).  d_plus / d_minus must
//                        carry the sampled bit value in that same clock.
//   * HS: clk is the 480 MHz clock locked to the incoming data (see notes).
//
// Interface mapping
//   LineState  : raw {DM, DP}: 00 SE0, 01 J (FS) / K (LS), 10 K (FS) / J (LS), 11 SE1.
//   RxError    : bit-stuff violation, packet not ending on a byte boundary, illegal line
//                state, or babble; high only while RxActive = 1 (sample it when RxActive falls).
module phy_rx_top
    import usb_phy_pkg::*;
#(
    parameter int WIDTH             = 8,
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
    input  speed_t 			 usb_speed,

    // from CDR / sampler block
    input  logic             d_plus,
    input  logic             d_minus,
    input  logic             sample_valid,

    // SIE <-> PHY interface (UTMI naming)
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
    // ---------------- interface decode ----------------
    assign LineState = {d_plus,d_minus};
    // ---------------- internal nets ----------------
    logic line_j, line_k, line_se0, line_se1;
    logic sop_det, eop_det, sync_error;
    logic sym_bit, sym_valid;
    logic dec_sop, dec_eop, unst_sop, unst_eop, sipo_clear;
    logic nrzi_dec_out, dec_valid;
    logic unst_bit, unst_valid, stuff_err;
    logic [WIDTH-1:0] sipo_data;
    logic sipo_valid, sipo_busy;
    logic [$clog2(WIDTH)-1:0] sipo_bit_count;
    logic bus_reset, sync_search_en;

    usb2_rx_line_state_detector u_line (
        						.d_plus		(d_plus), 
								.d_minus	(d_minus), 
								.speed		(usb_speed),
        						.line_j		(line_j), 
								.line_k		(line_k), 
								.line_se0	(line_se0), 
								.line_se1	(line_se1)
    );

    usb2_rx_reset_detect #(.CLK_HZ		(CLK_HZ), 
						   .RESET_SE0_NS(RESET_SE0_NS)
						  ) u_reset (
        				   .clk			(clk), 
						   .rst_n		(rst_n), 
						   .speed		(usb_speed),
        				   .d_plus		(d_plus), 
						   .d_minus		(d_minus), 
						   .bus_reset	(bus_reset)
    );
    assign rx_bus_reset = bus_reset;

    usb2_rx_sync_eop_detector #(.HS_SYNC_MIN_ALT	(HS_SYNC_MIN_ALT), 
								.HS_SYNC_MAX_ALT	(HS_SYNC_MAX_ALT),
        						.FSLS_SYNC_MIN_ALT	(FSLS_SYNC_MIN_ALT), 
								.FSLS_SYNC_MAX_ALT	(FSLS_SYNC_MAX_ALT),
        						.SYNC_ERR_MIN		(SYNC_ERR_MIN), 
								.EOP_SE0_MIN		(EOP_SE0_MIN), 
								.EOP_SE0_MAX		(EOP_SE0_MAX),
        						.HS_HOLDOFF_MAX		(HS_HOLDOFF_MAX)
    							) u_sync (
        						.clk			(clk), 
								.rst_n			(rst_n), 
								.speed			(usb_speed), 
								.sample_valid	(sample_valid),
        						.sync_search_en	(sync_search_en),
        						.line_j			(line_j), 
								.line_k			(line_k), 
								.line_se0		(line_se0), 
								.line_se1		(line_se1),
        						.sop			(sop_det), 
								.eop			(eop_det), 
								.sync_error		(sync_error)
    );

    usb2_rx_ctrl #(.WIDTH			(WIDTH), 
				   .BAD_LIMIT		(BAD_LIMIT),
        		   .EOP_SE0_MIN		(EOP_SE0_MIN), 
				   .EOP_SE0_MAX		(EOP_SE0_MAX), 
				   .ALIGN_IN_RXERROR(ALIGN_IN_RXERROR)
    			  ) u_ctrl (
        		   .clk				(clk), 
				   .rst_n			(rst_n), 
				   .speed			(usb_speed),
				   .bus_reset		(bus_reset),
        		   .sample_valid	(sample_valid),
        		   .line_j			(line_j), 
				   .line_k			(line_k), 
				   .line_se0		(line_se0), 
				   .line_se1		(line_se1),
        		   .sop_det			(sop_det), 
				   .eop_det			(eop_det), 
				   .sync_err_det	(sync_error),
        		   .stuff_err		(stuff_err), 
				   .sync_search_en	(sync_search_en),
        		   .sipo_bit_count	(sipo_bit_count), 
				   .sipo_data		(sipo_data), 
				   .sipo_valid		(sipo_valid),
        		   .sym_bit			(sym_bit), 
				   .sym_valid		(sym_valid),
        		   .dec_sop			(dec_sop), 
				   .dec_eop			(dec_eop),
        		   .unst_sop		(unst_sop), 
				   .unst_eop		(unst_eop), 
				   .sipo_clear		(sipo_clear),
        		   .rx_active		(RxActive), 
				   .rx_sop			(rx_sop), 
				   .rx_eop			(rx_eop),
        		   .rx_valid		(RxValid), 
				   .rx_data			(DataOut),
        		   .rx_error		(RxError), 
				   .rx_stuff_err	(rx_stuff_err), 
				   .rx_align_err	(rx_align_err),
        		   .rx_line_err		(rx_line_err), 
				   .rx_sync_err		(rx_sync_err)
    );

    usb2_nrzi_decoder u_nrzi (
        		   .clk				(clk), 
				   .rst_n			(rst_n),
        		   .sop				(dec_sop), 
				   .eop				(dec_eop),
        		   .nrzi_enc_in		(sym_bit), 
				   .nrzi_enc_valid	(sym_valid),
        		   .nrzi_dec_out	(nrzi_dec_out), 
				   .data_valid		(dec_valid)
    );

    usb2_bit_unstuffer u_unstuff (
        		   .clk				(clk), 
				   .rst_n			(rst_n),
        		   .sop				(unst_sop), 
				   .eop				(unst_eop),
        		   .bit_in			(nrzi_dec_out), 
				   .bit_in_valid	(dec_valid),
        		   .bit_out			(unst_bit), 
				   .bit_out_valid	(unst_valid), 
				   .stuff_err		(stuff_err)
    );

    usb_sipo #(.WIDTH(WIDTH)) u_sipo (
        		   .clk				(clk), 
				   .rst_n			(rst_n),
        		   .serial_in		(unst_bit), 
				   .serial_valid	(unst_valid),
        		   .parallel_out	(sipo_data), 
				   .parallel_valid	(sipo_valid), 
				   .busy			(sipo_busy),
        		   .clear			(sipo_clear), 
				   .bit_count_out	(sipo_bit_count)
    );

endmodule


