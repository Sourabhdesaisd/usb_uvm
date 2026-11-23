

class usb_phy_tx_test extends usb_phy_base_test;

  `uvm_component_utils(usb_phy_tx_test)

  phy_simple_tx_seq tx_seq;

  function new(
    string name = "usb_phy_tx_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction


  virtual task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    `uvm_info(
      "TX_TEST",
      "USB PHY TX test started",
      UVM_LOW
    )

    if (env == null)
      `uvm_fatal("TX_TEST", "Environment handle is NULL")

    if (env_cfg == null)
      `uvm_fatal("TX_TEST", "Environment configuration is NULL")

    if (!env_cfg.enable_phy_agent)
      `uvm_fatal("TX_TEST", "PHY agent is disabled in env_cfg")

    if (env.phy_ag == null)
      `uvm_fatal("TX_TEST", "PHY agent was not created")

    if (env.phy_ag.sequencer == null)
      `uvm_fatal("TX_TEST", "PHY sequencer was not created")

    if (env.phy_ag.driver == null)
      `uvm_fatal("TX_TEST", "PHY driver was not created")

    tx_seq = phy_simple_tx_seq::type_id::create("tx_seq");

    tx_seq.packet_speed = env_cfg.speed;

    `uvm_info(
      "TX_TEST",
      $sformatf("Starting TX sequence at speed=%0d", env_cfg.speed),
      UVM_LOW
    )

    tx_seq.start(env.phy_ag.sequencer);

    `uvm_info(
      "TX_TEST",
      "PHY TX sequence returned",
      UVM_LOW
    )

    // Allow the final registered TX activity to settle before
    // ending the test. Tune this drain time after checking the
    // actual DUT TX timing and driver handshake.
    repeat (10) @(posedge env_cfg.phy_cfg.vif.clk);

    phase.drop_objection(this);

  endtask


  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info(
      "TX_TEST",
      "USB PHY TX test report phase completed",
      UVM_LOW
    )
  endfunction

endclass

