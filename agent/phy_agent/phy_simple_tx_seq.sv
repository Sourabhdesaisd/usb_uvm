
class usb_phy_tx_test extends usb_phy_base_test;

  `uvm_component_utils(usb_phy_tx_test)

  // TX sequence handle
  phy_simple_tx_seq tx_seq;

  // Constructor
  function new(
    string name = "usb_phy_tx_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction


  // --------------------------------------------------
  // Build phase
  // --------------------------------------------------

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    `uvm_info(
      "TX_TEST",
      "USB PHY TX test build phase completed",
      UVM_LOW
    )

  endfunction


  // --------------------------------------------------
  // Run phase
  // --------------------------------------------------

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    `uvm_info(
      "TX_TEST",
      "USB PHY TX test started",
      UVM_LOW
    )

    // ----------------------------------------------
    // Check environment
    // ----------------------------------------------

    if (env == null) begin
      `uvm_fatal(
        "TX_TEST",
        "USB PHY environment handle is NULL"
      )
    end

    if (env_cfg == null) begin
      `uvm_fatal(
        "TX_TEST",
        "USB PHY environment configuration is NULL"
      )
    end

    // ----------------------------------------------
    // Check PHY agent
    // ----------------------------------------------

    if (env.phy_ag == null) begin
      `uvm_fatal(
        "TX_TEST",
        "PHY agent is not created"
      )
    end

    if (env.phy_ag.sequencer == null) begin
      `uvm_fatal(
        "TX_TEST",
        "PHY sequencer is not created. Check PHY agent active mode."
      )
    end

    if (env.phy_ag.driver == null) begin
      `uvm_fatal(
        "TX_TEST",
        "PHY driver is not created. Check enable_driver configuration."
      )
    end

    // ----------------------------------------------
    // Create TX sequence
    // ----------------------------------------------

    tx_seq = phy_simple_tx_seq::type_id::create(
      "tx_seq"
    );

    // Use speed configured by the environment.
    tx_seq.packet_speed = env_cfg.speed;

    `uvm_info(
      "TX_TEST",
      $sformatf(
        "Starting TX sequence at USB speed = %0d",
        env_cfg.speed
      ),
      UVM_LOW
    )

    // ----------------------------------------------
    // Start sequence on PHY sequencer
    // ----------------------------------------------

    tx_seq.start(env.phy_ag.sequencer);

    `uvm_info(
      "TX_TEST",
      "PHY TX sequence completed successfully",
      UVM_LOW
    )

    // ----------------------------------------------
    // Complete test
    // ----------------------------------------------

    phase.drop_objection(this);

  endtask


  // --------------------------------------------------
  // Report phase
  // --------------------------------------------------

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info(
      "TX_TEST",
      "USB PHY TX test completed",
      UVM_LOW
    )

  endfunction

endclass

