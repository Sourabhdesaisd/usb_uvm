
class usb_phy_base_test extends uvm_test;

  `uvm_component_utils(usb_phy_base_test)

  usb_phy_env env;

  usb_phy_env_config env_cfg;

  int unsigned speed_arg;

  virtual usb_phy_if phy_vif;
  virtual usb_bus_if usb_vif;


  function new(string name = "usb_phy_base_test",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    // --------------------------------------------
    // Get PHY virtual interface
    // --------------------------------------------
    if (!uvm_config_db#(virtual usb_phy_if)::get(
          this, "", "phy_vif", phy_vif)) begin

      `uvm_fatal("BASE_TEST",
                 "PHY virtual interface not found")

    end

    // --------------------------------------------
    // Get USB bus virtual interface
    // --------------------------------------------
    if (!uvm_config_db#(virtual usb_bus_if)::get(
          this, "", "usb_vif", usb_vif)) begin

      `uvm_fatal("BASE_TEST",
                 "USB bus virtual interface not found")

    end

    // --------------------------------------------
    // Read speed from command line
    // --------------------------------------------
    if (!$value$plusargs("USB_SPEED=%d", speed_arg))
      speed_arg = 1;  // Default FS

    // --------------------------------------------
    // Create environment configuration
    // --------------------------------------------
    env_cfg = usb_phy_env_config::type_id::create(
      "env_cfg"
    );

    // --------------------------------------------
    // Configure selected speed
    // --------------------------------------------
    case (speed_arg)

      0: env_cfg.speed = USB_SPEED_LS;

      1: env_cfg.speed = USB_SPEED_FS;

      2: env_cfg.speed = USB_SPEED_HS;

      default: begin

        `uvm_fatal("BASE_TEST",
                   "Invalid USB_SPEED. Use 0=LS, 1=FS, 2=HS")

      end

    endcase

    // --------------------------------------------
    // Assign virtual interfaces
    // --------------------------------------------
    env_cfg.phy_vif = phy_vif;
    env_cfg.usb_vif = usb_vif;

    // --------------------------------------------
    // Agent activity configuration
    // --------------------------------------------
    env_cfg.phy_is_active = UVM_ACTIVE;
    env_cfg.usb_is_active = UVM_ACTIVE;

    // Pass environment configuration
    uvm_config_db#(usb_phy_env_config)::set(
      this,
      "env",
      "cfg",
      env_cfg
    );

    // --------------------------------------------
    // Create environment
    // --------------------------------------------
    env = usb_phy_env::type_id::create(
      "env", this
    );

    `uvm_info("BASE_TEST",
              $sformatf("USB speed selected: %0d", speed_arg),
              UVM_LOW)

  endfunction

endclass

