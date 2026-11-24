// USB_FAULT: 1=SE1, 2=missing stuffed zero, 3=long SE0, 4=broken SYNC.
class usb_phy_fault_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_fault_test)
  function new(string name="usb_phy_fault_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction
  virtual task run_phase(uvm_phase phase);
    usb_slave_packet_seq packet;
    byte unsigned recovery[$];
    int before_recovery;
    int mode;
    phase.raise_objection(this);
    wait (env_cfg.phy_cfg.vif.rst_n === 1'b1);
    if (env_cfg.speed == HS)
      `uvm_fatal("FAULT","HS receive is absent from supplied CDR")
    if (!$value$plusargs("USB_FAULT=%d",mode)) mode=1;
    if (!(mode inside {1,2,3,4}))
      `uvm_fatal("FAULT","USB_FAULT must be 1, 2, 3 or 4")
    env.scoreboard.expect_rx_error=(mode==1 || mode==2);
    env.scoreboard.expect_line_err=(mode==1);
    env.scoreboard.expect_stuff_err=(mode==2);
    env.scoreboard.expect_sync_err=(mode==4);
    repeat (env_cfg.usb_bfm_cfg.default_bit_time_cycles*10)
      @(posedge env_cfg.phy_cfg.vif.clk);
    packet=usb_slave_packet_seq::type_id::create("malformed_packet");
    packet.packet_speed=env_cfg.speed;
    packet.score_packet=0; // Payload may be discarded on an abort.
    packet.payload.push_back(8'hff);
    packet.payload.push_back(8'hff);
    packet.payload.push_back(8'h2d);
    packet.inject_se1=(mode==1);
    packet.omit_stuffed_zero=(mode==2);
    packet.eop_se0_bits=(mode==3) ? 4 : 2;
    packet.break_sync=(mode==4);
    packet.start(env.usb_ag.sequencer);
    for (int t=0;t<env_cfg.usb_bfm_cfg.default_bit_time_cycles*40;t++) begin
      if ((mode==1 && env.scoreboard.rx_line_error_count!=0) ||
          (mode==2 && env.scoreboard.rx_stuff_error_count!=0) ||
          (mode==3 && env.scoreboard.rx_eop_count!=0) ||
          (mode==4 && env.scoreboard.rx_sync_error_count!=0)) break;
      @(posedge env_cfg.phy_cfg.vif.clk);
    end
    if (mode==1 && env.scoreboard.rx_line_error_count==0)
      `uvm_error("FAULT","SE1 did not raise rx_line_err")
    if (mode==2 && env.scoreboard.rx_stuff_error_count==0)
      `uvm_error("FAULT","Missing stuffed zero did not raise rx_stuff_err")
    if (mode==3 && (env.scoreboard.rx_eop_count==0 ||
                    env.scoreboard.rx_line_error_count!=0))
      `uvm_error("FAULT","Long SE0 must abort/close without a line error")
    if (mode==4 && env.scoreboard.rx_sync_error_count==0)
      `uvm_error("FAULT","Broken SYNC did not raise rx_sync_err")
    if (mode==1) begin
      // SE1 leaves a tail to drain. A fresh idle interval must rearm SYNC.
      repeat (env_cfg.usb_bfm_cfg.default_bit_time_cycles*12)
        @(posedge env_cfg.phy_cfg.vif.clk);
      env.scoreboard.require_expected_rx=1;
      before_recovery=env.scoreboard.rx_eop_count;
      recovery.push_back(8'h2d);
      recovery.push_back(8'h00);
      env.usb_ag.send_packet(recovery);
      for(int t=0;t<env_cfg.usb_bfm_cfg.default_bit_time_cycles*15 &&
                       env.scoreboard.rx_eop_count==before_recovery;t++)
        @(posedge env_cfg.phy_cfg.vif.clk);
      if(env.scoreboard.rx_eop_count==before_recovery)
        `uvm_error("FAULT","Receiver did not rearm after SE1/drain")
    end
    repeat (env_cfg.usb_bfm_cfg.default_bit_time_cycles*8)
      @(posedge env_cfg.phy_cfg.vif.clk);
    phase.drop_objection(this);
  endtask
endclass
