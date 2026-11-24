// A transmitted DUT packet followed by an external USB device response.
// Run at USB_SPEED=0 (LS) or USB_SPEED=1 (FS); HS RX is not implemented.
class usb_phy_slave_turnaround_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_slave_turnaround_test)

  function new(string name = "usb_phy_slave_turnaround_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phy_simple_tx_seq tx_seq;
    byte unsigned response_bytes[$];
    phase.raise_objection(this);
    wait (env_cfg.phy_cfg.vif.rst_n === 1'b1);
    if (env_cfg.speed == HS)
      `uvm_fatal("TURNAROUND", "HS RX is out of scope")
    if (env.phy_ag.sequencer == null || env.usb_ag.sequencer == null)
      `uvm_fatal("TURNAROUND", "Both active agents are required")
    env.scoreboard.require_expected_rx = 1;

    tx_seq = phy_simple_tx_seq::type_id::create("tx_seq");
    tx_seq.packet_speed = env_cfg.speed;
    response_bytes.push_back(8'hd2); // Example SIE handshake byte.
    fork
      env.usb_ag.respond_after_tx(response_bytes);
      tx_seq.start(env.phy_ag.sequencer);
    join
    for (int t = 0; t < 10_000 && env.scoreboard.rx_eop_count == 0; t++)
      @(posedge env_cfg.phy_cfg.vif.clk);
    if (env.scoreboard.rx_eop_count == 0)
      `uvm_error("TURNAROUND", "Slave response not received")
    phase.drop_objection(this);
  endtask
endclass
