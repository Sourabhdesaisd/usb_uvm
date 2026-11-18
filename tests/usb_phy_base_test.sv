

class usb_phy_base_test extends uvm_test;

  `uvm_component_utils(usb_phy_base_test)


    
  // 1. ENVIRONMENT
    

  usb_phy_env env;


    
  // 2. ENVIRONMENT CONFIGURATION
    

  usb_phy_env_config env_cfg;


    
  // 3. VIRTUAL INTERFACES
    

  virtual usb_phy_if phy_vif;

  virtual usb_bus_if usb_vif;


    
  // 4. USB SPEED ARGUMENT
    

  int unsigned speed_arg;


    
  // 5. CONSTRUCTOR
    

  function new(string name = "usb_phy_base_test",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction


    
  // 6. BUILD PHASE
    

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);


     
    // Get PHY virtual interface
     

    if (!uvm_config_db#(virtual usb_phy_if)::get(
          this, "", "phy_vif", phy_vif)) begin

      `uvm_fatal("BASE_TEST",
                 "PHY virtual interface not found")

    end


     
    // Get USB bus virtual interface
     

    if (!uvm_config_db#(virtual usb_bus_if)::get(
          this, "", "usb_vif", usb_vif)) begin

      `uvm_fatal("BASE_TEST",
                 "USB bus virtual interface not found")

    end


     
    // Read USB speed from command line
    //
    // 0 = Low Speed
    // 1 = Full Speed
    // 2 = High Speed
     

    if (!$value$plusargs("USB_SPEED=%d", speed_arg)) begin

      speed_arg = 1;

    end


     
    // Create environment configuration
     

    env_cfg = usb_phy_env_config::type_id::create(
                "env_cfg");


     
    // Configure USB speed
     

    case (speed_arg)

      0: begin

        env_cfg.speed = USB_SPEED_LS;

        `uvm_info("BASE_TEST",
                  "USB Low Speed selected",
                  UVM_LOW)

      end


      1: begin

        env_cfg.speed = USB_SPEED_FS;

        `uvm_info("BASE_TEST",
                  "USB Full Speed selected",
                  UVM_LOW)

      end


      2: begin

        env_cfg.speed = USB_SPEED_HS;

        `uvm_info("BASE_TEST",
                  "USB High Speed selected",
                  UVM_LOW)

      end


      default: begin

        `uvm_fatal("BASE_TEST",
                   "Invalid USB_SPEED. Use 0=LS, 1=FS, 2=HS")

      end

    endcase


     
    // Assign virtual interfaces
     

    env_cfg.phy_vif = phy_vif;

    env_cfg.usb_vif = usb_vif;


     
    // Agent activity configuration
     

    env_cfg.phy_is_active = UVM_ACTIVE;

    env_cfg.usb_is_active = UVM_ACTIVE;


     
    // Validate environment configuration
     

    env_cfg.validate_config();


     
    // Pass configuration to environment
     

    uvm_config_db#(usb_phy_env_config)::set(
      this,
      "env",
      "cfg",
      env_cfg
    );


     
    // Create USB PHY environment
     

    env = usb_phy_env::type_id::create(
            "env",
            this
          );


     
    // Configuration summary
     

    `uvm_info("BASE_TEST",
              $sformatf(
                "USB PHY Base Test Configuration: SPEED=%0d PHY_ACTIVE=%0d USB_ACTIVE=%0d",
                env_cfg.speed,
                env_cfg.phy_is_active,
                env_cfg.usb_is_active
              ),
              UVM_LOW)

  endfunction


task run_phase(uvm_phase phase);

  phy_simple_tx_seq tx_seq;

  phase.raise_objection(this);

  `uvm_info("BASE_TEST",
            "Starting simple PHY TX sequence",
            UVM_LOW)

  tx_seq = phy_simple_tx_seq::type_id::create("tx_seq");

  if (env.phy_ag == null ||
      env.phy_ag.sequencer == null) begin

    `uvm_fatal("BASE_TEST",
               "PHY agent or sequencer is NULL")

  end

  tx_seq.start(env.phy_ag.sequencer);

  `uvm_info("BASE_TEST",
            "Simple PHY TX sequence completed",
            UVM_LOW)

  // Allow a few clocks for final DUT observations
  repeat (10) @(posedge phy_vif.clk);

  phase.drop_objection(this);

endtask
  
endclass

