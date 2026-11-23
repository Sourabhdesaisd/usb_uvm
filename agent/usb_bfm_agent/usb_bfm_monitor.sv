
class usb_bfm_monitor extends uvm_monitor;

  `uvm_component_utils(usb_bfm_monitor)

  // --------------------------------------------------
  // Configuration and virtual interfaces
  // --------------------------------------------------

  usb_bfm_agent_config cfg;

  virtual usb_bus_if bus_vif;
  virtual usb_phy_if #(8) phy_vif;


  // --------------------------------------------------
  // Analysis port
  // --------------------------------------------------

  uvm_analysis_port #(usb_bfm_transaction) analysis_port;


  // --------------------------------------------------
  // Statistics
  // --------------------------------------------------

  int unsigned transaction_count;
  int unsigned total_sample_count;
  int unsigned next_transaction_id;


  // --------------------------------------------------
  // Constructor
  // --------------------------------------------------

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

  endfunction


  // --------------------------------------------------
  // Run phase
  // --------------------------------------------------

  task run_phase(uvm_phase phase);

    logic previous_dp;
    logic previous_dm;
    logic previous_oe;
    logic previous_serial;
    logic previous_analog_enable;

    logic current_dp;
    logic current_dm;
    logic current_oe;
    logic current_serial;
    logic current_analog_enable;

    speed_t previous_speed;
    speed_t current_speed;

    int unsigned segment_duration;

    bit first_sample;

    previous_dp            = 1'bx;
    previous_dm            = 1'bx;
    previous_oe            = 1'bx;
    previous_serial        = 1'bx;
    previous_analog_enable = 1'bx;

    previous_speed         = cfg.speed;

    segment_duration = 0;
    first_sample     = 1'b1;

    `uvm_info(
      "USB_BFM_MON",
      "USB BFM monitor started",
      UVM_LOW
    )


    // Wait for reset release
    wait (bus_vif.rst_n === 1'b1);


    forever begin

      // Sample both interfaces at their clocking events.
      // Both interfaces use the same system clock.
      @(bus_vif.cb_mon);
      @(phy_vif.cb_mon);

      total_sample_count++;


      // ------------------------------------------------
      // Reset handling
      // ------------------------------------------------

      if (bus_vif.cb_mon.rst_n !== 1'b1 ||
          phy_vif.cb_mon.rst_n !== 1'b1) begin

        // Publish the last collected segment before
        // clearing the monitor's segment state.
        if (!first_sample && segment_duration != 0) begin

          publish_segment(
            previous_dp,
            previous_dm,
            previous_oe,
            previous_serial,
            previous_analog_enable,
            previous_speed,
            segment_duration
          );

        end

        first_sample     = 1'b1;
        segment_duration = 0;

        continue;

      end


      // ------------------------------------------------
      // Sample shared bus
      // ------------------------------------------------

      current_dp = bus_vif.cb_mon.bus_dp;
      current_dm = bus_vif.cb_mon.bus_dm;

      // External BFM output enable.
      // This does not indicate exclusive bus ownership.
      current_oe = bus_vif.cb_mon.device_oe;


      // ------------------------------------------------
      // Sample CDR-related signals
      // ------------------------------------------------

      current_serial        = phy_vif.cb_mon.analog_serial;
      current_analog_enable = phy_vif.cb_mon.analog_enable;

      current_speed = phy_vif.cb_mon.usb_speed;


      // ------------------------------------------------
      // First sample after reset
      // ------------------------------------------------

      if (first_sample) begin

        previous_dp            = current_dp;
        previous_dm            = current_dm;
        previous_oe            = current_oe;
        previous_serial        = current_serial;
        previous_analog_enable = current_analog_enable;
        previous_speed         = current_speed;

        segment_duration = 1;
        first_sample     = 1'b0;

      end


      // ------------------------------------------------
      // Detect a new segment
      // ------------------------------------------------

      else if (
           (current_dp !== previous_dp)
        || (current_dm !== previous_dm)
        || (current_oe !== previous_oe)
        || (current_serial !== previous_serial)
        || (current_analog_enable !== previous_analog_enable)
        || (current_speed != previous_speed)
      ) begin

        // Publish the previous stable segment
        publish_segment(
          previous_dp,
          previous_dm,
          previous_oe,
          previous_serial,
          previous_analog_enable,
          previous_speed,
          segment_duration
        );


        // Start the next segment
        previous_dp            = current_dp;
        previous_dm            = current_dm;
        previous_oe            = current_oe;
        previous_serial        = current_serial;
        previous_analog_enable = current_analog_enable;
        previous_speed         = current_speed;

        segment_duration = 1;

      end


      // ------------------------------------------------
      // No signal transition
      // ------------------------------------------------

      else begin

        segment_duration++;

      end

    end

  endtask


  // --------------------------------------------------
  // Publish observed segment
  // --------------------------------------------------

  task publish_segment(

    input logic dp_value,
    input logic dm_value,
    input logic oe_value,
    input logic serial_value,
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


    // ------------------------------------------------
    // Copy observed values
    // ------------------------------------------------

    tr.speed = speed_value;

    tr.dp = dp_value;
    tr.dm = dm_value;

    tr.drive_enable = (oe_value === 1'b1);

    tr.analog_serial = serial_value;

    tr.duration_cycles = duration_value;

    tr.idle_cycles = 0;


    // This monitor observes electrical line segments.
    // It does not yet decode USB packet boundaries.
    tr.packet_start = 1'b0;
    tr.packet_end   = 1'b0;


    tr.transaction_id = next_transaction_id++;


    // ------------------------------------------------
    // Publish transaction
    // ------------------------------------------------

    analysis_port.write(tr);

    transaction_count++;


    `uvm_info(
      "USB_BFM_MON",
      $sformatf(
        "Observed segment: ID=%0d SPEED=%0d DP=%b DM=%b EXT_OE=%b SERIAL=%b ANALOG_EN=%b DURATION=%0d",
        tr.transaction_id,
        tr.speed,
        tr.dp,
        tr.dm,
        tr.drive_enable,
        tr.analog_serial,
        analog_enable_value,
        tr.duration_cycles
      ),
      UVM_HIGH
    )

  endtask


  // --------------------------------------------------
  // Report phase
  // --------------------------------------------------

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info(
      "USB_BFM_MON",
      "----------------------------------------",
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_MON",
      $sformatf(
        "Total samples       = %0d",
        total_sample_count
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_MON",
      $sformatf(
        "Observed segments   = %0d",
        transaction_count
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_MON",
      "----------------------------------------",
      UVM_LOW
    )

  endfunction

endclass

