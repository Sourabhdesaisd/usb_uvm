
class phy_monitor extends uvm_monitor;

  `uvm_component_utils(phy_monitor)

  virtual usb_phy_if #(8) vif;
  phy_agent_config cfg;

  uvm_analysis_port #(phy_transaction) analysis_port;
  uvm_analysis_port #(phy_transaction) rx_analysis_port;

  int unsigned tx_handshake_count;
  int unsigned rx_valid_count;
  int unsigned tx_active_cycles;
  int unsigned rx_error_count;

  int unsigned tx_transaction_id;
  int unsigned rx_transaction_id;

  function new(
    string name = "phy_monitor",
    uvm_component parent = null
  );
    super.new(name, parent);

    analysis_port    = new("analysis_port", this);
    rx_analysis_port = new("rx_analysis_port", this);

    tx_handshake_count = 0;
    rx_valid_count     = 0;
    tx_active_cycles   = 0;
    rx_error_count     = 0;

    tx_transaction_id = 0;
    rx_transaction_id = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(phy_agent_config)::get(
          this, "", "cfg", cfg
        )) begin
      `uvm_fatal("PHY_MON", "phy_agent_config not found")
    end

    if (cfg == null || cfg.vif == null) begin
      `uvm_fatal("PHY_MON", "PHY virtual interface is NULL")
    end

    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    fork
      monitor_tx();
      monitor_rx();
    join
  endtask

  task monitor_tx();

    phy_transaction tr;

    forever begin
      @(vif.cb_mon);

      if (vif.cb_mon.rst_n !== 1'b1)
        continue;

      if (vif.cb_mon.tx_valid === 1'b1)
        tx_active_cycles++;

      if ((vif.cb_mon.sie_valid === 1'b1) &&
          (vif.cb_mon.sie_ready === 1'b1)) begin

        tr = phy_transaction::type_id::create("tx_handshake_tr");

        tr.speed           = vif.cb_mon.usb_speed;
        tr.data            = vif.cb_mon.sie_data;
        tr.valid           = vif.cb_mon.sie_valid;
        tr.ready           = vif.cb_mon.sie_ready;
        tr.sop             = vif.cb_mon.sie_sop;
        tr.eop             = vif.cb_mon.sie_eop;
        tr.sof_packet      = vif.cb_mon.sof_packet;
        tr.transaction_id  = tx_transaction_id++;

        tx_handshake_count++;

        `uvm_info("PHY_MON_TX",
                  tr.convert2string(),
                  UVM_HIGH)

        analysis_port.write(tr);
      end
    end

  endtask

  task monitor_rx();

    phy_transaction tr;

    forever begin
      @(vif.cb_mon);

      if (vif.cb_mon.rst_n !== 1'b1)
        continue;

      if (vif.cb_mon.RxValid === 1'b1) begin

        tr = phy_transaction::type_id::create("rx_data_tr");

        tr.speed          = vif.cb_mon.usb_speed;
        tr.data           = vif.cb_mon.DataOut;
        tr.valid          = vif.cb_mon.RxValid;
        tr.ready          = 1'b0;
        tr.sop            = vif.cb_mon.rx_sop;
        tr.eop            = vif.cb_mon.rx_eop;
        tr.sof_packet     = 1'b0;
        tr.transaction_id = rx_transaction_id++;

        tr.rx_error       = vif.cb_mon.RxError;
        tr.rx_stuff_err   = vif.cb_mon.rx_stuff_err;
        tr.rx_align_err   = vif.cb_mon.rx_align_err;
        tr.rx_line_err    = vif.cb_mon.rx_line_err;
        tr.rx_sync_err    = vif.cb_mon.rx_sync_err;
        tr.rx_bus_reset   = vif.cb_mon.rx_bus_reset;

        rx_valid_count++;

        if (tr.rx_error ||
            tr.rx_stuff_err ||
            tr.rx_align_err ||
            tr.rx_line_err ||
            tr.rx_sync_err) begin
          rx_error_count++;
        end

        `uvm_info("PHY_MON_RX",
                  tr.convert2string(),
                  UVM_HIGH)

        rx_analysis_port.write(tr);
      end
    end

  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("PHY_MON_REPORT",
      $sformatf(
        "TX handshakes=%0d TX active cycles=%0d RX valid bytes=%0d RX error bytes=%0d",
        tx_handshake_count,
        tx_active_cycles,
        rx_valid_count,
        rx_error_count
      ),
      UVM_LOW)
  endfunction

endclass

