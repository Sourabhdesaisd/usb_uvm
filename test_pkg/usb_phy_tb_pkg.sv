
package usb_phy_tb_pkg;

  import uvm_pkg::*;
  import usb_phy_pkg::*;

  `include "uvm_macros.svh"

  typedef enum logic [1:0] {
    USB_SPEED_LS       = 2'b00,
    USB_SPEED_FS       = 2'b01,
    USB_SPEED_HS       = 2'b10,
    USB_SPEED_RESERVED = 2'b11
  } usb_speed_e;

  typedef enum logic [1:0] {
    USB_LINE_SE0 = 2'b00,
    USB_LINE_K   = 2'b01,
    USB_LINE_J   = 2'b10,
    USB_LINE_SE1 = 2'b11
  } usb_line_state_e;



    
  // --------------------------------------------------
  // PHY AGENT
  // --------------------------------------------------

  `include "../phy_agent/phy_transaction.sv"
  `include "../phy_agent/phy_agent_config.sv"
  `include "../phy_agent/phy_sequencer.sv"
  `include "../phy_agent/phy_simple_tx_seq.sv"
  `include "../phy_agent/phy_driver.sv"
  `include "../phy_agent/phy_monitor.sv"
  `include "../phy_agent/phy_agent.sv"


  // --------------------------------------------------
  // USB BFM AGENT
  // --------------------------------------------------

  `include "../phy_bfm_agent/usb_bfm_transaction.sv"
  `include "../phy_bfm_agent/usb_bfm_agent_config.sv"
  `include "../phy_bfm_agent/usb_bfm_sequencer.sv"
  `include "../phy_bfm_agent/usb_bfm_driver.sv"
  `include "../phy_bfm_agent/usb_bfm_monitor.sv"
  `include "../phy_bfm_agent/usb_bfm_agent.sv"


 

  // --------------------------------------------------
  // SCOREBOARD
  // --------------------------------------------------

  `include "../phy_bfm_agent/usb_slave_model.sv"
  `include "../env/usb_phy_scb.sv"
  `include "../env/usb_phy_coverage.sv"


  // --------------------------------------------------
  // ENVIRONMENT
  // --------------------------------------------------

  `include "../env/usb_phy_env_config.sv"
  `include "../env/usb_phy_env.sv"


  // --------------------------------------------------
  // TESTS
  // --------------------------------------------------

  `include "../test/usb_phy_base_test.sv"
  `include "../test/usb_phy_tx_test.sv"
  `include "../test/usb_phy_slave_rx_test.sv"
  `include "../test/usb_phy_slave_turnaround_test.sv"
  `include "../test/usb_phy_full_path_test.sv"
  `include "../test/usb_phy_fault_test.sv"
  `include "../test/usb_phy_speed_switch_test.sv"
  `include "../test/usb_phy_reset_test.sv"
  `include "../test/usb_phy_back_to_back_test.sv"
  `include "../test/usb_phy_underrun_test.sv"
  `include "../test/usb_phy_cdr_test.sv"
  `include "../test/usb_phy_alignment_test.sv"

endpackage : usb_phy_tb_pkg

