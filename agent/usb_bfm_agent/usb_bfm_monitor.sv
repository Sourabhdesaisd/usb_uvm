

class usb_bfm_monitor extends uvm_monitor;

  `uvm_component_utils(usb_bfm_monitor)

   
  // 1. VIRTUAL INTERFACE AND CONFIGURATION
   

  virtual usb_bus_if vif;

  usb_bfm_config cfg;


   
  // 2. ANALYSIS PORT
   

  uvm_analysis_port #(usb_bfm_transaction) analysis_port;


   
  // 3. TRANSACTION HANDLE
   

  usb_bfm_transaction tr;


   
  // 4. CONSTRUCTOR
   

  function new(string name = "usb_bfm_monitor",
               uvm_component parent = null);

    super.new(name, parent);

    analysis_port = new("analysis_port", this);

  endfunction


   
  // 5. BUILD PHASE
   

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(virtual usb_bus_if)::get(
          this, "", "vif", vif)) begin

      `uvm_fatal("USB_MON_VIF",
                 "USB bus virtual interface not found")

    end

    if (vif == null) begin

      `uvm_fatal("USB_MON_VIF_NULL",
                 "USB bus virtual interface is NULL")

    end

    if (!uvm_config_db#(usb_bfm_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("USB_MON_CFG",
                 "USB BFM configuration not found")

    end

    if (cfg == null) begin

      `uvm_fatal("USB_MON_CFG_NULL",
                 "USB BFM configuration is NULL")

    end

    if (cfg.speed == USB_SPEED_RESERVED) begin

      `uvm_fatal("USB_MON_SPEED",
                 "Reserved USB speed selected")

    end

    `uvm_info("USB_MON",
              $sformatf(
                "USB BFM monitor configured. Speed=%0d",
                cfg.speed),
              UVM_LOW)

  endfunction


   
  // 6. DECODE USB LINE STATE
   

  function usb_line_state_e decode_line_state(
    input logic dp,
    input logic dm
  );

      
    // SE0: DP=0, DM=0
      

    if ((dp === 1'b0) && (dm === 1'b0)) begin

      return USB_LINE_SE0;

    end

      
    // SE1: DP=1, DM=1
      

    else if ((dp === 1'b1) && (dm === 1'b1)) begin

      return USB_LINE_SE1;

    end

      
    // J and K states
      

    else begin

      case (cfg.speed)

        // ------------------------------------------
        // LOW SPEED
        // J = DP=0, DM=1
        // K = DP=1, DM=0
        // ------------------------------------------

        USB_SPEED_LS: begin

          if ((dp === 1'b0) && (dm === 1'b1))
            return USB_LINE_J;

          else if ((dp === 1'b1) && (dm === 1'b0))
            return USB_LINE_K;

        end


        // ------------------------------------------
        // FULL SPEED AND HIGH SPEED DIGITAL MAPPING
        // J = DP=1, DM=0
        // K = DP=0, DM=1
        // ------------------------------------------

        USB_SPEED_FS,
        USB_SPEED_HS: begin

          if ((dp === 1'b1) && (dm === 1'b0))
            return USB_LINE_J;

          else if ((dp === 1'b0) && (dm === 1'b1))
            return USB_LINE_K;

        end


        default: begin

          `uvm_error("USB_MON_SPEED",
                     "Invalid speed during line-state decoding")

        end

      endcase

    end

    // Unknown or invalid combination
    return USB_LINE_SE1;

  endfunction


   
  // 7. CHECK EXTERNAL PARTNER SIGNALS
   

  function bit check_device_signals();

    // device_oe must always be known
    if ((vif.cb_mon.device_oe !== 1'b0) &&
        (vif.cb_mon.device_oe !== 1'b1)) begin

      return 0;

    end

    // DP and DM are relevant only when the
    // external partner is driving the bus
    if (vif.cb_mon.device_oe === 1'b1) begin

      if ((vif.cb_mon.device_dp !== 1'b0 &&
           vif.cb_mon.device_dp !== 1'b1) ||

          (vif.cb_mon.device_dm !== 1'b0 &&
           vif.cb_mon.device_dm !== 1'b1)) begin

        return 0;

      end

    end

    return 1;

  endfunction


   
  // 8. CHECK DUT TX SIGNALS
   

  function bit check_phy_tx_signals();

    // PHY TX valid must always be known
    if ((vif.cb_mon.phy_tx_valid !== 1'b0) &&
        (vif.cb_mon.phy_tx_valid !== 1'b1)) begin

      return 0;

    end

    // Check line state only during valid TX activity
    if (vif.cb_mon.phy_tx_valid === 1'b1) begin

      if (^vif.cb_mon.phy_line_state === 1'bx) begin

        return 0;

      end

    end

    return 1;

  endfunction


   
  // 9. MAIN MONITOR PROCESS
   

  task run_phase(uvm_phase phase);

    forever begin

      @(vif.cb_mon);

        
      // Ignore observations during reset
        

      if (vif.cb_mon.rst_n !== 1'b1) begin

        continue;

      end


        
      // Check external partner signals
        

      if (!check_device_signals()) begin

        `uvm_error("USB_MON_DEVICE_X",
                   "Unknown value detected on external device signals")

        continue;

      end


        
      // Check DUT TX signals
        

      if (!check_phy_tx_signals()) begin

        `uvm_error("USB_MON_PHY_X",
                   "Unknown value detected on PHY TX signals")

        continue;

      end


        
      // Create observation transaction
        

      tr = usb_bfm_transaction::type_id::create(
             "tr", this);


        
      // Capture external partner signals
        

      tr.device_oe = vif.cb_mon.device_oe;
      tr.device_dp = vif.cb_mon.device_dp;
      tr.device_dm = vif.cb_mon.device_dm;


        
      // Capture DUT physical TX signals
        

      tr.phy_line_state = vif.cb_mon.phy_line_state;
      tr.phy_tx_valid   = vif.cb_mon.phy_tx_valid;


        
      // Set event indicators
        

      tr.is_device_drive =
          (vif.cb_mon.device_oe === 1'b1);

      tr.is_phy_tx =
          (vif.cb_mon.phy_tx_valid === 1'b1);


        
      // Decode external partner line state
        

      if (tr.is_device_drive) begin

        tr.line_state = decode_line_state(
                          vif.cb_mon.device_dp,
                          vif.cb_mon.device_dm);

      end


        
      // Publish meaningful bus activity
        

      if (tr.is_device_drive || tr.is_phy_tx) begin

        analysis_port.write(tr);

        `uvm_info("USB_MON",
                  $sformatf(
                    "SPEED=%0d DEVICE_OE=%0b DEVICE_DP=%0b DEVICE_DM=%0b DEVICE_STATE=%0d PHY_TX=%0b PHY_STATE=%0d",
                    cfg.speed,
                    tr.device_oe,
                    tr.device_dp,
                    tr.device_dm,
                    tr.line_state,
                    tr.phy_tx_valid,
                    tr.phy_line_state),
                  UVM_MEDIUM)

      end


        
      // Monitor USB bit timing
        

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


   
  // 10. REPORT PHASE
   

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("USB_MON_REPORT",
              "USB BFM monitor simulation completed",
              UVM_LOW)

  endfunction

endclass

