

class phy_driver extends uvm_driver #(phy_transaction);

  `uvm_component_utils(phy_driver)

  virtual usb_phy_if vif;

  phy_agent_config cfg;

  int unsigned ready_timeout;

  bit transaction_accepted;


  // ------------------------------------------------
  // Constructor
  // ------------------------------------------------
  function new(string name = "phy_driver",
               uvm_component parent = null);

    super.new(name, parent);

    ready_timeout = 50;
    transaction_accepted = 0;

  endfunction


  // ------------------------------------------------
  // Build phase
  // ------------------------------------------------
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(virtual usb_phy_if)::get(
          this, "", "vif", vif)) begin

      `uvm_fatal("PHY_DRV_VIF",
                 "PHY virtual interface not found")

    end

    if (!uvm_config_db#(phy_agent_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("PHY_DRV_CFG",
                 "PHY agent configuration not found")

    end

    if (cfg.speed == USB_SPEED_RESERVED) begin

      `uvm_fatal("PHY_DRV_SPEED",
                 "Reserved USB speed selected")

    end

    `uvm_info("PHY_DRV",
              $sformatf("PHY driver configured for speed %0d",
                        cfg.speed),
              UVM_LOW)

  endfunction


  // ------------------------------------------------
  // Drive idle values
  // ------------------------------------------------
  task drive_idle();

    vif.cb_drv.sie_valid  <= 1'b0;
    vif.cb_drv.sie_data   <= 8'h00;
    vif.cb_drv.sop        <= 1'b0;
    vif.cb_drv.eop        <= 1'b0;
    vif.cb_drv.sof_packet <= 1'b0;

  endtask


  // ------------------------------------------------
  // Wait for reset release
  // ------------------------------------------------
  task wait_for_reset_release();

    while (vif.rst_n !== 1'b1) begin

      @(vif.cb_drv);

    end

  endtask


  // ------------------------------------------------
  // Main driver process
  // ------------------------------------------------
  task run_phase(uvm_phase phase);

    phy_transaction req;

    int unsigned wait_count;

    bit accepted;
    bit reset_abort;

    // Initialize SIE inputs
    drive_idle();

    `uvm_info("PHY_DRV",
              "PHY driver started",
              UVM_LOW)

    forever begin

      // Get transaction from sequencer
      seq_item_port.get_next_item(req);

      accepted    = 0;
      reset_abort = 0;
      wait_count  = 0;

      transaction_accepted = 0;

      // Wait for reset release
      wait_for_reset_release();

      // Apply runtime speed configuration
      @(vif.cb_drv);

      vif.cb_drv.usb_speed <= cfg.speed;

      // Drive transaction only when valid
      if (req.sie_valid !== 1'b1) begin

        `uvm_error("PHY_DRV",
                   "Invalid transaction: sie_valid must be 1")

        drive_idle();

        seq_item_port.item_done();

        continue;

      end

      vif.cb_drv.sie_data   <= req.sie_data;
      vif.cb_drv.sie_valid  <= req.sie_valid;
      vif.cb_drv.sop        <= req.sop;
      vif.cb_drv.eop        <= req.eop;
      vif.cb_drv.sof_packet <= req.sof_packet;

      `uvm_info("PHY_DRV",
                $sformatf(
                  "Driving SIE data=0x%02h SOP=%0b EOP=%0b SOF=%0b Speed=%0d",
                  req.sie_data,
                  req.sop,
                  req.eop,
                  req.sof_packet,
                  cfg.speed),
                UVM_MEDIUM)

      // Wait until DUT accepts transaction
      while ((wait_count < ready_timeout) &&
             !accepted &&
             !reset_abort) begin

        @(vif.cb_drv);

        // Check reset
        if (vif.cb_drv.rst_n !== 1'b1) begin

          reset_abort = 1;

          `uvm_warning("PHY_DRV",
                       "Reset asserted during SIE transaction")

        end

        // Check handshake
        else if (vif.cb_drv.sie_ready === 1'b1) begin

          accepted = 1;

          transaction_accepted = 1;

          `uvm_info("PHY_DRV",
                    "SIE transaction accepted by DUT",
                    UVM_MEDIUM)

        end

        else if (vif.cb_drv.sie_ready !== 1'b0) begin

          `uvm_error("PHY_DRV",
                     "Unknown value detected on sie_ready")

          wait_count++;

        end

        else begin

          wait_count++;

        end

      end

      // Deassert SIE inputs
      @(vif.cb_drv);

      drive_idle();

      // Report transaction result
      if (accepted) begin

        `uvm_info("PHY_DRV",
                  "PHY transaction completed successfully",
                  UVM_MEDIUM)

      end
      else if (reset_abort) begin

        `uvm_warning("PHY_DRV",
                     "PHY transaction aborted due to reset")

      end
      else begin

        `uvm_error("PHY_DRV",
                   $sformatf(
                     "Timeout waiting for sie_ready after %0d cycles",
                     ready_timeout))

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

    `uvm_info("PHY_DRV_REPORT",
              "PHY driver simulation completed",
              UVM_LOW)

  endfunction

endclass

