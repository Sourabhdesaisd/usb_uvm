package usb_phy_pkg;
	typedef enum logic[1:0]{
		LS=2'b00,
		FS=2'b01,
		HS=2'b10
	}speed_t;
endpackage

import usb_phy_pkg::*;
