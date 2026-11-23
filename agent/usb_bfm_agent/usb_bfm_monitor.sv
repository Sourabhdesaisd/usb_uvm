
class usb_bfm_monitor extends uvm_monitor;

  `uvm_component_utils(usb_bfm_monitor)

             
  // Virtual interface and configuration
             

  virtual usb_bus_if vif;
  usb_bfm_config cfg;

  // Analysis port: publishes observed USB bus transactions
  uvm_analysis_port #(usb_bfm_transaction) ap;

  // Symbol counters for debug
  int unsigned phy_tx_symbol_count;
  int unsigned device_symbol_count;

             
  // Constructor
             

  function new(string name = "usb_bfm_monitor",
               uvm_component parent = null);
    super.new(name, parent);

    ap = new("ap", this);

    phy_tx_symbol_count = 0;
    device_symbol_count = 0;
  endfunction


             
  // Build phase
             

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual usb_bus_if)::get(
          this, "", "vif", vif)) begin
      `uvm_fatal("BFM_MON",
                 "usb_bus_if virtual interface not found")
    end

    if (!uvm_config_db#(usb_bfm_config)::get(
          this, "", "cfg", cfg)) begin
      `uvm_fatal("BFM_MON",
                 "usb_bfm_config not found")
    end
  endfunction


             
  // Decode USB line state
  //
  // USB_LINE_J:
  //   LS : DP=0, DM=1
  //   FS/HS : DP=1, DM=0
  //
  // USB_LINE_K:
  //   LS : DP=1, DM=0
  //   FS/HS : DP=0, DM=1
  //
  // SE0 = 00
  // SE1 = 11
             

  function automatic usb_line_state_e decode_line_state(
      input logic dp,
      input logic dm
  );

    if ((dp === 1'b0) && (dm === 1'b0)) begin
      return USB_LINE_SE0;
    end

    if ((dp === 1'b1) && (dm === 1'b1)) begin
      return USB_LINE_SE1;
    end

    case (cfg.speed)

      USB_SPEED_LS: begin
        if ((dp === 1'b0) && (dm === 1'b1))
          return USB_LINE_J;
        else
          return USB_LINE_K;
      end

      USB_SPEED_FS,
      USB_SPEED_HS: begin
        if ((dp === 1'b1) && (dm === 1'b0))
          return USB_LINE_J;
        else
          return USB_LINE_K;
      end

      default: begin
        return USB_LINE_SE1;
      end

    endcase

  endfunction


             
  // Check for unknown values
             

  task automatic check_bus_signals();

    if ((vif.phy_dp !== 1'b0) &&
        (vif.phy_dp !== 1'b1)) begin

      `uvm_error("BFM_MON",
                 "Unknown value detected on PHY DP")
    end

    if ((vif.phy_dm !== 1'b0) &&
        (vif.phy_dm !== 1'b1)) begin

      `uvm_error("BFM_MON",
                 "Unknown value detected on PHY DM")
    end

    if ((vif.device_dp !== 1'b0) &&
        (vif.device_dp !== 1'b1)) begin

      `uvm_error("BFM_MON",
                 "Unknown value detected on device DP")
    end

    if ((vif.device_dm !== 1'b0) &&
        (vif.device_dm !== 1'b1)) begin

      `uvm_error("BFM_MON",
                 "Unknown value detected on device DM")
    end

    if ((vif.bus_dp === 1'bx) ||
        (vif.bus_dp === 1'bz) ||
        (vif.bus_dm === 1'bx) ||
        (vif.bus_dm === 1'bz)) begin

      `uvm_warning("BFM_MON",
                   "Resolved USB bus contains X or Z")
    end

  endtask


             
  // Monitor DUT TX output
  //
  // Capture only one symbol when:
  //   bit_tick     = 1
  //   phy_tx_valid = 1
  //
  // The DUT TX line state is sampled after the positive edge
  // sequential logic has settled.
             

  task automatic monitor_phy_tx();

    usb_bfm_transaction tr;

    if ((vif.bit_tick === 1'b1) &&
        (vif.phy_tx_valid === 1'b1)) begin

      tr = usb_bfm_transaction::type_id::create(
             "phy_tx_tr", this);

      tr.is_phy_tx       = 1'b1;
      tr.is_device_drive = 1'b0;

      tr.phy_tx_valid = vif.phy_tx_valid;

      tr.phy_line_state = {vif.phy_dp, vif.phy_dm};

      tr.line_state = decode_line_state(
                        vif.phy_dp,
                        vif.phy_dm
                      );

      tr.bit_count = 1;

      tr.device_dp = 1'b0;
      tr.device_dm = 1'b0;
      tr.device_oe = 1'b0;

      phy_tx_symbol_count++;

      `uvm_info("BFM_PHY_TX",
        $sformatf(
          "TX Symbol[%0d]: Speed=%0d DP=%b DM=%b LineState=%s",
          phy_tx_symbol_count,
          cfg.speed,
          vif.phy_dp,
          vif.phy_dm,
          tr.line_state.name()
        ),
        UVM_HIGH
      )

      ap.write(tr);

    end

  endtask


             
  // Monitor external USB device drive
  //
  // This path observes the external USB partner connected
  // through device_dp/device_dm/device_oe.
             

  task automatic monitor_device_drive();

    usb_bfm_transaction tr;

    if (vif.device_oe === 1'b1) begin

      tr = usb_bfm_transaction::type_id::create(
             "device_tr", this);

      tr.is_device_drive = 1'b1;
      tr.is_phy_tx       = 1'b0;

      tr.device_dp = vif.device_dp;
      tr.device_dm = vif.device_dm;
      tr.device_oe = vif.device_oe;

      tr.line_state = decode_line_state(
                        vif.device_dp,
                        vif.device_dm
                      );

      tr.phy_tx_valid = 1'b0;
      tr.phy_line_state = 2'b00;

      tr.bit_count = 1;

      device_symbol_count++;

      `uvm_info("BFM_DEVICE",
        $sformatf(
          "Device Symbol[%0d]: Speed=%0d DP=%b DM=%b LineState=%s",
          device_symbol_count,
          cfg.speed,
          vif.device_dp,
          vif.device_dm,
          tr.line_state.name()
        ),
        UVM_HIGH
      )

      ap.write(tr);

    end

  endtask


             
  // Run phase
             

  task run_phase(uvm_phase phase);

    super.run_phase(phase);

    `uvm_info("BFM_MON",
      "USB BFM monitor started",
      UVM_LOW
    )

    forever begin

      // Sample after the DUT's positive-edge sequential logic
      // has settled. bit_tick is a full-cycle pulse.
      @(negedge vif.clk);

      if (vif.rst_n !== 1'b1) begin
        phy_tx_symbol_count = 0;
        device_symbol_count = 0;
        continue;
      end

      // Check signal integrity on each active bit interval.
      if (vif.bit_tick === 1'b1) begin

        check_bus_signals();

        // Independent monitoring paths
        monitor_phy_tx();
        monitor_device_drive();

        // Both the external device and DUT are driving.
        if ((vif.device_oe === 1'b1) &&
            (vif.phy_tx_valid === 1'b1)) begin

          `uvm_error("USB_CONTENTION",
            $sformatf(
              "Both device and PHY are driving USB bus. Device DP/DM=%b%b, PHY DP/DM=%b%b",
              vif.device_dp,
              vif.device_dm,
              vif.phy_dp,
              vif.phy_dm
            )
          )

        end

      end

    end

  endtask


             
  // Report phase
             

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("BFM_MON_REPORT",
      $sformatf(
        "Total PHY TX symbols observed = %0d, Total device symbols observed = %0d",
        phy_tx_symbol_count,
        device_symbol_count
      ),
      UVM_LOW
    )

  endfunction

endclass

