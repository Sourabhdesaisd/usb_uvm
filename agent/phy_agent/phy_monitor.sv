

class phy_monitor extends uvm_monitor;

  `uvm_component_utils(phy_monitor)

       
  // Virtual interface and configuration
       

  virtual usb_phy_if vif;

  phy_agent_config cfg;

       
  // Analysis port
       

  uvm_analysis_port #(phy_transaction) ap;

       
  // Constructor
       

  function new(string name = "phy_monitor",
               uvm_component parent = null);

    super.new(name, parent);

    ap = new("ap", this);

  endfunction


       
  // Build phase
       

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(virtual usb_phy_if)::get(
          this, "", "vif", vif)) begin

      `uvm_fatal("PHY_MON_VIF",
                 "PHY monitor virtual interface not found")

    end

    if (vif == null) begin

      `uvm_fatal("PHY_MON_VIF_NULL",
                 "PHY monitor virtual interface is NULL")

    end

    if (!uvm_config_db#(phy_agent_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("PHY_MON_CFG",
                 "PHY monitor configuration not found")

    end

    if (cfg == null) begin

      `uvm_fatal("PHY_MON_CFG_NULL",
                 "PHY monitor configuration is NULL")

    end

    `uvm_info("PHY_MON",
              "PHY monitor build completed",
              UVM_LOW)

  endfunction


       
  // Main monitor process
       

  task run_phase(uvm_phase phase);

    phy_transaction tx_tr;

    `uvm_info("PHY_MON",
              "PHY monitor started",
              UVM_LOW)

    forever begin

      @(vif.cb_mon);

           
      // Ignore activity during reset
           

      if (vif.cb_mon.rst_n !== 1'b1) begin

        continue;

      end

           
      // Monitor SIE TX handshake
      //
      // A transfer is accepted when:
      // sie_valid = 1
      // sie_ready = 1
           

      if ((vif.cb_mon.sie_valid === 1'b1) &&
          (vif.cb_mon.sie_ready === 1'b1)) begin

        tx_tr = phy_transaction::type_id::create(
                  "tx_tr", this);

        // Capture accepted SIE transaction
        tx_tr.sie_data   = vif.cb_mon.sie_data;
        tx_tr.sie_valid  = vif.cb_mon.sie_valid;
        tx_tr.sop        = vif.cb_mon.sie_sop;
        tx_tr.eop        = vif.cb_mon.sie_eop;
        tx_tr.sof_packet = vif.cb_mon.sof_packet;

        // Publish observed transaction
        ap.write(tx_tr);

        `uvm_info("PHY_MON",
                  $sformatf(
                    "SIE TX accepted: DATA=0x%02h SOP=%0b EOP=%0b SOF=%0b SPEED=%0d",
                    vif.cb_mon.sie_data,
                    vif.cb_mon.sie_sop,
                    vif.cb_mon.sie_eop,
                    vif.cb_mon.sof_packet,
                    vif.cb_mon.usb_speed),
                  UVM_MEDIUM)

      end

           
      // Monitor physical TX outputs
           

      if (vif.cb_mon.tx_valid === 1'b1) begin

        `uvm_info("PHY_MON",
                  $sformatf(
                    "PHY TX activity: DP=%0b DM=%0b TX_VALID=%0b",
                    vif.cb_mon.dp,
                    vif.cb_mon.dm,
                    vif.cb_mon.tx_valid),
                  UVM_HIGH)

      end

           
      // Monitor DUT RX outputs
           

      if (vif.cb_mon.RxValid === 1'b1) begin

        `uvm_info("PHY_MON",
                  $sformatf(
                    "PHY RX data: DATA=0x%02h RX_VALID=%0b RX_ACTIVE=%0b RX_ERROR=%0b LINE_STATE=%0b",
                    vif.cb_mon.DataOut,
                    vif.cb_mon.RxValid,
                    vif.cb_mon.RxActive,
                    vif.cb_mon.RxError,
                    vif.cb_mon.LineState),
                  UVM_MEDIUM)

      end

           
      // Monitor RX packet markers
           

      if (vif.cb_mon.rx_sop === 1'b1) begin

        `uvm_info("PHY_MON",
                  "RX packet start detected",
                  UVM_MEDIUM)

      end

      if (vif.cb_mon.rx_eop === 1'b1) begin

        `uvm_info("PHY_MON",
                  "RX packet end detected",
                  UVM_MEDIUM)

      end

           
      // Monitor RX error and status signals
           

      if ((vif.cb_mon.RxError      === 1'b1) ||
          (vif.cb_mon.rx_stuff_err === 1'b1) ||
          (vif.cb_mon.rx_align_err === 1'b1) ||
          (vif.cb_mon.rx_line_err  === 1'b1) ||
          (vif.cb_mon.rx_babble_err === 1'b1) ||
          (vif.cb_mon.rx_sync_err  === 1'b1) ||
          (vif.cb_mon.rx_bus_reset === 1'b1)) begin

        `uvm_warning("PHY_MON",
                     $sformatf(
                       "RX STATUS: RxError=%0b StuffErr=%0b AlignErr=%0b LineErr=%0b BabbleErr=%0b SyncErr=%0b BusReset=%0b",
                       vif.cb_mon.RxError,
                       vif.cb_mon.rx_stuff_err,
                       vif.cb_mon.rx_align_err,
                       vif.cb_mon.rx_line_err,
                       vif.cb_mon.rx_babble_err,
                       vif.cb_mon.rx_sync_err,
                       vif.cb_mon.rx_bus_reset))

      end

    end

  endtask


       
  // Report phase
       

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("PHY_MON_REPORT",
              "PHY monitor simulation completed",
              UVM_LOW)

  endfunction

endclass

