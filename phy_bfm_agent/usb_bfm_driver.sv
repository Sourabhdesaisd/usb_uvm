
class usb_bfm_driver extends uvm_driver #(usb_bfm_transaction);

  `uvm_component_utils(usb_bfm_driver)

  // --------------------------------------------------
  // Configuration and virtual interfaces
  // --------------------------------------------------

  usb_bfm_agent_config cfg;

  virtual usb_bus_if bus_vif;
  virtual usb_phy_if #(8) phy_vif;
  uvm_analysis_port #(usb_bfm_transaction) expected_rx_port;
  bit packet_in_progress;
  int unsigned peer_symbols_checked;
  int unsigned peer_packets_sent;
  int unsigned peer_line_errors;


  // --------------------------------------------------
  // Constructor
  // --------------------------------------------------

  function new(
    string name = "usb_bfm_driver",
    uvm_component parent = null
  );

    super.new(name, parent);
    expected_rx_port = new("expected_rx_port", this);
    packet_in_progress = 0;

  endfunction


  // --------------------------------------------------
  // Build phase
  // --------------------------------------------------

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(usb_bfm_agent_config)::get(
          this,
          "",
          "cfg",
          cfg
        )) begin

      `uvm_fatal(
        "USB_BFM_DRV",
        "usb_bfm_agent_config not found in config_db"
      )

    end

    if (cfg == null) begin

      `uvm_fatal(
        "USB_BFM_DRV",
        "USB BFM configuration is NULL"
      )

    end

    cfg.check_config();

    bus_vif = cfg.bus_vif;
    phy_vif = cfg.phy_vif;

  endfunction


  // --------------------------------------------------
  // Run phase
  // --------------------------------------------------

  task run_phase(uvm_phase phase);

    usb_bfm_transaction tr;

    initialize_outputs();

    wait_for_reset_release();

    `uvm_info(
      "USB_BFM_DRV",
      "USB BFM driver started",
      UVM_LOW
    )

    forever begin

      seq_item_port.get_next_item(tr);

      if (tr == null) begin

        `uvm_fatal(
          "USB_BFM_DRV",
          "Received NULL USB BFM transaction"
        )

      end

      `uvm_info(
        "USB_BFM_DRV",
        $sformatf(
          "Driving transaction: %s",
          tr.convert2string()
        ),
        UVM_MEDIUM
      )

      drive_transaction(tr);

      seq_item_port.item_done();

    end

  endtask


  // --------------------------------------------------
  // Initialize driver outputs
  // --------------------------------------------------

  task initialize_outputs();

    // External BFM does not drive the shared bus
    bus_vif.device_dp = 1'b1;
    bus_vif.device_dm = 1'b0;
    bus_vif.device_oe = 1'b0;

    // Disable analog input path during initialization
    phy_vif.analog_enable_req = 1'b0;

    // Default phy_bfm input level
    phy_vif.analog_phy_bfm = 1'b1;

  endtask


  // --------------------------------------------------
  // Wait for reset release
  // --------------------------------------------------

  task wait_for_reset_release();

    while (bus_vif.rst_n !== 1'b1) begin

      @(bus_vif.cb_drv);

    end

    // Allow one clock after reset release
    @(bus_vif.cb_drv);
    phy_vif.cb_bfm_drv.analog_enable_req <= 1'b1;

  endtask


  // --------------------------------------------------
  // Drive one low-level bus segment
  // --------------------------------------------------

  task drive_transaction(usb_bfm_transaction tr);

    int unsigned cycle_count;
    usb_bfm_transaction copy_tr;

    // ----------------------------------------------
    // Validate transaction speed
    // ----------------------------------------------

    if (!(tr.speed inside {LS, FS, HS})) begin

      `uvm_error(
        "USB_BFM_DRV",
        $sformatf(
          "Unsupported USB speed: %0d",
          tr.speed
        )
      )

      return;

    end


    // Speed must remain consistent with the
    // configured operating speed of the PHY.
    if (tr.speed != cfg.speed) begin

      `uvm_error(
        "USB_BFM_DRV",
        $sformatf(
          "Transaction speed %0d does not match configured speed %0d",
          tr.speed,
          cfg.speed
        )
      )

      return;

    end


    // ----------------------------------------------
    // Validate duration
    // ----------------------------------------------

    if (tr.duration_cycles == 0) begin

      `uvm_error(
        "USB_BFM_DRV",
        "Transaction duration cannot be zero"
      )

      return;

    end


    // ----------------------------------------------
    // Check reset before driving
    // ----------------------------------------------

    if (bus_vif.rst_n !== 1'b1) begin

      `uvm_warning(
        "USB_BFM_DRV",
        "Reset asserted before transaction started"
      )

      wait_for_reset_release();

    end


    // ----------------------------------------------
    // Start driving at a clocking event
    // ----------------------------------------------

    @(bus_vif.cb_drv);

    if (tr.packet_start) begin
      if (packet_in_progress)
        `uvm_fatal("USB_BFM_DRV", "New packet started before prior EOP")
      packet_in_progress = 1;
      if (tr.expected_rx_bytes.size() != 0) begin
        copy_tr = usb_bfm_transaction::type_id::create("copy_tr");
        copy_tr.copy(tr);
        expected_rx_port.write(copy_tr);
      end
    end else if (!packet_in_progress && tr.packet_end) begin
      `uvm_fatal("USB_BFM_DRV", "EOP item without packet start")
    end

    // Keep PHY speed consistent with BFM speed
    phy_vif.usb_speed = cfg.speed;


    // ----------------------------------------------
    // Drive DP/DM
    // ----------------------------------------------

    bus_vif.cb_drv.device_dp <= tr.dp;
    bus_vif.cb_drv.device_dm <= tr.dm;
    bus_vif.cb_drv.device_oe <= tr.drive_enable;


    // ----------------------------------------------
    // Drive CDR input controls
    // ----------------------------------------------

    // CDR must remain enabled across every symbol, EOP and idle.
    phy_vif.cb_bfm_drv.analog_enable_req <= 1'b1;

    // This is a separate CDR input in your RTL.
    // Do not assume it is equivalent to DP or DM.
    // Its relationship to the external line signals
    // must follow the CDR architecture specification.
    phy_vif.cb_bfm_drv.analog_phy_bfm <= tr.analog_phy_bfm;

    // Check the resolved external pins midway through each bit/line segment.
    // This also works for HS, whose entire symbol lasts one system clock.
    @(negedge bus_vif.clk);
    check_peer_symbol(tr);


    // ----------------------------------------------
    // Hold the segment for the requested duration
    // ----------------------------------------------

    // First driven cycle began at the clocking event above.
    for (cycle_count = 1;
         cycle_count < tr.duration_cycles;
         cycle_count++) begin

      @(bus_vif.cb_drv);

      // Abort the segment if reset is asserted
      if (bus_vif.cb_drv.rst_n !== 1'b1) begin

        `uvm_warning(
          "USB_BFM_DRV",
          "Reset asserted during bus segment"
        )

        packet_in_progress = 0;
        release_bus();
        return;

      end

      @(negedge bus_vif.clk);
      check_peer_symbol(tr);

    end


    // ----------------------------------------------
    // End of segment
    // ----------------------------------------------

    if (tr.packet_end) begin
      packet_in_progress = 0;
      peer_packets_sent++;
      `uvm_info("USB_PEER_WIRE",$sformatf(
        "packet id=%0d speed=%s complete; checked_symbols/clocks=%0d line_errors=%0d",
        tr.transaction_id,tr.speed.name(),peer_symbols_checked,peer_line_errors),UVM_LOW)
      release_bus();
    end else if (!packet_in_progress) begin
      release_bus(); // Legacy standalone segment.
    end


    // ----------------------------------------------
    // Optional idle interval
    // ----------------------------------------------

    for (cycle_count = 0;
         cycle_count < tr.idle_cycles;
         cycle_count++) begin

      @(bus_vif.cb_drv);

      if (bus_vif.cb_drv.rst_n !== 1'b1) begin

        wait_for_reset_release();

      end

    end


    `uvm_info(
      "USB_BFM_DRV",
      $sformatf(
        "Transaction completed: ID=%0d duration=%0d",
        tr.transaction_id,
        tr.duration_cycles
      ),
      UVM_MEDIUM
    )

  endtask

  task check_peer_symbol(usb_bfm_transaction tr);
    if (bus_vif.rst_n !== 1'b1 || !tr.drive_enable) return;
    peer_symbols_checked++;
    if (bus_vif.bus_dp !== tr.dp || bus_vif.bus_dm !== tr.dm ||
        bus_vif.bus_contention !== 1'b0) begin
      peer_line_errors++;
      `uvm_error("USB_PEER_WIRE",$sformatf(
        "peer line mismatch packet=%0d speed=%s expected {DP,DM}=%b%b actual=%b%b contention=%b",
        tr.transaction_id,tr.speed.name(),tr.dp,tr.dm,
        bus_vif.bus_dp,bus_vif.bus_dm,bus_vif.bus_contention))
    end
  endtask


  // --------------------------------------------------
  // Release external bus and analog input enable
  // --------------------------------------------------

  task release_bus();

    @(bus_vif.cb_drv);

    bus_vif.cb_drv.device_oe <= 1'b0;
    // Passive termination restores J. Keep the CDR enabled between packets.
    phy_vif.cb_bfm_drv.analog_phy_bfm <= 1'b1;

  endtask


  // --------------------------------------------------
  // Report phase
  // --------------------------------------------------

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info(
      "USB_BFM_DRV",
      "USB BFM driver report phase completed",
      UVM_LOW
    )
    `uvm_info("USB_PEER_WIRE",$sformatf(
      "peer packets=%0d checked symbol clocks=%0d line errors=%0d",
      peer_packets_sent,peer_symbols_checked,peer_line_errors),UVM_NONE)

  endfunction

endclass

