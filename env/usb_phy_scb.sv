class usb_phy_scb extends uvm_scoreboard;

  `uvm_component_utils(usb_phy_scb)

  // ------------------------------------------------------------
  // Analysis FIFOs
  // ------------------------------------------------------------

  uvm_tlm_analysis_fifo #(phy_transaction)     phy_fifo;
  uvm_tlm_analysis_fifo #(usb_bfm_transaction) bus_fifo;

  // ------------------------------------------------------------
  // Transaction handles
  // ------------------------------------------------------------

  phy_transaction     phy_tr;
  usb_bfm_transaction bus_tr;

  // ------------------------------------------------------------
  // TX packet tracking
  // ------------------------------------------------------------

  bit tx_packet_active;
  int tx_packet_count;
  int tx_symbol_count;

  // ------------------------------------------------------------
  // RX tracking
  // ------------------------------------------------------------

  int rx_packet_count;
  int rx_byte_count;
  int rx_error_count;

  // ------------------------------------------------------------
  // Scoreboard statistics
  // ------------------------------------------------------------

  int total_checks;
  int total_pass;
  int total_fail;

  int tx_checks;
  int tx_pass;
  int tx_fail;

  int rx_checks;
  int rx_pass;
  int rx_fail;

  int bus_checks;
  int bus_pass;
  int bus_fail;

  // ------------------------------------------------------------
  // Constructor
  // ------------------------------------------------------------

  function new(string name = "usb_phy_scb",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction

  // ------------------------------------------------------------
  // Build phase
  // ------------------------------------------------------------

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    phy_fifo = new("phy_fifo", this);
    bus_fifo = new("bus_fifo", this);

    tx_packet_active = 0;

    tx_packet_count = 0;
    tx_symbol_count = 0;

    rx_packet_count = 0;
    rx_byte_count = 0;
    rx_error_count = 0;

    total_checks = 0;
    total_pass   = 0;
    total_fail   = 0;

    tx_checks = 0;
    tx_pass   = 0;
    tx_fail   = 0;

    rx_checks = 0;
    rx_pass   = 0;
    rx_fail   = 0;

    bus_checks = 0;
    bus_pass   = 0;
    bus_fail   = 0;

  endfunction

  // ------------------------------------------------------------
  // Run phase
  // ------------------------------------------------------------

  task run_phase(uvm_phase phase);

    `uvm_info("USB_PHY_SCB",
              "USB PHY scoreboard started",
              UVM_LOW)

    fork
      process_phy_transactions();
      process_bus_transactions();
    join

  endtask

  // ------------------------------------------------------------
  // PHY monitor transaction processing
  // ------------------------------------------------------------

  task process_phy_transactions();

    forever begin

      phy_fifo.get(phy_tr);

      if (phy_tr == null) begin
        `uvm_error("USB_PHY_SCB",
                   "NULL transaction received from PHY monitor")
        continue;
      end

      // TX-side SIE handshake
      if (phy_tr.sie_valid && phy_tr.sie_ready) begin

        tx_checks++;
        total_checks++;

        `uvm_info("USB_PHY_SCB",
          $sformatf(
            "TX accepted: DATA=0x%02h SPEED=%0d SOP=%0b EOP=%0b SOF=%0b",
            phy_tr.sie_data,
            phy_tr.usb_speed,
            phy_tr.sop,
            phy_tr.eop,
            phy_tr.sof_packet
          ),
          UVM_MEDIUM)

        tx_pass++;
        total_pass++;

      end

      // RX-side output checking
      if (phy_tr.RxValid) begin

        rx_checks++;
        total_checks++;

        rx_byte_count++;

        `uvm_info("USB_PHY_SCB",
          $sformatf(
            "RX BYTE: DATA=0x%02h ACTIVE=%0b ERROR=%0b SPEED=%0d",
            phy_tr.DataOut,
            phy_tr.RxActive,
            phy_tr.RxError,
            phy_tr.usb_speed
          ),
          UVM_MEDIUM)

        if (phy_tr.RxError) begin

          rx_fail++;
          total_fail++;
          rx_error_count++;

          `uvm_error("USB_PHY_SCB",
            $sformatf(
              "RX error asserted with valid data: DATA=0x%02h",
              phy_tr.DataOut
            ))

        end
        else begin

          rx_pass++;
          total_pass++;

        end

      end

      // RX packet boundary tracking
      if (phy_tr.rx_sop) begin

        rx_packet_count++;

        `uvm_info("USB_PHY_SCB",
                  "RX packet start detected",
                  UVM_MEDIUM)

      end

      if (phy_tr.rx_eop) begin

        `uvm_info("USB_PHY_SCB",
                  "RX packet end detected",
                  UVM_MEDIUM)

      end

      // RX error indicators
      if (phy_tr.rx_stuff_err ||
          phy_tr.rx_align_err ||
          phy_tr.rx_line_err ||
          phy_tr.rx_sync_err) begin

        rx_error_count++;

        `uvm_warning("USB_PHY_SCB",
          $sformatf(
            "RX error flags: STUFF=%0b ALIGN=%0b LINE=%0b SYNC=%0b",
            phy_tr.rx_stuff_err,
            phy_tr.rx_align_err,
            phy_tr.rx_line_err,
            phy_tr.rx_sync_err
          ))

      end

    end

  endtask

  // ------------------------------------------------------------
  // USB bus monitor transaction processing
  // ------------------------------------------------------------

  task process_bus_transactions();

    forever begin

      bus_fifo.get(bus_tr);

      if (bus_tr == null) begin
        `uvm_error("USB_PHY_SCB",
                   "NULL transaction received from USB bus monitor")
        continue;
      end

      bus_checks++;
      total_checks++;

      // Physical packet start
      if (bus_tr.packet_start) begin

        tx_packet_active = 1;
        tx_packet_count++;

        tx_symbol_count = 0;

        `uvm_info("USB_PHY_SCB",
          $sformatf(
            "USB BUS PACKET START: LINE_STATE=%0b",
            bus_tr.phy_line_state
          ),
          UVM_MEDIUM)

      end

      // Count physical symbols while packet is active
      if (tx_packet_active) begin

        tx_symbol_count++;

      end

      // Physical packet end
      if (bus_tr.packet_end) begin

        tx_packet_active = 0;

        `uvm_info("USB_PHY_SCB",
          $sformatf(
            "USB BUS PACKET END: SYMBOL_COUNT=%0d",
            tx_symbol_count
          ),
          UVM_MEDIUM)

      end

      // Basic line-state validity check
      // DP and DM must not both be high.
      if (bus_tr.phy_line_state === 2'b11) begin

        bus_fail++;
        total_fail++;

        `uvm_error("USB_PHY_SCB",
          "Invalid USB differential line state: DP=1 and DM=1")

      end
      else begin

        bus_pass++;
        total_pass++;

      end

    end

  endtask

  // ------------------------------------------------------------
  // Check phase
  // ------------------------------------------------------------

  function void check_phase(uvm_phase phase);

    super.check_phase(phase);

    if (tx_packet_active) begin

      `uvm_error("USB_PHY_SCB",
                 "TX packet was still active at end of simulation")

    end

  endfunction

  // ------------------------------------------------------------
  // Report phase
  // ------------------------------------------------------------

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("USB_PHY_SCB",
      "==============================================",
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      "          USB 2.0 PHY SCOREBOARD REPORT",
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      "==============================================",
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "TOTAL CHECKS : %0d",
        total_checks
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "TOTAL PASS   : %0d",
        total_pass
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "TOTAL FAIL   : %0d",
        total_fail
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      "----------------------------------------------",
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "TX CHECKS=%0d PASS=%0d FAIL=%0d",
        tx_checks, tx_pass, tx_fail
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "RX CHECKS=%0d PASS=%0d FAIL=%0d",
        rx_checks, rx_pass, rx_fail
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "BUS CHECKS=%0d PASS=%0d FAIL=%0d",
        bus_checks, bus_pass, bus_fail
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      "----------------------------------------------",
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "TX PACKETS     : %0d",
        tx_packet_count
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "RX PACKETS     : %0d",
        rx_packet_count
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "RX BYTES       : %0d",
        rx_byte_count
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      $sformatf(
        "RX ERROR COUNT : %0d",
        rx_error_count
      ),
      UVM_NONE)

    `uvm_info("USB_PHY_SCB",
      "==============================================",
      UVM_NONE)

    if (total_fail == 0) begin

      `uvm_info("USB_PHY_SCB",
                "SCOREBOARD RESULT: NO FAILURES REPORTED",
                UVM_LOW)

    end
    else begin

      `uvm_error("USB_PHY_SCB",
        $sformatf(
          "SCOREBOARD RESULT: %0d FAILURES",
          total_fail
        ))

    end

  endfunction

endclass
