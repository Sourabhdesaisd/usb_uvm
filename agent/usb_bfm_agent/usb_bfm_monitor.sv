
class usb_bfm_monitor extends uvm_monitor;

  `uvm_component_utils(usb_bfm_monitor)

  // Virtual interface
  virtual usb_bus_if vif;

  // USB BFM configuration
  usb_bfm_config cfg;

  // Analysis port
  uvm_analysis_port #(usb_bfm_transaction) analysis_port;

  // Transaction handle
  usb_bfm_transaction tr;


  // ------------------------------------------------
  // Constructor
  // ------------------------------------------------
  function new(string name = "usb_bfm_monitor",
               uvm_component parent = null);

    super.new(name, parent);

    analysis_port = new("analysis_port", this);

  endfunction


  // ------------------------------------------------
  // Build phase
  // ------------------------------------------------
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(virtual usb_bus_if)::get(
          this, "", "vif", vif)) begin

      `uvm_fatal("USB_MON_VIF",
                 "USB bus virtual interface not found")

    end

    if (!uvm_config_db#(usb_bfm_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("USB_MON_CFG",
                 "USB BFM configuration not found")

    end

    if (cfg.speed == USB_SPEED_RESERVED) begin

      `uvm_fatal("USB_MON_SPEED",
                 "Reserved USB speed selected")

    end

    `uvm_info("USB_MON",
              $sformatf("USB BFM Monitor configured for speed %0d",
                        cfg.speed),
              UVM_LOW)

  endfunction


  // ------------------------------------------------
  // Convert observed DP/DM into USB line state
  // ------------------------------------------------
  function usb_line_state_e decode_line_state(
    input logic dp,
    input logic dm
  );

    if ((dp === 1'b0) && (dm === 1'b0))
      return USB_LINE_SE0;

    else if ((dp === 1'b1) && (dm === 1'b1))
      return USB_LINE_SE1;

    else if (cfg.speed == USB_SPEED_LS) begin

      if ((dp === 1'b0) && (dm === 1'b1))
        return USB_LINE_J;

      else if ((dp === 1'b1) && (dm === 1'b0))
        return USB_LINE_K;

    end

    else begin

      if ((dp === 1'b1) && (dm === 1'b0))
        return USB_LINE_J;

      else if ((dp === 1'b0) && (dm === 1'b1))
        return USB_LINE_K;

    end

    return USB_LINE_SE1;

  endfunction


  // ------------------------------------------------
  // Check unknown values
  // ------------------------------------------------
  function bit check_bus_signals();

    if ((vif.cb_mon.device_dp !== 1'b0 &&
         vif.cb_mon.device_dp !== 1'b1) ||

        (vif.cb_mon.device_dm !== 1'b0 &&
         vif.cb_mon.device_dm !== 1'b1) ||

        (vif.cb_mon.device_oe !== 1'b0 &&
         vif.cb_mon.device_oe !== 1'b1) ||

        (vif.cb_mon.phy_tx_valid !== 1'b0 &&
         vif.cb_mon.phy_tx_valid !== 1'b1) ||

        (^vif.cb_mon.phy_line_state === 1'bx)) begin

      return 0;

    end

    return 1;

  endfunction


  // ------------------------------------------------
  // Main monitor process
  // ------------------------------------------------
  task run_phase(uvm_phase phase);

    forever begin

      @(vif.cb_mon);

      // Ignore observations during reset
      if (vif.cb_mon.rst_n !== 1'b1)
        continue;

      // Check for X/Z values
      if (!check_bus_signals()) begin

        `uvm_error("USB_MON_X",
                   "Unknown value detected on USB bus signals")

        continue;

      end

      // Create observation transaction
      tr = usb_bfm_transaction::type_id::create(
        "tr", this);

      // External device observations
      tr.device_dp = vif.cb_mon.device_dp;
      tr.device_dm = vif.cb_mon.device_dm;
      tr.device_oe = vif.cb_mon.device_oe;

      // PHY TX observations
      tr.phy_line_state = vif.cb_mon.phy_line_state;
      tr.phy_tx_valid   = vif.cb_mon.phy_tx_valid;

      // Event indicators
      tr.is_device_drive =
          (vif.cb_mon.device_oe === 1'b1);

      tr.is_phy_tx =
          (vif.cb_mon.phy_tx_valid === 1'b1);

      // Decode external device line state
      tr.line_state = decode_line_state(
        vif.cb_mon.device_dp,
        vif.cb_mon.device_dm
      );

      // Publish only meaningful bus activity
      if (tr.is_device_drive || tr.is_phy_tx) begin

        analysis_port.write(tr);

        `uvm_info("USB_MON",
                  $sformatf(
                    "Speed=%0d Device_OE=%0b DP=%0b DM=%0b Device_State=%0d PHY_TX=%0b PHY_State=%0b",
                    cfg.speed,
                    tr.device_oe,
                    tr.device_dp,
                    tr.device_dm,
                    tr.line_state,
                    tr.phy_tx_valid,
                    tr.phy_line_state),
                  UVM_MEDIUM)

      end

      // Monitor bit timing events
      if (vif.cb_mon.bit_tick === 1'b1) begin

        `uvm_info("USB_MON",
                  "USB bit interval observed",
                  UVM_HIGH)

      end
      else if (vif.cb_mon.bit_tick !== 1'b0) begin

        `uvm_error("USB_MON_TICK",
                   "Unknown value detected on bit_tick")

      end

    end

  endtask


  // ------------------------------------------------
  // Report phase
  // ------------------------------------------------
  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("USB_MON_REPORT",
              "USB BFM monitor simulation completed",
              UVM_LOW)

  endfunction

endclass

