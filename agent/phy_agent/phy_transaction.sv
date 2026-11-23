
class phy_transaction extends uvm_sequence_item;

        
  // SIE TO PHY - TX STIMULUS
        

  rand bit        sie_valid;
  rand bit [7:0]  sie_data;
  rand bit        sop;
  rand bit        eop;
  rand bit        sof_packet;


        
  // ONITOR EVENT INDICATORS
        

  bit is_sie_transfer;
  bit is_rx_transfer;


        
  // COMMON DUT OBSERVATIONS
        

  logic       rst_n;
  logic [1:0] usb_speed;
  logic       sie_ready;


        
  //  PHYSICAL TX OBSERVATIONS
        

  logic dp;
  logic dm;
  logic tx_valid;


        
  // PHY RX DATA OBSERVATIONS
        

  logic [7:0] DataOut;
  logic       RxValid;
  logic       RxActive;
  logic       RxError;

  logic [1:0] LineState;

  logic       rx_sop;
  logic       rx_eop;


        
  // RX ERROR AND STATUS OBSERVATIONS
        

  logic rx_stuff_err;
  logic rx_align_err;
  logic rx_line_err;
  logic rx_babble_err;
  logic rx_sync_err;
  logic rx_bus_reset;


        
  //  UVM FIELD REGISTRATION
        

  `uvm_object_utils_begin(phy_transaction)

    // TX stimulus
    `uvm_field_int(sie_valid,        UVM_ALL_ON)
    `uvm_field_int(sie_data,         UVM_ALL_ON)
    `uvm_field_int(sop,              UVM_ALL_ON)
    `uvm_field_int(eop,              UVM_ALL_ON)
    `uvm_field_int(sof_packet,       UVM_ALL_ON)

    // Monitor event indicators
    `uvm_field_int(is_sie_transfer,  UVM_ALL_ON)
    `uvm_field_int(is_rx_transfer,   UVM_ALL_ON)

    // Common observations
    `uvm_field_int(rst_n,            UVM_ALL_ON)
    `uvm_field_int(usb_speed,        UVM_ALL_ON)
    `uvm_field_int(sie_ready,        UVM_ALL_ON)

    // Physical TX observations
    `uvm_field_int(dp,               UVM_ALL_ON)
    `uvm_field_int(dm,               UVM_ALL_ON)
    `uvm_field_int(tx_valid,         UVM_ALL_ON)

    // RX data observations
    `uvm_field_int(DataOut,          UVM_ALL_ON)
    `uvm_field_int(RxValid,          UVM_ALL_ON)
    `uvm_field_int(RxActive,         UVM_ALL_ON)
    `uvm_field_int(RxError,          UVM_ALL_ON)
    `uvm_field_int(LineState,        UVM_ALL_ON)

    `uvm_field_int(rx_sop,           UVM_ALL_ON)
    `uvm_field_int(rx_eop,           UVM_ALL_ON)

    // RX status
    `uvm_field_int(rx_stuff_err,     UVM_ALL_ON)
    `uvm_field_int(rx_align_err,     UVM_ALL_ON)
    `uvm_field_int(rx_line_err,      UVM_ALL_ON)
    `uvm_field_int(rx_babble_err,    UVM_ALL_ON)
    `uvm_field_int(rx_sync_err,      UVM_ALL_ON)
    `uvm_field_int(rx_bus_reset,     UVM_ALL_ON)

  `uvm_object_utils_end


        
  // 8. CONSTRUCTOR
        

  function new(string name = "phy_transaction");

    super.new(name);

    // TX stimulus defaults
    sie_valid = 0;
    sie_data  = 0;
    sop       = 0;
    eop       = 0;
    sof_packet = 0;

    // Monitor event defaults
    is_sie_transfer = 0;
    is_rx_transfer  = 0;

    // Common observation defaults
    rst_n     = 0;
    usb_speed = 2'b11;
    sie_ready = 0;

    // Physical TX defaults
    dp       = 0;
    dm       = 0;
    tx_valid = 0;

    // RX data defaults
    DataOut  = 0;
    RxValid  = 0;
    RxActive = 0;
    RxError  = 0;

    LineState = 0;

    rx_sop = 0;
    rx_eop = 0;

    // RX status defaults
    rx_stuff_err  = 0;
    rx_align_err  = 0;
    rx_line_err   = 0;
    rx_babble_err = 0;
    rx_sync_err   = 0;
    rx_bus_reset  = 0;

  endfunction

endclass

