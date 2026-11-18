class phy_transaction extends uvm_sequence_item;

  // SIE to PHY: TX stimulus
  rand bit        sie_valid;
  rand bit [7:0]  sie_data;
  rand bit        sop;
  rand bit        eop;
  rand bit        sof_packet;

  // Monitor event indicators
  bit is_sie_transfer;
  bit is_rx_transfer;

  // DUT observations
  logic        rst_n;
  logic [1:0]  usb_speed;
  logic        sie_ready;

  logic [1:0]  tx_line_state;
  logic        tx_valid;

  logic        rx_dp;
  logic        rx_dm;

  logic [7:0]  Rx_data;
  logic        Rx_valid;
  logic [1:0]  line_state;

  `uvm_object_utils_begin(phy_transaction)

    `uvm_field_int(sie_valid,       UVM_ALL_ON)
    `uvm_field_int(sie_data,        UVM_ALL_ON)
    `uvm_field_int(sop,             UVM_ALL_ON)
    `uvm_field_int(eop,             UVM_ALL_ON)
    `uvm_field_int(sof_packet,      UVM_ALL_ON)

    `uvm_field_int(is_sie_transfer,UVM_ALL_ON)
    `uvm_field_int(is_rx_transfer, UVM_ALL_ON)

    `uvm_field_int(rst_n,           UVM_ALL_ON)
    `uvm_field_int(usb_speed,       UVM_ALL_ON)
    `uvm_field_int(sie_ready,       UVM_ALL_ON)

    `uvm_field_int(tx_line_state,   UVM_ALL_ON)
    `uvm_field_int(tx_valid,        UVM_ALL_ON)

    `uvm_field_int(rx_dp,           UVM_ALL_ON)
    `uvm_field_int(rx_dm,           UVM_ALL_ON)
    `uvm_field_int(Rx_data,         UVM_ALL_ON)
    `uvm_field_int(Rx_valid,        UVM_ALL_ON)
    `uvm_field_int(line_state,      UVM_ALL_ON)

  `uvm_object_utils_end

  function new(string name = "phy_transaction");
    super.new(name);

    sie_valid       = 0;
    sie_data        = 0;
    sop             = 0;
    eop             = 0;
    sof_packet      = 0;

    is_sie_transfer = 0;
    is_rx_transfer  = 0;

    rst_n           = 0;
    usb_speed       = 2'b11;
    sie_ready       = 0;

    tx_line_state   = 0;
    tx_valid        = 0;

    rx_dp           = 0;
    rx_dm           = 0;
    Rx_data         = 0;
    Rx_valid        = 0;
    line_state      = 0;

  endfunction

endclass
