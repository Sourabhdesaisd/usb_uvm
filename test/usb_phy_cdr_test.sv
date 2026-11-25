// LS/FS nominal RX, +/-1-clk alternating bit jitter, and receiver re-enable.
// This is a directed functional check, not a USB compliance PPM measurement.
class usb_phy_cdr_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_cdr_test)
  function new(string name="usb_phy_cdr_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction
  virtual task run_phase(uvm_phase phase);
    usb_slave_packet_seq packet;
    virtual usb_phy_if #(8) vif;
    int period;
    phase.raise_objection(this);
    vif=env_cfg.phy_cfg.vif;
    wait(vif.rst_n===1'b1);
    if(env_cfg.speed==HS)
      `uvm_fatal("CDR_TEST","HS receiver is not implemented by this CDR")
    period=env_cfg.usb_bfm_cfg.default_bit_time_cycles;
    env.scoreboard.require_expected_rx=1;
    repeat(period*12) @(posedge vif.clk);
    for(int n=0;n<2;n++) begin
      if(n==1) begin
        @(negedge vif.clk);
        vif.analog_enable_req=0;
        repeat(period*3) @(negedge vif.clk);
        vif.analog_enable_req=1;
        repeat(period*12) @(posedge vif.clk);
      end
      packet=usb_slave_packet_seq::type_id::create("cdr_packet");
      packet.packet_speed=env_cfg.speed;
      packet.jitter_cycles=(n==1) ? 1 : 0;
      packet.payload.push_back(8'h2d);
      packet.payload.push_back(8'hff);
      packet.payload.push_back(8'h55);
      packet.start(env.usb_ag.sequencer);
      for(int t=0;t<period*15 && env.scoreboard.rx_eop_count < n+1;t++)
        @(posedge vif.clk);
      if(env.scoreboard.rx_eop_count < n+1)
        `uvm_error("CDR_TEST",$sformatf("CDR missed packet %0d",n))
      repeat(period*10) @(posedge vif.clk);
    end
    phase.drop_objection(this);
  endtask
endclass

