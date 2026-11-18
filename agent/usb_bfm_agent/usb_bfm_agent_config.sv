

class usb_bfm_config extends uvm_object;

  // USB bus virtual interface
  virtual usb_bus_if vif;

  // Agent activity configuration
  uvm_active_passive_enum is_active;

  // USB speed configuration
  usb_speed_e speed;


  // UVM factory and field registration
  `uvm_object_utils_begin(usb_bfm_config)

    `uvm_field_enum(uvm_active_passive_enum,
                    is_active, UVM_ALL_ON)

    `uvm_field_enum(usb_speed_e,
                    speed, UVM_ALL_ON)

  `uvm_object_utils_end


  // Constructor
  function new(string name = "usb_bfm_config");

    super.new(name);

    vif       = null;
    is_active = UVM_ACTIVE;
    speed     = USB_SPEED_FS;

  endfunction


  // Configuration validation
  function void validate_config();

    if (vif == null) begin
      `uvm_fatal("USB_BFM_CFG",
                 "USB BFM virtual interface is NULL")
    end

    if (speed == USB_SPEED_RESERVED) begin
      `uvm_fatal("USB_BFM_CFG",
                 "Reserved USB speed is not supported")
    end

    if ((is_active != UVM_ACTIVE) &&
        (is_active != UVM_PASSIVE)) begin
      `uvm_fatal("USB_BFM_CFG",
                 "Invalid USB BFM agent activity configuration")
    end

  endfunction

endclass

