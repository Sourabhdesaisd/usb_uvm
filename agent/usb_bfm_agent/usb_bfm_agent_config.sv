class usb_bfm_config extends uvm_object;

  virtual usb_bus_if vif;

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  usb_speed_e speed = USB_SPEED_FS;

  `uvm_object_utils_begin(usb_bfm_config)

    `uvm_field_enum(uvm_active_passive_enum,
                    is_active, UVM_ALL_ON)

    `uvm_field_enum(usb_speed_e,
                    speed, UVM_ALL_ON)

  `uvm_object_utils_end

  function new(string name = "usb_bfm_config");

    super.new(name);

  endfunction

endclass
