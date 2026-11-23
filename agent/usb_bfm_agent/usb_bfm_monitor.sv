
class usb_bfm_monitor extends uvm_monitor;

  `uvm_component_utils(usb_bfm_monitor)

  usb_bfm_agent_config cfg;

  virtual usb_bus_if bus_vif;
  virtual usb_phy_if #(8) phy_vif;

  uvm_analysis_port #(usb_bfm_transaction) analysis_port;

  int unsigned transaction_count;
  int unsigned total_sample_count;
  int unsigned next_transaction_id;

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

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(usb_bfm_agent_config)::get(
          this, "", "cfg", cfg
        )) begin
      `uvm_fatal("USB_BFM_MON",
                 "usb_bfm_agent_config not found")
    end

    if (cfg == null ||
        cfg.bus_vif == null ||
        cfg.phy_vif == null) begin
      `uvm_fatal("USB_BFM_MON",
                 "USB BFM virtual interface is NULL")
    end

    bus_vif = cfg.bus_vif;
    phy_vif = cfg.phy_vif;
  endfunction

  task run_phase(uvm_phase phase);

    logic previous_dp;
    logic previous_dm;
    logic previous_oe;

    logic current_dp;
    logic current_dm;
    logic current_oe;

    speed_t current_speed;

    int unsigned segment_duration;
    bit first_sample;

    previous_dp = 1'bx;
    previous_dm = 1'bx;
    previous_oe = 1'bx;

    segment_duration = 0;
    first_sample = 1'b1;

    wait (bus_vif.rst_n === 1'b1);

    forever begin

      @(bus_vif.cb_mon);

      if (bus_vif.rst_n !== 1'b1) begin
        first_sample = 1'b1;
        segment_duration = 0;
        continue;
      end

      current_dp = bus_vif.cb_mon.bus_dp;
      current_dm = bus_vif.cb_mon.bus_dm;

      // This is the external device's OE, not the PHY's OE.
      // It is recorded only as a separate observation.
      current_oe = bus_vif.device_oe;

      current_speed = phy_vif.usb_speed;

      total_sample_count++;

      if (first_sample) begin

        previous_dp = current_dp;
        previous_dm = current_dm;
        previous_oe = current_oe;

        segment_duration = 1;
        first_sample = 1'b0;

      end
      else if ((current_dp !== previous_dp) ||
               (current_dm !== previous_dm) ||
               (current_oe !== previous_oe)) begin

        publish_segment(
          previous_dp,
          previous_dm,
          previous_oe,
          current_speed,
          segment_duration
        );

        previous_dp = current_dp;
        previous_dm = current_dm;
        previous_oe = current_oe;

        segment_duration = 1;

      end
      else begin

        segment_duration++;

      end

    end

  endtask

  task publish_segment(
    input logic dp_value,
    input logic dm_value,
    input logic oe_value,
    input speed_t speed_value,
    input int unsigned duration_value
  );

    usb_bfm_transaction tr;

    tr = usb_bfm_transaction::type_id::create(
      "usb_bfm_observed_tr"
    );

    tr.speed           = speed_value;
    tr.dp              = dp_value;
    tr.dm              = dm_value;
    tr.drive_enable    = (oe_value === 1'b1);
    tr.analog_serial   = phy_vif.analog_serial;
    tr.duration_cycles = duration_value;
    tr.idle_cycles     = 0;

    // This monitor does not decode USB packet boundaries.
    tr.packet_start = 1'b0;
    tr.packet_end   = 1'b0;

    tr.transaction_id = next_transaction_id++;

    analysis_port.write(tr);
    transaction_count++;

    `uvm_info("USB_BFM_MON",
              tr.convert2string(),
              UVM_HIGH)

  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("USB_BFM_MON",
      $sformatf(
        "Total samples=%0d, observed line segments=%0d",
        total_sample_count,
        transaction_count
      ),
      UVM_LOW)
  endfunction

endclass

