

class phy_agent_config extends uvm_object;

           
  // 1. VIRTUAL INTERFACE
           

  virtual usb_phy_if vif;


           
  // 2. AGENT CONFIGURATION
           

  uvm_active_passive_enum is_active;

  usb_speed_e speed;


           
  // 3. UVM FACTORY AND FIELD REGISTRATION
           

  `uvm_object_utils_begin(phy_agent_config)

    `uvm_field_enum(uvm_active_passive_enum,
                    is_active, UVM_ALL_ON)

    `uvm_field_enum(usb_speed_e,
                    speed, UVM_ALL_ON)

  `uvm_object_utils_end


           
  // 4. CONSTRUCTOR
           

  function new(string name = "phy_agent_config");

    super.new(name);

    vif       = null;
    is_active = UVM_ACTIVE;
    speed     = USB_SPEED_FS;

  endfunction


           
  // 5. CONFIGURATION VALIDATION
           

  function void validate_config();

    // Check virtual interface
    if (vif == null) begin

      `uvm_fatal("PHY_CFG",
                 "PHY virtual interface is NULL")

    end


    // Check USB speed
    if (speed == USB_SPEED_RESERVED) begin

      `uvm_fatal("PHY_CFG",
                 "Reserved USB speed is not supported")

    end


    // Check agent activity mode
    if ((is_active != UVM_ACTIVE) &&
        (is_active != UVM_PASSIVE)) begin

      `uvm_fatal("PHY_CFG",
                 "Invalid PHY agent activity configuration")

    end

  endfunction

endclass

