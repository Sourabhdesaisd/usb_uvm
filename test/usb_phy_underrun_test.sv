// The SIE stops after a SOP byte without asserting sie_eop. PISO must close
// at that byte boundary and the following properly tagged packet must work.
class usb_underrun_tx_seq extends uvm_sequence #(phy_transaction);
  `uvm_object_utils(usb_underrun_tx_seq)
  speed_t packet_speed;
  function new(string name="usb_underrun_tx_seq");super.new(name);endfunction
  virtual task body();
    phy_transaction req;
    req=phy_transaction::type_id::create("underrun_byte");
    start_item(req);
    req.speed=packet_speed;
    req.data=8'hff;
    req.valid=1;
    req.sop=1;
    req.eop=0;
    req.sof_packet=0;
    req.delay_cycles=0;
    req.valid_gap_cycles=0;
    finish_item(req);
  endtask
endclass

class usb_phy_underrun_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_underrun_test)
  function new(string name="usb_phy_underrun_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction
  virtual task run_phase(uvm_phase phase);
    usb_underrun_tx_seq incomplete;
    usb_directed_tx_seq recovered;
    virtual usb_phy_if #(8) vif;
    phase.raise_objection(this);
    vif=env_cfg.phy_cfg.vif;
    wait(vif.rst_n===1'b1);
    env.tx_wire_checker.allow_underrun=1;
    env.scoreboard.allow_underrun=1;
    incomplete=usb_underrun_tx_seq::type_id::create("incomplete");
    incomplete.packet_speed=env_cfg.speed;
    incomplete.start(env.phy_ag.sequencer);
    for(int t=0;t<100000 && env.tx_wire_checker.underrun_packets_checked==0;t++)
      @(posedge vif.clk);
    if(env.tx_wire_checker.underrun_packets_checked!=1)
      `uvm_error("UNDERRUN","Missing clean end of unterminated TX packet")
    recovered=usb_directed_tx_seq::type_id::create("recovered");
    recovered.packet_speed=env_cfg.speed;
    recovered.bytes.push_back(8'h55);
    recovered.start(env.phy_ag.sequencer);
    repeat(5) @(posedge vif.clk);
    if(env.tx_wire_checker.packets_checked!=2 ||
       env.scoreboard.tx_underrun_packets!=1)
      `uvm_error("UNDERRUN","Packet recovery or decoded-byte check failed")
    phase.drop_objection(this);
  endtask
endclass
