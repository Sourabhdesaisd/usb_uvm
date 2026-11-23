
class usb_phy_base_test extends uvm_test;

  `uvm_component_utils(usb_phy_base_test)

  // Environment configuration
  usb_phy_env_config env_cfg;

  // Environment instance
  usb_phy_env env;

  // Constructor
  function new(
    string name = "usb_phy_base_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    // Get environment configuration from tb_top
    if (!uvm_config_db#(usb_phy_env_config)::get(
          this,
          "",
          "env_cfg",
          env_cfg
        )) begin

      `uvm_fatal(
        "BASE_TEST",
        "Failed to get environment configuration from config_db"
      )

    end

    if (env_cfg == null) begin

      `uvm_fatal(
        "BASE_TEST",
        "Environment configuration handle is NULL"
      )

    end

    // Pass configuration to environment
    uvm_config_db#(usb_phy_env_config)::set(
      this,
      "env",
      "cfg",
      env_cfg
    );

    // Create environment
    env = usb_phy_env::type_id::create(
      "env",
      this
    );

    `uvm_info(
      "BASE_TEST",
      "USB PHY base test build completed",
      UVM_LOW
    )

  endfunction

  // Connect phase
  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    `uvm_info(
      "BASE_TEST",
      "USB PHY base test connect phase completed",
      UVM_LOW
    )

  endfunction

  // End of elaboration phase
  function void end_of_elaboration_phase(uvm_phase phase);

    super.end_of_elaboration_phase(phase);

    `uvm_info(
      "BASE_TEST",
      "USB PHY testbench topology",
      UVM_LOW
    )

    uvm_top.print_topology();

  endfunction

  // Run phase
  task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    `uvm_info(
      "BASE_TEST",
      "USB PHY base test started",
      UVM_LOW
    )

    // No stimulus in base test.
    // Derived tests will start sequences.

    phase.drop_objection(this);

  endtask

  // Report phase
  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info(
      "BASE_TEST",
      "USB PHY base test completed",
      UVM_LOW
    )

  endfunction

endclass

