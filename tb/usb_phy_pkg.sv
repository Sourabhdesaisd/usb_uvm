
package usb_phy_tb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // USB speed enumeration used by UVM configuration
  typedef enum logic [1:0] {
    USB_SPEED_LS       = 2'b00,
    USB_SPEED_FS       = 2'b01,
    USB_SPEED_HS       = 2'b10,
    USB_SPEED_RESERVED = 2'b11
  } usb_speed_e;


  // USB line state enumeration used by USB BFM
  typedef enum logic [1:0] {
    USB_LINE_SE0 = 2'b00,
    USB_LINE_K   = 2'b01,
    USB_LINE_J   = 2'b10,
    USB_LINE_SE1 = 2'b11
  } usb_line_state_e;


      
  // PHY AGENT
      

  `include "phy_agent/phy_transaction.sv"
  `include "phy_agent/phy_agent_config.sv"
  `include "phy_agent/phy_sequencer.sv"
`include "phy_agent/phy_simple_tx_seq.sv"
  
  `include "phy_agent/phy_driver.sv"
  `include "phy_agent/phy_monitor.sv"
  `include "phy_agent/phy_agent.sv"


      
  // USB BFM AGENT
      

  `include "usb_bfm_agent/usb_bfm_transaction.sv"
  `include "usb_bfm_agent/usb_bfm_agent_config.sv"
  `include "usb_bfm_agent/usb_bfm_sequencer.sv"
  `include "usb_bfm_agent/usb_bfm_driver.sv"
  `include "usb_bfm_agent/usb_bfm_monitor.sv"
  `include "usb_bfm_agent/usb_bfm_agent.sv"


      
  // SCOREBOARD AND ENVIRONMENT
      

  `include "usb_phy_scb.sv"
  `include "usb_phy_env_config.sv"
  `include "usb_phy_env.sv"


      
  // TEST
      

  `include "usb_phy_base_test.sv"

endpackage

