
package usb_phy_tb_pkg;

    import uvm_pkg::*;
    import usb_phy_pkg::*;

    `include "uvm_macros.svh"


    `include "usb_phy_ref_model.sv"
    
                 
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


                 
    // SCOREBOARD
                 

    `include "usb_phy_scb.sv"


                 
    // ENVIRONMENT CONFIGURATION
                 

    `include "usb_phy_env_config.sv"


                 
    // ENVIRONMENT
                 

    `include "usb_phy_env.sv"


                 
    // BASE TEST
                 

    `include "usb_phy_base_test.sv"

endpackage 
