class usb_bfm_transaction extends uvm_sequence_item;

  // Stimulus
  rand usb_line_state_e line_state;
  rand int unsigned     bit_count;

  // Monitor observations
  logic device_dp;
  logic device_dm;
  logic device_oe;

  logic [1:0] phy_line_state;
  logic       phy_tx_valid;

  logic       is_device_drive;
  logic       is_phy_tx;

  `uvm_object_utils_begin(usb_bfm_transaction)

    `uvm_field_enum(usb_line_state_e, line_state, UVM_ALL_ON)
    `uvm_field_int(bit_count, UVM_ALL_ON)

    `uvm_field_int(device_dp, UVM_ALL_ON)
    `uvm_field_int(device_dm, UVM_ALL_ON)
    `uvm_field_int(device_oe, UVM_ALL_ON)

    `uvm_field_int(phy_line_state, UVM_ALL_ON)
    `uvm_field_int(phy_tx_valid, UVM_ALL_ON)

    `uvm_field_int(is_device_drive, UVM_ALL_ON)
    `uvm_field_int(is_phy_tx, UVM_ALL_ON)

  `uvm_object_utils_end

  constraint valid_bit_count_c {
    bit_count inside {[1:1024]};
  }

  function new(string name = "usb_bfm_transaction");

    super.new(name);

    line_state      = USB_LINE_SE0;
    bit_count       = 1;

    device_dp       = 1'b0;
    device_dm       = 1'b0;
    device_oe       = 1'b0;

    phy_line_state  = 2'b00;
    phy_tx_valid    = 1'b0;

    is_device_drive = 1'b0;
    is_phy_tx       = 1'b0;

  endfunction

endclass
