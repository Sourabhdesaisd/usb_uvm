// Coverage is sampled from observed PHY outputs and accepted SIE inputs.
class usb_phy_coverage extends uvm_component;
  `uvm_component_utils(usb_phy_coverage)
  virtual usb_phy_if #(8) vif;
  int tx_len, rx_len;
  covergroup cg_tx with function sample(speed_t speed, int length,
                                        bit sof, bit stuffing_pattern);
    option.per_instance = 1;
    cp_speed: coverpoint speed { bins ls={LS}; bins fs={FS}; bins hs={HS}; }
    cp_len: coverpoint length { bins one={1}; bins short_pkt={[2:4]}; bins long_pkt={[5:$]}; }
    cp_sof: coverpoint sof { bins normal={0}; bins sof={1}; }
    cp_stuff: coverpoint stuffing_pattern { bins no={0}; bins yes={1}; }
    speed_length: cross cp_speed,cp_len;
  endgroup
  covergroup cg_rx with function sample(speed_t speed, int length,
                                        bit rx_error, bit stuff, bit align,
                                        bit line_error, bit bus_reset);
    option.per_instance = 1;
    cp_speed: coverpoint speed { bins ls={LS}; bins fs={FS}; }
    cp_len: coverpoint length { bins empty={0}; bins one={1}; bins multiple={[2:$]}; }
    cp_error: coverpoint rx_error { bins clean={0}; bins error={1}; }
    cp_stuff: coverpoint stuff { bins no={0}; bins yes={1}; }
    cp_align: coverpoint align { bins no={0}; bins yes={1}; }
    cp_line: coverpoint line_error { bins no={0}; bins yes={1}; }
    cp_reset: coverpoint bus_reset { bins no={0}; bins yes={1}; }
    speed_error: cross cp_speed,cp_error;
  endgroup
  covergroup cg_status with function sample(speed_t speed, bit stuff,
                               bit align, bit line_error, bit sync,
                               bit bus_reset);
    option.per_instance=1;
    cp_speed: coverpoint speed {bins ls={LS};bins fs={FS};bins hs={HS};}
    cp_status: coverpoint {stuff,align,line_error,sync,bus_reset} {
      bins stuff_error={5'b10000};
      bins align_error={5'b01000};
      bins line_error={5'b00100};
      bins sync_error={5'b00010};
      bins bus_reset={5'b00001};
      bins combinations=default;
    }
  endgroup

  function new(string name="usb_phy_coverage",uvm_component parent=null);
    super.new(name,parent); cg_tx=new(); cg_rx=new(); cg_status=new();
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb_phy_if #(8))::get(this,"","vif",vif))
      `uvm_fatal("USB_COV","Missing usb_phy_if")
  endfunction
  task run_phase(uvm_phase phase);
    bit tx_sof, tx_stuff_pattern;
    bit rx_error_seen, stuff_seen, align_seen, line_seen, reset_seen;
    bit rx_active_prev;
    bit [4:0] old_flags,new_flags;
    forever begin
      @(vif.cb_mon);
      if (vif.cb_mon.rst_n !== 1'b1) begin
        tx_len=0;rx_len=0;rx_active_prev=0;
        tx_sof=0;tx_stuff_pattern=0;
        rx_error_seen=0;stuff_seen=0;align_seen=0;line_seen=0;reset_seen=0;
        old_flags='0;
        continue;
      end
      if (vif.cb_mon.sie_valid && vif.cb_mon.sie_ready) begin
        if (vif.cb_mon.sie_sop) begin
          tx_len=0;tx_sof=vif.cb_mon.sof_packet;tx_stuff_pattern=0;
        end
        tx_len++;
        if (vif.cb_mon.sie_data == 8'hff) tx_stuff_pattern=1;
        if (vif.cb_mon.sie_eop)
          cg_tx.sample(vif.cb_mon.usb_speed,tx_len,tx_sof,tx_stuff_pattern);
      end
      if (vif.cb_mon.RxActive && !rx_active_prev) begin
        rx_len=0;
        rx_error_seen=0;stuff_seen=0;align_seen=0;line_seen=0;reset_seen=0;
      end
      if (vif.cb_mon.RxActive) begin
        if (vif.cb_mon.RxValid) rx_len++;
        rx_error_seen |= vif.cb_mon.RxError;
        stuff_seen |= vif.cb_mon.rx_stuff_err;
        align_seen |= vif.cb_mon.rx_align_err;
        line_seen |= vif.cb_mon.rx_line_err;
        reset_seen |= vif.cb_mon.rx_bus_reset;
      end
      new_flags={vif.cb_mon.rx_stuff_err,vif.cb_mon.rx_align_err,
                 vif.cb_mon.rx_line_err,vif.cb_mon.rx_sync_err,
                 vif.cb_mon.rx_bus_reset};
      if ((new_flags & ~old_flags) != 5'b0)
        cg_status.sample(vif.cb_mon.usb_speed,new_flags[4],new_flags[3],
                         new_flags[2],new_flags[1],new_flags[0]);
      old_flags=new_flags;
      if (!vif.cb_mon.RxActive && rx_active_prev && vif.cb_mon.usb_speed != HS)
        cg_rx.sample(vif.cb_mon.usb_speed,rx_len,rx_error_seen,stuff_seen,
                     align_seen,line_seen,reset_seen);
      rx_active_prev=vif.cb_mon.RxActive;
    end
  endtask
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("USB_COV",$sformatf("TX=%0.1f%% RX=%0.1f%% STATUS=%0.1f%%",
              cg_tx.get_inst_coverage(),cg_rx.get_inst_coverage(),
              cg_status.get_inst_coverage()),UVM_NONE)
  endfunction
endclass
