
class usb_phy_base_test extends uvm_test;

  `uvm_component_utils(usb_phy_base_test)

  // --------------------------------------------------
  // Environment configuration and environment handles
  // --------------------------------------------------

  usb_phy_env_config env_cfg;
  usb_phy_env        env;

  // --------------------------------------------------
  // Constructor
  // --------------------------------------------------

  function new(
    string name = "usb_phy_base_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  // --------------------------------------------------
  // Build phase
  // --------------------------------------------------

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    // Get environment configuration created by tb_top.
    if (!uvm_config_db#(usb_phy_env_config)::get(
          this,
          "",
          "env_cfg",
          env_cfg
        )) begin

      `uvm_fatal(
        "BASE_TEST",
        "Cannot get env_cfg from uvm_config_db. Check tb_top."
      )

    end

    // Check configuration handle.
    if (env_cfg == null) begin

      `uvm_fatal(
        "BASE_TEST",
        "Environment configuration handle is NULL."
      )

    end

    // At least one verification component must be enabled.
    if (!env_cfg.enable_phy_agent &&
        !env_cfg.enable_usb_bfm_agent &&
        !env_cfg.enable_scoreboard) begin

      `uvm_fatal(
        "BASE_TEST",
        "PHY agent, USB BFM agent and scoreboard are all disabled."
      )

    end

    // Pass configuration to the environment.
    uvm_config_db#(usb_phy_env_config)::set(
      this,
      "env",
      "cfg",
      env_cfg
    );

    // Create UVM environment.
    env = usb_phy_env::type_id::create(
      "env",
      this
    );

    `uvm_info(
      "BASE_TEST",
      "USB PHY base test build phase completed.",
      UVM_LOW
    )

  endfunction

  // --------------------------------------------------
  // Connect phase
  // --------------------------------------------------

  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    `uvm_info(
      "BASE_TEST",
      "USB PHY base test connect phase completed.",
      UVM_LOW
    )

  endfunction

  // --------------------------------------------------
  // End of elaboration phase
  // --------------------------------------------------

  function void end_of_elaboration_phase(
    uvm_phase phase
  );

    super.end_of_elaboration_phase(phase);

    `uvm_info(
      "BASE_TEST",
      "Printing USB PHY UVM testbench topology.",
      UVM_LOW
    )

    uvm_top.print_topology();

  endfunction

  // --------------------------------------------------
  // Run phase
  // --------------------------------------------------

    task run_phase(uvm_phase phase);
    
      phase.raise_objection(this);
    
      `uvm_info(
        "BASE_TEST",
        "USB PHY base test started",
        UVM_LOW
      )
    
      // Wait until reset is released by tb_top.
      wait (env_cfg.phy_cfg.vif.rst_n === 1'b1);
    
      `uvm_info(
        "BASE_TEST",
        "DUT reset released",
        UVM_LOW
      )
    
      // Allow one clock after reset release.
      @(posedge env_cfg.phy_cfg.vif.clk);
    
      `uvm_info(
        "BASE_TEST",
        "USB PHY base test completed",
        UVM_LOW
      )
    
      phase.drop_objection(this);
    
    endtask
  // --------------------------------------------------
  // Report phase
  // --------------------------------------------------

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info(
      "BASE_TEST",
      "USB PHY base test completed.",
      UVM_LOW
    )

  endfunction

endclass

