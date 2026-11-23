
class phy_driver extends uvm_driver #(phy_transaction);

  `uvm_component_utils(phy_driver)

  // Virtual interface and configuration
  virtual usb_phy_if vif;
  phy_agent_config cfg;

  // Maximum cycles to wait for DUT ready
  int unsigned ready_timeout;

  // Transaction status
  bit transaction_accepted;


  // Constructor
  function new(string name = "phy_driver",
               uvm_component parent = null);

    super.new(name, parent);

    ready_timeout        = 50;
    transaction_accepted = 0;

  endfunction


  // Build phase
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(virtual usb_phy_if)::get(
          this, "", "vif", vif)) begin

      `uvm_fatal("PHY_DRV_VIF",
                 "PHY virtual interface not found")
    end

    if (vif == null) begin

      `uvm_fatal("PHY_DRV_VIF_NULL",
                 "PHY virtual interface is NULL")
    end

    if (!uvm_config_db#(phy_agent_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("PHY_DRV_CFG",
                 "PHY agent configuration not found")
    end

    if (cfg == null) begin

      `uvm_fatal("PHY_DRV_CFG_NULL",
                 "PHY agent configuration is NULL")
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


  // Drive idle values
  task drive_idle();

    vif.cb_drv.sie_valid  <= 1'b0;
    vif.cb_drv.sie_data   <= '0;
    vif.cb_drv.sie_sop    <= 1'b0;
    vif.cb_drv.sie_eop    <= 1'b0;
    vif.cb_drv.sof_packet <= 1'b0;

  endtask


  // Wait for reset release
  task wait_for_reset_release();

    while (vif.cb_drv.rst_n !== 1'b1) begin
      @(vif.cb_drv);
    end

    `uvm_info("PHY_DRV",
              "Reset released. Driver is ready.",
              UVM_MEDIUM)

  endtask


  // Main driver process
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

      // Get next transaction
      seq_item_port.get_next_item(req);

      accepted             = 0;
      reset_abort          = 0;
      wait_count           = 0;
      transaction_accepted = 0;

      // Wait until reset is released
      wait_for_reset_release();

      // Configure USB speed
      @(vif.cb_drv);

      
      vif.cb_drv.usb_speed <= usb_phy_pkg::speed_t'(cfg.speed);

      // Check transaction
      if (req.sie_valid !== 1'b1) begin

        `uvm_error("PHY_DRV",
                   "Invalid transaction: sie_valid must be 1")

        drive_idle();
        seq_item_port.item_done();

      end
      else begin

        // Drive SIE transaction
        vif.cb_drv.sie_data   <= req.sie_data;
        vif.cb_drv.sie_valid  <= 1'b1;
        vif.cb_drv.sie_sop    <= req.sop;
        vif.cb_drv.sie_eop    <= req.eop;
        vif.cb_drv.sof_packet <= req.sof_packet;

        `uvm_info("PHY_DRV",
                  $sformatf(
                    "Driving SIE transaction: DATA=0x%02h SOP=%0b EOP=%0b SOF=%0b SPEED=%0d",
                    req.sie_data,
                    req.sop,
                    req.eop,
                    req.sof_packet,
                    cfg.speed),
                  UVM_MEDIUM)

        // Wait for DUT handshake
        while ((wait_count < ready_timeout) &&
               !accepted &&
               !reset_abort) begin

          @(vif.cb_drv);

          // Reset check
          if (vif.cb_drv.rst_n !== 1'b1) begin

            reset_abort = 1'b1;

            `uvm_warning("PHY_DRV",
                         "Reset asserted during SIE transaction")

          end
          else begin

            case (vif.cb_drv.sie_ready)

              1'b1: begin

                accepted             = 1'b1;
                transaction_accepted = 1'b1;

                `uvm_info("PHY_DRV",
                          "DUT accepted SIE transaction",
                          UVM_MEDIUM)

              end

              1'b0: begin

                wait_count++;

              end

              default: begin

                wait_count++;

                `uvm_warning("PHY_DRV",
                             "Unknown value detected on sie_ready")

              end

            endcase

          end

        end

        // Deassert immediately after handshake/abort/timeout.
        // The DUT has already sampled the preceding valid beat.
        drive_idle();

        // Report transaction result
        if (accepted) begin

          `uvm_info("PHY_DRV",
                    "PHY transaction accepted successfully",
                    UVM_MEDIUM)

        end
        else if (reset_abort) begin

          `uvm_warning("PHY_DRV",
                       "PHY transaction aborted due to reset")

        end
        else begin

          `uvm_error("PHY_DRV",
                     $sformatf(
                       "Timeout waiting for sie_ready. Timeout=%0d cycles",
                       ready_timeout))

        end

        // Complete sequence-driver handshake
        seq_item_port.item_done();

      end

    end

  endtask


  // Report phase
  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("PHY_DRV_REPORT",
              "PHY driver simulation completed",
              UVM_LOW)

  endfunction

endclass

