// RESET_CASE=0: initialization; 1: reset during TX; 2: reset during RX.
// RX case uses the real LS/FS CDR; HS RX has no implementation in this RTL.
class usb_phy_reset_test extends usb_phy_base_test;
  `uvm_component_utils(usb_phy_reset_test)
  virtual usb_phy_if #(8) vif;
  virtual usb_bus_if bus_vif;
  function new(string name="usb_phy_reset_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction

  task pulse_reset();
    @(negedge vif.clk);
    vif.rst_n=0;
    repeat (10) @(negedge vif.clk);
    if (vif.tx_valid!==1'b0 || vif.RxActive!==1'b0 ||
        vif.RxValid!==1'b0 || vif.RxError!==1'b0 ||
        vif.rx_bus_reset!==1'b0)
      `uvm_error("RESET","TX/RX valid or status remained asserted during reset")
    vif.rst_n=1;
    repeat (4) @(posedge vif.clk);
  endtask

  task drive_line(bit p,bit m,bit phy_bfm_level,int clocks);
    @(negedge vif.clk);
    bus_vif.device_oe=1;
    bus_vif.device_dp=p;
    bus_vif.device_dm=m;
    vif.analog_phy_bfm=phy_bfm_level;
    repeat (clocks) @(negedge vif.clk);
  endtask

  task interrupt_rx();
    bit jp,jm;
    int period;
    int waited;
    byte unsigned recovery[$];
    if (env_cfg.speed==HS)
      `uvm_fatal("RESET_RX","The supplied CDR does not implement HS receive")
    period=env_cfg.usb_bfm_cfg.default_bit_time_cycles;
    jp=(env_cfg.speed!=LS);jm=!jp;
    repeat (period*10) @(negedge vif.clk);
    // FS/LS SYNC K,J,K,J,K,J,K,K, using analog_phy_bfm=1 on J.
    for (int i=0;i<8;i++) begin
      bit k;
      k=(i%2)==0 || i==7;
      drive_line(k ? !jp : jp, k ? !jm : jm, !k, period);
    end
    // Continue K symbols until RX becomes active, then interrupt the packet.
    waited=0;
    while (vif.RxActive!==1'b1 && waited<period*8) begin
      drive_line(!jp,!jm,0,period);
      waited+=period;
    end
    if (vif.RxActive!==1'b1)
      `uvm_error("RESET_RX","Packet did not become active before reset")
    pulse_reset();
    @(negedge vif.clk);
    bus_vif.device_oe=0;
    vif.analog_phy_bfm=1;
    repeat (period*12) @(posedge vif.clk);
    env.scoreboard.require_expected_rx=1;
    recovery.push_back(8'h2d);
    recovery.push_back(8'h00);
    env.usb_ag.send_packet(recovery);
    for (int t=0;t<period*12 && env.scoreboard.rx_eop_count==0;t++)
      @(posedge vif.clk);
    if (env.scoreboard.rx_eop_count==0)
      `uvm_error("RESET_RX","No recovered RX packet after reset")
  endtask

  task interrupt_tx();
    usb_directed_tx_seq interrupted;
    usb_directed_tx_seq recovered;
    interrupted=usb_directed_tx_seq::type_id::create("interrupted");
    interrupted.packet_speed=env_cfg.speed;
    interrupted.bytes.push_back(8'hff);
    fork
      interrupted.start(env.phy_ag.sequencer);
      begin
        wait (vif.tx_valid===1'b1);
        repeat (2) @(negedge vif.clk);
        pulse_reset();
      end
    join
    recovered=usb_directed_tx_seq::type_id::create("recovered");
    recovered.packet_speed=env_cfg.speed;
    recovered.bytes.push_back(8'h55);
    recovered.start(env.phy_ag.sequencer);
    repeat (4) @(posedge vif.clk);
    if (env.tx_wire_checker.packets_checked!=1)
      `uvm_error("RESET_TX","No good TX packet following interrupted TX")
  endtask

  virtual task run_phase(uvm_phase phase);
    int which_case;
    phase.raise_objection(this);
    vif=env_cfg.phy_cfg.vif;
    bus_vif=env_cfg.usb_bfm_cfg.bus_vif;
    if (!$value$plusargs("RESET_CASE=%d",which_case)) which_case=0;
    wait (vif.rst_n===1'b1);
    case (which_case)
      0: pulse_reset();
      1: interrupt_tx();
      2: interrupt_rx();
      default: `uvm_fatal("RESET","RESET_CASE must be 0, 1, or 2")
    endcase
    phase.drop_objection(this);
  endtask
endclass
