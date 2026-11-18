
class phy_agent_config extends uvm_object;

  // PHY virtual interface
  virtual usb_phy_if vif;

  // Agent active/passive mode
  uvm_active_passive_enum is_active;

  // Runtime USB speed
  usb_speed_e speed;

  `uvm_object_utils_begin(phy_agent_config)

    `uvm_field_enum(uvm_active_passive_enum,
                    is_active, UVM_ALL_ON)

    `uvm_field_enum(usb_speed_e,
                    speed, UVM_ALL_ON)

  `uvm_object_utils_end


  function new(string name = "phy_agent_config");

    super.new(name);

    vif       = null;
    is_active = UVM_ACTIVE;
    speed     = USB_SPEED_FS;

  endfunction

endclass

