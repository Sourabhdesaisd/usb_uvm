// Run: make run TEST=usb_phy_slave_rx_test USB_SPEED=1 (FS)
//      make run TEST=usb_phy_slave_rx_test USB_SPEED=0 (LS)
class usb_phy_slave_rx_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_slave_rx_test)

  function new(string name = "usb_phy_slave_rx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    byte unsigned payload[$];
    phase.raise_objection(this);
    wait (env_cfg.phy_cfg.vif.rst_n === 1'b1);

    if (env_cfg.speed == HS)
      `uvm_fatal("SLAVE_TEST", "Supplied CDR has no HS RX path; use LS or FS")
    if (env.usb_ag == null || env.usb_ag.sequencer == null)
      `uvm_fatal("SLAVE_TEST", "Active external USB bus agent is required")
    if (env.scoreboard == null)
      `uvm_fatal("SLAVE_TEST", "RX scoreboard is required")

    env.scoreboard.require_expected_rx = 1;
    // Leave a stable idle J before the device begins its SYNC.
    repeat (env_cfg.usb_bfm_cfg.default_bit_time_cycles * 8)
      @(posedge env_cfg.phy_cfg.vif.clk);

    payload.push_back(8'h2d);
    payload.push_back(8'hff); // Exercises mandatory bit stuffing.
    payload.push_back(8'ha5);
    env.usb_ag.send_packet(payload);

    // Driver completion is at the pad EOP. RX byte tags arrive later.
    for (int t = 0; t < 10_000 && env.scoreboard.rx_eop_count == 0; t++)
      @(posedge env_cfg.phy_cfg.vif.clk);
    if (env.scoreboard.rx_eop_count == 0)
      `uvm_error("SLAVE_TEST", "No completed RX packet after slave drive")
    repeat (5) @(posedge env_cfg.phy_cfg.vif.clk);
    phase.drop_objection(this);
  endtask
endclass
