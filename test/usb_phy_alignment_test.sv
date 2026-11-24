// FS/LS dribble: last whole byte remains valid, partial trailing bits set
// rx_align_err; ALIGN_IN_RXERROR=0 leaves RxError clear by default.
class usb_phy_alignment_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_alignment_test)
  function new(string name="usb_phy_alignment_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction
  virtual task run_phase(uvm_phase phase);
    usb_slave_packet_seq packet;
    int period;
    phase.raise_objection(this);
    wait(env_cfg.phy_cfg.vif.rst_n===1'b1);
    if(env_cfg.speed==HS)
      `uvm_fatal("ALIGN","HS RX absent in supplied CDR RTL")
    period=env_cfg.usb_bfm_cfg.default_bit_time_cycles;
    env.scoreboard.require_expected_rx=1;
    repeat(period*10) @(posedge env_cfg.phy_cfg.vif.clk);
    packet=usb_slave_packet_seq::type_id::create("dribble_packet");
    packet.packet_speed=env_cfg.speed;
    packet.dribble_bits=3;
    packet.payload.push_back(8'h2d);
    packet.payload.push_back(8'h00); // Last bit zero clears stuffing run.
    packet.start(env.usb_ag.sequencer);
    for(int t=0;t<period*15 && env.scoreboard.rx_eop_count==0;t++)
      @(posedge env_cfg.phy_cfg.vif.clk);
    if(env.scoreboard.rx_eop_count!=1 || env.scoreboard.rx_align_error_count==0 ||
       env.scoreboard.rx_error_count!=0)
      `uvm_error("ALIGN","Expected intact packet and alignment status without RxError")
    phase.drop_objection(this);
  endtask
endclass
