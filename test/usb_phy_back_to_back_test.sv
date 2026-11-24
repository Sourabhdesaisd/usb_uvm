// Two consecutive packets in each direction, with only the legal bus gap.
class usb_phy_back_to_back_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_back_to_back_test)
  function new(string name="usb_phy_back_to_back_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction
  virtual task run_phase(uvm_phase phase);
    usb_directed_tx_seq tx;
    byte unsigned rx_payload[$];
    phase.raise_objection(this);
    wait(env_cfg.phy_cfg.vif.rst_n===1'b1);
    for(int n=0;n<2;n++) begin
      tx=usb_directed_tx_seq::type_id::create("tx_back_to_back");
      tx.packet_speed=env_cfg.speed;
      tx.bytes.push_back(n==0 ? 8'h00 : 8'hff);
      tx.bytes.push_back(8'ha5);
      tx.start(env.phy_ag.sequencer);
    end
    if (env_cfg.speed!=HS) begin
      env.scoreboard.require_expected_rx=1;
      repeat(env_cfg.usb_bfm_cfg.default_bit_time_cycles*10)
        @(posedge env_cfg.phy_cfg.vif.clk);
      for(int n=0;n<2;n++) begin
        rx_payload.delete();
        rx_payload.push_back(n==0 ? 8'h2d : 8'hc3);
        rx_payload.push_back(8'hff);
        env.usb_ag.send_packet(rx_payload);
        repeat(env_cfg.usb_bfm_cfg.default_bit_time_cycles*3)
          @(posedge env_cfg.phy_cfg.vif.clk);
      end
      for(int t=0;t<2000 && env.scoreboard.rx_eop_count!=2;t++)
        @(posedge env_cfg.phy_cfg.vif.clk);
      if (env.scoreboard.rx_eop_count!=2)
        `uvm_error("BACK_TO_BACK","Expected two completed RX packets")
    end
    repeat(5) @(posedge env_cfg.phy_cfg.vif.clk);
    if(env.tx_wire_checker.packets_checked!=2)
      `uvm_error("BACK_TO_BACK","Expected two checked TX packets")
    phase.drop_objection(this);
  endtask
endclass
