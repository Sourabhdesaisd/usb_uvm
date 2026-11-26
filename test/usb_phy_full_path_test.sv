class usb_directed_tx_seq extends uvm_sequence #(phy_transaction);
  `uvm_object_utils(usb_directed_tx_seq)
  byte unsigned bytes[$];
  speed_t packet_speed;
  bit is_sof;
  function new(string name="usb_directed_tx_seq"); super.new(name); endfunction
  virtual task body();
    phy_transaction req;
    if (bytes.size()==0) `uvm_fatal("TX_SEQ","Empty directed packet")
    foreach (bytes[i]) begin
      req = phy_transaction::type_id::create($sformatf("tx_%0d",i));
      start_item(req);
      req.speed = packet_speed;
      req.data = bytes[i];
      req.valid = 1;
      req.sop = i==0;
      req.eop = i==bytes.size()-1;
      req.sof_packet = is_sof;
      req.delay_cycles = 0;
      req.valid_gap_cycles = 0;
      finish_item(req);
    end
  endtask
endclass


// HS peer exercise at the implemented PHY boundary. The supplied CDR parks
// at HS, so this test checks DUT TX bytes/wire and peer generated line slots,
// direction and EOP, without expecting RxValid for peer-generated packets.
class usb_phy_hs_peer_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_hs_peer_test)
  function new(string name="usb_phy_hs_peer_test", uvm_component parent=null);
    super.new(name,parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    usb_directed_tx_seq host_tx;
    byte unsigned payload[$];
    int unsigned prior_tx;
    int unsigned prior_peer;
    phase.raise_objection(this);
    wait (env_cfg.phy_cfg.vif.rst_n === 1'b1);
    if (env_cfg.speed != HS)
      `uvm_fatal("HS_PEER","Run with USB_SPEED=2")
    if (env.usb_ag.sequencer == null || env.phy_ag.sequencer == null)
      `uvm_fatal("HS_PEER","Both active agents are required")

    prior_tx=env.tx_wire_checker.packets_checked;
    prior_peer=env.usb_ag.driver.peer_packets_sent;
    host_tx=usb_directed_tx_seq::type_id::create("host_tx");
    host_tx.packet_speed=HS;
    host_tx.bytes.push_back(8'h2d);
    host_tx.bytes.push_back(8'hff);
    payload.push_back(8'hd2);
    fork
      env.usb_ag.respond_after_tx(payload); // 16-bit opposite-direction gap.
      host_tx.start(env.phy_ag.sequencer);
    join
    repeat (3) @(posedge env_cfg.phy_cfg.vif.clk);
    if (env.tx_wire_checker.packets_checked != prior_tx+1)
      `uvm_error("HS_PEER","DUT HS TX was not decoded/checked")

    // Normal HS packet, stuffed payload and forty-bit SOF EOP. The peer
    // models SIE-provided bytes; PID and CRC are outside this PHY test.
    payload.delete(); payload.push_back(8'hff);
    payload.push_back(8'hff); payload.push_back(8'h7e);
    env.usb_ag.send_hs_line_packet(payload);
    payload.delete(); payload.push_back(8'ha5);
    env.usb_ag.send_hs_line_packet(payload,1);

    // Deliberately malformed HS physical traffic: line error, bit-stuff
    // violation and invalid SYNC. The HS-disabled DUT RX cannot report them.
    payload.delete(); payload.push_back(8'hff);
    payload.push_back(8'hff);
    env.usb_ag.send_fault_packet(payload,1);
    env.usb_ag.send_fault_packet(payload,2);
    env.usb_ag.send_fault_packet(payload,3);
    if (env.usb_ag.driver.peer_packets_sent != prior_peer+6)
      `uvm_error("HS_PEER",$sformatf(
        "Expected six peer packets, got %0d",
        env.usb_ag.driver.peer_packets_sent-prior_peer))
    if (env.usb_ag.driver.peer_symbols_checked==0 ||
        env.usb_ag.driver.peer_line_errors!=0 ||
        env.scoreboard.bus_contention_count!=0)
      `uvm_error("HS_PEER","Peer line check or bus ownership failed")
    phase.drop_objection(this);
  endtask
endclass

// Directed physical-layer regression. Run separately at USB_SPEED=0,1,2.
// In this test HS checks DUT TX; usb_phy_hs_peer_test below also exercises
// peer-generated HS pins. The supplied CDR intentionally disables HS RX.
class usb_phy_full_path_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_full_path_test)
  function new(string name="usb_phy_full_path_test", uvm_component parent=null);
    super.new(name,parent);
  endfunction

  task send_tx(input byte unsigned bytes[$], input bit sof=0);
    usb_directed_tx_seq seq;
    seq = usb_directed_tx_seq::type_id::create("directed_tx");
    seq.packet_speed = env_cfg.speed;
    seq.is_sof = sof;
    foreach (bytes[i]) seq.bytes.push_back(bytes[i]);
    seq.start(env.phy_ag.sequencer);
  endtask

  task send_rx(input byte unsigned bytes[$], int unsigned se0_len=2);
    env.usb_ag.send_packet(bytes,se0_len);
  endtask

  virtual task run_phase(uvm_phase phase);
    byte unsigned pkt[$];
    int before_count;
    usb_slave_reset_seq reset_seq;
    phase.raise_objection(this);
    wait (env_cfg.phy_cfg.vif.rst_n === 1'b1);
    if (env.tx_wire_checker == null || env.scoreboard == null)
      `uvm_fatal("FULL_PATH","Scoreboard and TX wire checker required")
    if (env.phy_ag.sequencer == null || env.usb_ag.sequencer == null)
      `uvm_fatal("FULL_PATH","Both active agents required")

    // One-byte, multiple-byte, stuffing at a boundary, consecutive packets.
    pkt.push_back(8'h00);
    send_tx(pkt);
    pkt.delete(); pkt.push_back(8'hff); pkt.push_back(8'hff);
    pkt.push_back(8'h7e); pkt.push_back(8'h80);
    send_tx(pkt);
    pkt.delete();
    repeat (20) pkt.push_back(8'hff); // Exceeds the 16-byte FIFO depth.
    send_tx(pkt);
    if (env_cfg.speed == HS) begin
      pkt.delete(); pkt.push_back(8'h2d); pkt.push_back(8'h00);
      send_tx(pkt,1); // 40-symbol SOF EOP.
    end
    repeat (3) @(posedge env_cfg.phy_cfg.vif.clk);
    if (env.tx_wire_checker.packets_checked != (env_cfg.speed == HS ? 4 : 3))
      `uvm_error("FULL_PATH","Missing checked TX pad packet")

    if (env_cfg.speed != HS) begin
      env.scoreboard.require_expected_rx = 1;
      // Let the analog CDR reacquire idle J after DUT transmission.
      repeat (env_cfg.usb_bfm_cfg.default_bit_time_cycles*10)
        @(posedge env_cfg.phy_cfg.vif.clk);
      pkt.delete(); pkt.push_back(8'h2d); pkt.push_back(8'hff);
      pkt.push_back(8'ha5);
      for (int se0=1; se0<=3; se0++) begin
        before_count = env.scoreboard.rx_eop_count;
        send_rx(pkt,se0);
        for (int t=0; t<6000 && env.scoreboard.rx_eop_count==before_count; t++)
          @(posedge env_cfg.phy_cfg.vif.clk);
        if (env.scoreboard.rx_eop_count==before_count)
          `uvm_error("FULL_PATH",$sformatf("Missing RX packet with %0d SE0 EOP bits",se0))
        repeat (env_cfg.usb_bfm_cfg.default_bit_time_cycles*12)
          @(posedge env_cfg.phy_cfg.vif.clk);
      end
      reset_seq = usb_slave_reset_seq::type_id::create("reset_seq");
      reset_seq.reset_speed = env_cfg.speed;
      reset_seq.start(env.usb_ag.sequencer);
      if (env.scoreboard.rx_bus_reset_count == 0)
        `uvm_error("FULL_PATH","LS/FS bus reset status was not observed")
    end
    repeat (5) @(posedge env_cfg.phy_cfg.vif.clk);
    phase.drop_objection(this);
  endtask
endclass
