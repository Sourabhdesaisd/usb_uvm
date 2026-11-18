

class usb_bfm_driver extends uvm_driver #(usb_bfm_transaction);

  `uvm_component_utils(usb_bfm_driver)

     
  // 1. VIRTUAL INTERFACE AND CONFIGURATION
     

  virtual usb_bus_if vif;

  usb_bfm_config cfg;

  // Maximum system-clock cycles to wait for bit_tick
  int unsigned bit_tick_timeout;

  // Transaction status
  bit transaction_aborted;


     
  // 2. CONSTRUCTOR
     

  function new(string name = "usb_bfm_driver",
               uvm_component parent = null);

    super.new(name, parent);

    bit_tick_timeout = 1000;
    transaction_aborted = 0;

  endfunction


     
  // 3. BUILD PHASE
     

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(virtual usb_bus_if)::get(
          this, "", "vif", vif)) begin

      `uvm_fatal("USB_DRV_VIF",
                 "USB bus virtual interface not found")

    end

    if (vif == null) begin

      `uvm_fatal("USB_DRV_VIF_NULL",
                 "USB bus virtual interface is NULL")

    end

    if (!uvm_config_db#(usb_bfm_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("USB_DRV_CFG",
                 "USB BFM configuration not found")

    end

    if (cfg == null) begin

      `uvm_fatal("USB_DRV_CFG_NULL",
                 "USB BFM configuration is NULL")

    end

    if (cfg.speed == USB_SPEED_RESERVED) begin

      `uvm_fatal("USB_DRV_SPEED",
                 "Reserved USB speed selected")

    end

    `uvm_info("USB_DRV",
              $sformatf(
                "USB BFM driver configured. Speed=%0d",
                cfg.speed),
              UVM_LOW)

  endfunction


     
  // 4. RELEASE EXTERNAL USB BUS
     

  task drive_idle();

    vif.cb_drv.device_oe <= 1'b0;
    vif.cb_drv.device_dp <= 1'b0;
    vif.cb_drv.device_dm <= 1'b0;

  endtask


     
  // 5. DRIVE USB LINE STATE
     

  task drive_line_state(usb_line_state_e state);

    case (state)

                 
      // SE0
                 

      USB_LINE_SE0: begin

        vif.cb_drv.device_dp <= 1'b0;
        vif.cb_drv.device_dm <= 1'b0;

      end


                 
      // SE1
                 

      USB_LINE_SE1: begin

        vif.cb_drv.device_dp <= 1'b1;
        vif.cb_drv.device_dm <= 1'b1;

      end


                 
      // J STATE
                 

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


                 
      // K STATE
                 

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


                 
      // INVALID STATE
                 

      default: begin

        `uvm_fatal("USB_DRV_LINE",
                   $sformatf(
                     "Invalid USB line state: %0d",
                     state))

      end

    endcase

  endtask


     
  // 6. WAIT FOR RESET RELEASE
     

  task wait_for_reset_release();

    while (vif.cb_drv.rst_n !== 1'b1) begin

      @(vif.cb_drv);

    end

    `uvm_info("USB_DRV",
              "Reset released. USB BFM driver ready.",
              UVM_MEDIUM)

  endtask


     
  // 7. WAIT FOR REQUESTED BIT INTERVALS
     

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

                 
      // Reset check
                 

      if (vif.cb_drv.rst_n !== 1'b1) begin

        `uvm_warning("USB_DRV",
                     "Reset asserted during USB bus transaction")

        success = 1'b0;

        break;

      end

                 
      // Count bit_tick events
                 

      if (vif.cb_drv.bit_tick === 1'b1) begin

        tick_count++;

      end

      else if (vif.cb_drv.bit_tick !== 1'b0) begin

        `uvm_error("USB_DRV",
                   "Unknown value detected on bit_tick")

        success = 1'b0;

        break;

      end

                 
      // Timeout check
                 

      if ((cycle_count >= bit_tick_timeout) &&
          (tick_count < requested_bits)) begin

        `uvm_error("USB_DRV",
                   $sformatf(
                     "bit_tick timeout. Received=%0d Requested=%0d",
                     tick_count,
                     requested_bits))

        success = 1'b0;

        break;

      end

    end

  endtask


     
  // 8. MAIN DRIVER PROCESS
     

  task run_phase(uvm_phase phase);

    usb_bfm_transaction req;

    bit success;

    // Initially release the external USB bus
    drive_idle();

    `uvm_info("USB_DRV",
              "USB BFM driver started",
              UVM_LOW)

    forever begin

                 
      // Get transaction from sequencer
                 

      seq_item_port.get_next_item(req);

      transaction_aborted = 1'b0;
      success             = 1'b0;

                 
      // Wait for reset release
                 

      wait_for_reset_release();

                 
      // Validate transaction
                 

      if ((req.bit_count == 0) ||
          (req.bit_count > 1024)) begin

        `uvm_error("USB_DRV",
                   $sformatf(
                     "Invalid bit_count=%0d. Allowed range is 1 to 1024",
                     req.bit_count))

        drive_idle();

        seq_item_port.item_done();

      end

      else begin

                    
        // Wait for clocking event
                    

        @(vif.cb_drv);

                    
        // Check reset before driving
                    

        if (vif.cb_drv.rst_n !== 1'b1) begin

          transaction_aborted = 1'b1;

          `uvm_warning("USB_DRV",
                       "Reset asserted before USB bus drive")

          drive_idle();

          seq_item_port.item_done();

        end

        else begin

              
          // Enable external USB partner drive
              

          vif.cb_drv.device_oe <= 1'b1;

              
          // Drive requested line state
              

          drive_line_state(req.line_state);

          `uvm_info("USB_DRV",
                    $sformatf(
                      "Driving USB bus: SPEED=%0d LINE_STATE=%0d BIT_COUNT=%0d",
                      cfg.speed,
                      req.line_state,
                      req.bit_count),
                    UVM_MEDIUM)

              
          // Hold line state for requested bit intervals
              

          wait_bit_intervals(req.bit_count, success);

              
          // Release external USB bus
              

          @(vif.cb_drv);

          drive_idle();

              
          // Report transaction result
              

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

      end

    end

  endtask


     
  // 9. REPORT PHASE
     

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("USB_DRV_REPORT",
              "USB BFM driver simulation completed",
              UVM_LOW)

  endfunction

endclass

