
class usb_bfm_transaction extends uvm_sequence_item;


       
  //  STIMULUS FIELDS
       

  // USB line state driven by external partner
  rand usb_line_state_e line_state;

  // Number of bit intervals to hold the requested state
  rand int unsigned bit_count;


       
  //  EXTERNAL PARTNER OBSERVATIONS
       

  logic device_dp;
  logic device_dm;
  logic device_oe;


       
  //  DUT PHYSICAL TX OBSERVATIONS
       

  logic [1:0] phy_line_state;
  logic       phy_tx_valid;


       
  //  MONITOR EVENT INDICATORS
       

  bit is_device_drive;
  bit is_phy_tx;


       
  //  UVM FIELD REGISTRATION
       

  `uvm_object_utils_begin(usb_bfm_transaction)

    // Stimulus
    `uvm_field_enum(usb_line_state_e, line_state, UVM_ALL_ON)
    `uvm_field_int(bit_count, UVM_ALL_ON)

    // External partner observations
    `uvm_field_int(device_dp, UVM_ALL_ON)
    `uvm_field_int(device_dm, UVM_ALL_ON)
    `uvm_field_int(device_oe, UVM_ALL_ON)

    // DUT TX observations
    `uvm_field_int(phy_line_state, UVM_ALL_ON)
    `uvm_field_int(phy_tx_valid, UVM_ALL_ON)

    // Monitor event indicators
    `uvm_field_int(is_device_drive, UVM_ALL_ON)
    `uvm_field_int(is_phy_tx, UVM_ALL_ON)

  `uvm_object_utils_end


       
  //  RANDOMIZATION CONSTRAINTS
       

  // Keep bit_count within the supported driver range
  constraint valid_bit_count_c {

    bit_count inside {[1:1024]};

  }

  // Allow only defined USB line states
  constraint valid_line_state_c {

    line_state inside {
      USB_LINE_SE0,
      USB_LINE_SE1,
      USB_LINE_J,
      USB_LINE_K
    };

  }


       
  //  CONSTRUCTOR
       

  function new(string name = "usb_bfm_transaction");

    super.new(name);

    // Stimulus defaults
    line_state = USB_LINE_SE0;
    bit_count  = 1;

    // External partner observation defaults
    device_dp = 1'b0;
    device_dm = 1'b0;
    device_oe = 1'b0;

    // DUT physical TX observation defaults
    phy_line_state = 2'b00;
    phy_tx_valid   = 1'b0;

    // Monitor event defaults
    is_device_drive = 1'b0;
    is_phy_tx       = 1'b0;

  endfunction

endclass

