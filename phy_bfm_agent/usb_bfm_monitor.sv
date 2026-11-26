class usb_bfm_monitor extends uvm_monitor;

  `uvm_component_utils(usb_bfm_monitor)


  // ==================================================
  // CONFIGURATION
  // ==================================================

  usb_bfm_agent_config cfg;


  // ==================================================
  // VIRTUAL INTERFACES
  // ==================================================

  virtual usb_bus_if bus_vif;

  virtual usb_phy_if #(8) phy_vif;


  // ==================================================
  // ANALYSIS PORT
  // ==================================================

  uvm_analysis_port #(usb_bfm_transaction) analysis_port;


  // ==================================================
  // STATISTICS
  // ==================================================

  int unsigned transaction_count;
  int unsigned total_sample_count;
  int unsigned next_transaction_id;


  // ==================================================
  // CONSTRUCTOR
  // ==================================================

  function new(
    string name = "usb_bfm_monitor",
    uvm_component parent = null
  );

    super.new(name, parent);

    analysis_port = new("analysis_port", this);

    transaction_count   = 0;
    total_sample_count  = 0;
    next_transaction_id = 0;

  endfunction


  // ==================================================
  // BUILD PHASE
  // ==================================================

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(usb_bfm_agent_config)::get(
          this,
          "",
          "cfg",
          cfg
        )) begin

      `uvm_fatal(
        "USB_BFM_MON",
        "usb_bfm_agent_config not found in config_db"
      )

    end


    if (cfg == null) begin

      `uvm_fatal(
        "USB_BFM_MON",
        "USB BFM configuration is NULL"
      )

    end


    if (cfg.bus_vif == null) begin

      `uvm_fatal(
        "USB_BFM_MON",
        "USB bus virtual interface is NULL"
      )

    end


    if (cfg.phy_vif == null) begin

      `uvm_fatal(
        "USB_BFM_MON",
        "PHY virtual interface is NULL"
      )

    end


    bus_vif = cfg.bus_vif;
    phy_vif = cfg.phy_vif;


    `uvm_info(
      "USB_BFM_MON",
      "USB BFM monitor build completed",
      UVM_LOW
    )

  endfunction


  // ==================================================
  // RUN PHASE
  // ==================================================

  task run_phase(uvm_phase phase);

    // Previous sampled values
    logic previous_dp;
    logic previous_dm;

    logic previous_device_oe;
    logic previous_phy_oe;

    logic previous_phy_bfm;
    logic previous_analog_enable;

    logic previous_contention;

    speed_t previous_speed;


    // Current sampled values
    logic current_dp;
    logic current_dm;

    logic current_device_oe;
    logic current_phy_oe;

    logic current_phy_bfm;
    logic current_analog_enable;

    logic current_contention;

    speed_t current_speed;


    // Segment tracking
    int unsigned segment_duration;

    bit first_sample;


    // ------------------------------------------------
    // Initialize monitor variables
    // ------------------------------------------------

    previous_dp              = 1'bx;
    previous_dm              = 1'bx;

    previous_device_oe       = 1'bx;
    previous_phy_oe          = 1'bx;

    previous_phy_bfm          = 1'bx;
    previous_analog_enable   = 1'bx;

    previous_contention      = 1'bx;

    previous_speed           = cfg.speed;

    segment_duration         = 0;
    first_sample             = 1'b1;


    `uvm_info(
      "USB_BFM_MON",
      "USB BFM monitor started",
      UVM_LOW
    )


    // ------------------------------------------------
    // Wait for reset release
    // ------------------------------------------------

    wait (bus_vif.rst_n === 1'b1);


    // ------------------------------------------------
    // Main sampling loop
    // ------------------------------------------------

    forever begin

      // Both interfaces use the same system clock.
      // One clocking event is sufficient.
      @(bus_vif.cb_mon);

      total_sample_count++;


      // ----------------------------------------------
      // Reset handling
      // ----------------------------------------------

      if (bus_vif.cb_mon.rst_n !== 1'b1) begin

        first_sample     = 1'b1;
        segment_duration = 0;

        continue;

      end


      // ----------------------------------------------
      // Sample resolved bus
      // ----------------------------------------------

      current_dp = bus_vif.cb_mon.bus_dp;
      current_dm = bus_vif.cb_mon.bus_dm;


      // ----------------------------------------------
      // Sample both driver enables
      // ----------------------------------------------

      current_device_oe = bus_vif.cb_mon.device_oe;

      current_phy_oe = bus_vif.cb_mon.phy_tx_valid;


      // ----------------------------------------------
      // Sample contention
      // ----------------------------------------------

      current_contention =
        bus_vif.cb_mon.bus_contention;


      // ----------------------------------------------
      // Sample PHY analog/CDR signals
      // ----------------------------------------------

      current_phy_bfm =
        phy_vif.cb_mon.analog_phy_bfm;

      current_analog_enable =
        phy_vif.cb_mon.analog_enable;


      // ----------------------------------------------
      // Sample USB speed
      // ----------------------------------------------

      current_speed =
        phy_vif.cb_mon.usb_speed;


      // ----------------------------------------------
      // First sample after reset
      // ----------------------------------------------

      if (first_sample) begin

        previous_dp            = current_dp;
        previous_dm            = current_dm;

        previous_device_oe     = current_device_oe;
        previous_phy_oe        = current_phy_oe;

        previous_phy_bfm        = current_phy_bfm;
        previous_analog_enable = current_analog_enable;

        previous_contention    = current_contention;

        previous_speed         = current_speed;

        segment_duration = 1;

        first_sample = 1'b0;

      end


      // ----------------------------------------------
      // Detect a new segment
      // ----------------------------------------------

      else if (

           (current_dp !== previous_dp)

        || (current_dm !== previous_dm)

        || (current_device_oe !== previous_device_oe)

        || (current_phy_oe !== previous_phy_oe)

        || (current_phy_bfm !== previous_phy_bfm)

        || (current_analog_enable !== previous_analog_enable)

        || (current_contention !== previous_contention)

        || (current_speed != previous_speed)

      ) begin

        // Publish the previous stable segment
        publish_segment(
          previous_dp,
          previous_dm,

          previous_device_oe,
          previous_phy_oe,

          previous_contention,

          previous_phy_bfm,
          previous_analog_enable,

          previous_speed,

          segment_duration
        );


        // Save new segment values
        previous_dp            = current_dp;
        previous_dm            = current_dm;

        previous_device_oe     = current_device_oe;
        previous_phy_oe        = current_phy_oe;

        previous_phy_bfm        = current_phy_bfm;
        previous_analog_enable = current_analog_enable;

        previous_contention    = current_contention;

        previous_speed         = current_speed;

        segment_duration = 1;

      end


      // ----------------------------------------------
      // No signal transition
      // ----------------------------------------------

      else begin

        segment_duration++;

      end

    end

  endtask


  // ==================================================
  // PUBLISH OBSERVED SEGMENT
  // ==================================================

  task publish_segment(

    input logic dp_value,
    input logic dm_value,

    input logic device_oe_value,
    input logic phy_oe_value,

    input logic contention_value,

    input logic phy_bfm_value,
    input logic analog_enable_value,

    input speed_t speed_value,

    input int unsigned duration_value

  );

    usb_bfm_transaction tr;


    if (duration_value == 0) begin
      return;
    end


    tr = usb_bfm_transaction::type_id::create(
      "usb_bfm_observed_tr"
    );


    // ----------------------------------------------
    // Observed bus values
    // ----------------------------------------------

    tr.speed = speed_value;

    tr.dp = dp_value;
    tr.dm = dm_value;


    // ----------------------------------------------
    // Driver ownership
    // ----------------------------------------------

    tr.external_drive_enable =
      (device_oe_value === 1'b1);

    tr.phy_drive_enable =
      (phy_oe_value === 1'b1);

    tr.drive_enable =
      tr.external_drive_enable ||
      tr.phy_drive_enable;

    tr.bus_contention =
      (contention_value === 1'b1);


    // ----------------------------------------------
    // Analog/CDR signals
    // ----------------------------------------------

    tr.analog_phy_bfm = phy_bfm_value;
    tr.analog_enable = analog_enable_value;


    // ----------------------------------------------
    // Timing
    // ----------------------------------------------

    tr.duration_cycles = duration_value;
    tr.idle_cycles     = 0;


    // ----------------------------------------------
    // Packet boundaries
    // ----------------------------------------------

    // This monitor observes electrical line segments.
    // It does not decode USB packet boundaries.

    tr.packet_start = 1'b0;
    tr.packet_end   = 1'b0;


    // ----------------------------------------------
    // Transaction ID
    // ----------------------------------------------

    tr.transaction_id = next_transaction_id++;


    // ----------------------------------------------
    // Publish transaction
    // ----------------------------------------------

    analysis_port.write(tr);

    transaction_count++;


    // ----------------------------------------------
    // Debug message
    // ----------------------------------------------

    `uvm_info(
      "USB_BFM_MON",
      tr.convert2string(),
      UVM_HIGH
    )


    // ----------------------------------------------
    // Contention warning
    // ----------------------------------------------

    if (tr.bus_contention) begin

      `uvm_error(
        "USB_BFM_MON",
        $sformatf(
          "Bus contention: DUT and external BFM both enabled. ID=%0d",
          tr.transaction_id
        )
      )

    end

  endtask


  // ==================================================
  // REPORT PHASE
  // ==================================================

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);


    `uvm_info(
      "USB_BFM_MON_REPORT",
      "----------------------------------------",
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_MON_REPORT",
      $sformatf(
        "Total samples       = %0d",
        total_sample_count
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_MON_REPORT",
      $sformatf(
        "Observed segments   = %0d",
        transaction_count
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_MON_REPORT",
      "----------------------------------------",
      UVM_LOW
    )

  endfunction

endclass
