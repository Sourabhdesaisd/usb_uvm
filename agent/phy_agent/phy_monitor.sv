
class phy_monitor extends uvm_monitor;

  `uvm_component_utils(phy_monitor)

  virtual usb_phy_if vif;
  phy_agent_config cfg;

  uvm_analysis_port #(phy_transaction) ap;

  function new(string name = "phy_monitor",
               uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual usb_phy_if)::get(
          this, "", "vif", vif))
      `uvm_fatal("PHY_MON_VIF", "PHY virtual interface not found")

    if (!uvm_config_db#(phy_agent_config)::get(
          this, "", "cfg", cfg))
      `uvm_fatal("PHY_MON_CFG", "PHY monitor configuration not found")

  endfunction

  task run_phase(uvm_phase phase);

    phy_transaction tr;

    `uvm_info("PHY_MON", "PHY monitor started", UVM_LOW)

    forever begin

      @(vif.cb_mon);

      if (vif.cb_mon.rst_n !== 1'b1)
        continue;

      // ------------------------------------------------
      // SIE -> PHY accepted TX transfer
      // ------------------------------------------------

      if ((vif.cb_mon.sie_valid === 1'b1) &&
          (vif.cb_mon.sie_ready === 1'b1)) begin

        tr = phy_transaction::type_id::create("tr");

        tr.is_sie_transfer = 1'b1;
        tr.is_rx_transfer  = 1'b0;

        tr.rst_n     = vif.cb_mon.rst_n;
        tr.usb_speed = vif.cb_mon.usb_speed;
        tr.sie_ready = vif.cb_mon.sie_ready;

        tr.sie_valid  = vif.cb_mon.sie_valid;
        tr.sie_data   = vif.cb_mon.sie_data;
        tr.sop        = vif.cb_mon.sie_sop;
        tr.eop        = vif.cb_mon.sie_eop;
        tr.sof_packet = vif.cb_mon.sof_packet;

        ap.write(tr);

        `uvm_info("PHY_MON",
          $sformatf(
            "SIE ACCEPTED: DATA=%02h SOP=%0b EOP=%0b SOF=%0b SPEED=%0d",
            tr.sie_data,
            tr.sop,
            tr.eop,
            tr.sof_packet,
            tr.usb_speed
          ),
          UVM_MEDIUM)

      end

      // ------------------------------------------------
      // RX observation logging
      // ------------------------------------------------

      if (vif.cb_mon.RxValid === 1'b1) begin

        `uvm_info("PHY_MON",
          $sformatf(
            "RX DATA=%02h RX_ACTIVE=%0b RX_ERROR=%0b",
            vif.cb_mon.DataOut,
            vif.cb_mon.RxActive,
            vif.cb_mon.RxError
          ),
          UVM_MEDIUM)

      end

      if (vif.cb_mon.RxError === 1'b1 ||
          vif.cb_mon.rx_stuff_err === 1'b1 ||
          vif.cb_mon.rx_align_err === 1'b1 ||
          vif.cb_mon.rx_line_err === 1'b1 ||
          vif.cb_mon.rx_sync_err === 1'b1 ||
          vif.cb_mon.rx_bus_reset === 1'b1) begin

        `uvm_warning("PHY_MON_RX_STATUS",
          "PHY RX error/status flag detected")

      end

    end

  endtask

endclass

