
class usb_bfm_config extends uvm_object;

  `uvm_object_utils_begin(usb_bfm_config)

    `uvm_field_enum(uvm_active_passive_enum,
                    is_active, UVM_ALL_ON)

    `uvm_field_enum(usb_speed_e,
                    speed, UVM_ALL_ON)

  `uvm_object_utils_end


        
  // 1. USB BUS VIRTUAL INTERFACE
        

  virtual usb_bus_if vif;


        
  // 2. AGENT ACTIVE / PASSIVE CONFIGURATION
        

  uvm_active_passive_enum is_active;


        
  // 3. USB SPEED CONFIGURATION
        

  usb_speed_e speed;


        
  // 4. CONSTRUCTOR
        

  function new(string name = "usb_bfm_config");

    super.new(name);

    vif       = null;
    is_active = UVM_ACTIVE;
    speed     = USB_SPEED_FS;

  endfunction


        
  // 5. CONFIGURATION VALIDATION
        

  function void validate_config();

    if (vif == null) begin

      `uvm_fatal("USB_BFM_CFG_VIF",
                 "USB BFM virtual interface is NULL")

    end

    if (speed == USB_SPEED_RESERVED) begin

      `uvm_fatal("USB_BFM_CFG_SPEED",
                 "Reserved USB speed selected")

    end

    if ((is_active != UVM_ACTIVE) &&
        (is_active != UVM_PASSIVE)) begin

      `uvm_fatal("USB_BFM_CFG_ACTIVE",
                 "Invalid USB BFM active/passive configuration")

    end

  endfunction

endclass

