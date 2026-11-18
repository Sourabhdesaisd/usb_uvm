
class usb_bfm_driver extends uvm_driver #(usb_bfm_transaction);

  `uvm_component_utils(usb_bfm_driver)

  // Virtual interface
  virtual usb_bus_if vif;

  // USB BFM configuration
  usb_bfm_config cfg;

  // Maximum system-clock cycles to wait for each bit_tick
  int unsigned bit_tick_timeout;

  // Driver transaction status
  bit transaction_aborted;


  // ------------------------------------------------
  // Constructor
  // ------------------------------------------------
  function new(string name = "usb_bfm_driver",
               uvm_component parent = null);

    super.new(name, parent);

    bit_tick_timeout = 1000;
    transaction_aborted = 0;

  endfunction


  // ------------------------------------------------
  // Build phase
  // ------------------------------------------------
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(virtual usb_bus_if)::get(
          this, "", "vif", vif)) begin

      `uvm_fatal("USB_DRV_VIF",
                 "USB bus virtual interface not found")

    end

    if (!uvm_config_db#(usb_bfm_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("USB_DRV_CFG",
                 "USB BFM configuration not found")

    end

    if (cfg.speed == USB_SPEED_RESERVED) begin

      `uvm_fatal("USB_DRV_SPEED",
                 "Reserved USB speed selected")

    end

    `uvm_info("USB_DRV",
              $sformatf("USB BFM Driver configured for speed %0d",
                        cfg.speed),
              UVM_LOW)

  endfunction


  // ------------------------------------------------
  // Release external USB bus
  // ------------------------------------------------
  task drive_idle();

    vif.cb_drv.device_oe <= 1'b0;
    vif.cb_drv.device_dp <= 1'b0;
    vif.cb_drv.device_dm <= 1'b0;

  endtask


  // ------------------------------------------------
  // Convert USB line state into DP/DM
  // Supports LS, FS and HS
  // ------------------------------------------------
  task drive_line_state(usb_line_state_e state);

    case (state)

      // --------------------------------------------
      // SE0: Same for LS, FS and HS
      // --------------------------------------------
      USB_LINE_SE0: begin

        vif.cb_drv.device_dp <= 1'b0;
        vif.cb_drv.device_dm <= 1'b0;

      end


      // --------------------------------------------
      // SE1: Same digital representation for all speeds
      // --------------------------------------------
      USB_LINE_SE1: begin

        vif.cb_drv.device_dp <= 1'b1;
        vif.cb_drv.device_dm <= 1'b1;

      end


      // --------------------------------------------
      // J state
      // LS: DP=0, DM=1
      // FS: DP=1, DM=0
      // HS: DP=1, DM=0
      // --------------------------------------------
      USB_LINE_J: begin

        case (cfg.speed)

          USB_SPEED_LS: begin

            vif.cb_drv.device_dp <= 1'b0;
            vif.cb_drv.device_dm <= 1'b1;

          end

          USB_SPEED_FS,
          USB_SPEED_HS: begin

            vif.cb_drv.device_dp <= 1'b1;
            vif.cb_drv.device_dm <= 1'b0;

          end

          default: begin

            `uvm_fatal("USB_DRV_SPEED",
                       "Invalid USB speed for J state")

          end

        endcase

      end


      // --------------------------------------------
      // K state
      // LS: DP=1, DM=0
      // FS: DP=0, DM=1
      // HS: DP=0, DM=1
      // --------------------------------------------
      USB_LINE_K: begin

        case (cfg.speed)

          USB_SPEED_LS: begin

            vif.cb_drv.device_dp <= 1'b1;
            vif.cb_drv.device_dm <= 1'b0;

          end

          USB_SPEED_FS,
          USB_SPEED_HS: begin

            vif.cb_drv.device_dp <= 1'b0;
            vif.cb_drv.device_dm <= 1'b1;

          end

          default: begin

            `uvm_fatal("USB_DRV_SPEED",
                       "Invalid USB speed for K state")

          end

        endcase

      end


      // --------------------------------------------
      // Invalid line state
      // --------------------------------------------
      default: begin

        `uvm_fatal("USB_DRV_LINE",
                   "Invalid USB line state")

      end

    endcase

  endtask


  // ------------------------------------------------
  // Wait for reset release
  // ------------------------------------------------
  task wait_for_reset_release();

    while (vif.cb_drv.rst_n !== 1'b1) begin

      @(vif.cb_drv);

    end

  endtask


  // ------------------------------------------------
  // Wait for requested number of bit intervals
  // ------------------------------------------------
  task wait_bit_intervals(
    input  int unsigned requested_bits,
    output bit          success
  );

    int unsigned tick_count;
    int unsigned cycle_count;

    tick_count  = 0;
    cycle_count = 0;
    success     = 1'b1;

    while (tick_count < requested_bits) begin

      @(vif.cb_drv);

      cycle_count++;

      // Check reset
      if (vif.cb_drv.rst_n !== 1'b1) begin

        `uvm_warning("USB_DRV",
                     "Reset asserted during bus transaction")

        success = 1'b0;
        break;

      end

      // Count bit intervals
      if (vif.cb_drv.bit_tick === 1'b1) begin

        tick_count++;

      end
      else if (vif.cb_drv.bit_tick !== 1'b0) begin

        `uvm_error("USB_DRV",
                   "Unknown value detected on bit_tick")

        success = 1'b0;
        break;

      end

      // Timeout protection
      if ((cycle_count >= bit_tick_timeout) &&
          (tick_count < requested_bits)) begin

        `uvm_error("USB_DRV",
                   $sformatf(
                     "bit_tick timeout: received %0d of %0d intervals",
                     tick_count,
                     requested_bits))

        success = 1'b0;
        break;

      end

    end

  endtask


  // ------------------------------------------------
  // Main driver process
  // ------------------------------------------------
  task run_phase(uvm_phase phase);

    usb_bfm_transaction req;

    bit success;

    drive_idle();

    `uvm_info("USB_DRV",
              "USB BFM driver started",
              UVM_LOW)

    forever begin

      // Get next transaction
      seq_item_port.get_next_item(req);

      transaction_aborted = 1'b0;
      success = 1'b0;

      // Wait for reset release
      wait_for_reset_release();

      // Validate transaction
      if (req.bit_count == 0 ||
          req.bit_count > 1024) begin

        `uvm_error("USB_DRV",
                   "Invalid bit_count. Allowed range is 1 to 1024")

        drive_idle();

        seq_item_port.item_done();

        continue;

      end

      // Wait for next clocking event
      @(vif.cb_drv);

      // Check reset again
      if (vif.cb_drv.rst_n !== 1'b1) begin

        transaction_aborted = 1'b1;

        `uvm_warning("USB_DRV",
                     "Reset asserted before bus drive")

        drive_idle();

        seq_item_port.item_done();

        continue;

      end

      // Enable external USB device drive
      vif.cb_drv.device_oe <= 1'b1;

      // Drive requested line state
      drive_line_state(req.line_state);

      `uvm_info("USB_DRV",
                $sformatf(
                  "Speed=%0d LineState=%0d BitCount=%0d",
                  cfg.speed,
                  req.line_state,
                  req.bit_count),
                UVM_MEDIUM)

      // Hold the line state for requested intervals
      wait_bit_intervals(req.bit_count, success);

      // Release bus at next clocking event
      @(vif.cb_drv);

      drive_idle();

      if (success) begin

        `uvm_info("USB_DRV",
                  "USB bus transaction completed successfully",
                  UVM_MEDIUM)

      end
      else begin

        transaction_aborted = 1'b1;

        `uvm_warning("USB_DRV",
                     "USB bus transaction aborted or timed out")

      end

      // Complete sequencer-driver handshake
      seq_item_port.item_done();

    end

  endtask


  // ------------------------------------------------
  // Report phase
  // ------------------------------------------------
  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("USB_DRV_REPORT",
              "USB BFM driver simulation completed",
              UVM_LOW)

  endfunction

endclass

