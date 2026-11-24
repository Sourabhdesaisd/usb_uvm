// Speed selection may change only after the previous TX packet has released
// the bus. This test deliberately sends one packet at each implemented TX rate.
class usb_phy_speed_switch_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_speed_switch_test)
  function new(string name="usb_phy_speed_switch_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction
  task send_at_speed(speed_t next_speed);
    usb_directed_tx_seq packet;
    virtual usb_phy_if #(8) vif;
    vif=env_cfg.phy_cfg.vif;
    if (vif.tx_valid || vif.RxActive || env_cfg.usb_bfm_cfg.bus_vif.device_oe)
      `uvm_fatal("SPEED_SWITCH","Speed changed while line or RX was active")
    @(negedge vif.clk);
    env_cfg.set_speed(next_speed);
    vif.usb_speed=next_speed;
    repeat (8) @(posedge vif.clk);
    packet=usb_directed_tx_seq::type_id::create("speed_packet");
    packet.packet_speed=next_speed;
    packet.bytes.push_back(8'h00);
    packet.bytes.push_back(8'hff);
    packet.bytes.push_back(8'h81);
    packet.start(env.phy_ag.sequencer);
    repeat (3) @(posedge vif.clk);
  endtask
  virtual task run_phase(uvm_phase phase);
    usb_directed_tx_seq reserved_packet;
    phase.raise_objection(this);
    wait (env_cfg.phy_cfg.vif.rst_n===1'b1);
    send_at_speed(LS);
    send_at_speed(FS);
    send_at_speed(HS);
    send_at_speed(LS);
    // Top maps the reserved speed encoding to FS on all three paths.
    @(negedge env_cfg.phy_cfg.vif.clk);
    env_cfg.set_speed(FS);
    env_cfg.phy_cfg.vif.usb_speed=speed_t'(2'b11);
    repeat (8) @(posedge env_cfg.phy_cfg.vif.clk);
    reserved_packet=usb_directed_tx_seq::type_id::create("reserved_speed");
    reserved_packet.packet_speed=FS;
    reserved_packet.bytes.push_back(8'h2d);
    reserved_packet.start(env.phy_ag.sequencer);
    repeat (3) @(posedge env_cfg.phy_cfg.vif.clk);
    if (env.tx_wire_checker.packets_checked!=5)
      `uvm_error("SPEED_SWITCH","Expected five fully checked packets")
    phase.drop_objection(this);
  endtask
endclass
