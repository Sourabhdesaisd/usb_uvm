class usb_phy_scb extends uvm_scoreboard;

  `uvm_component_utils(usb_phy_scb)


  // ==================================================
  // ANALYSIS FIFOS
  // ==================================================

  uvm_tlm_analysis_fifo #(phy_transaction) phy_fifo;

  uvm_tlm_analysis_fifo #(phy_transaction) rx_fifo;

  uvm_tlm_analysis_fifo #(phy_transaction) rx_status_fifo;

  uvm_tlm_analysis_fifo #(usb_bfm_transaction) bus_fifo;


  // ==================================================
  // TRANSACTION HANDLES
  // ==================================================

  phy_transaction tx_tr;
  phy_transaction rx_tr;
  phy_transaction rx_status_tr;

  usb_bfm_transaction bus_tr;


  // ==================================================
  // TX STATISTICS
  // ==================================================

  int unsigned tx_handshake_count;
  int unsigned tx_sop_count;
  int unsigned tx_eop_count;
  int unsigned tx_sof_count;


  // ==================================================
  // RX STATISTICS
  // ==================================================

  int unsigned rx_byte_count;
  int unsigned rx_sop_count;
  int unsigned rx_eop_count;

  int unsigned rx_error_count;
  int unsigned rx_stuff_error_count;
  int unsigned rx_align_error_count;
  int unsigned rx_line_error_count;
  int unsigned rx_sync_error_count;
  int unsigned rx_bus_reset_count;


  // ==================================================
  // USB BUS STATISTICS
  // ==================================================

  int unsigned bus_segment_count;

  int unsigned bus_dpdm_10_count;
  int unsigned bus_dpdm_01_count;
  int unsigned bus_se0_count;
  int unsigned bus_se1_count;

  int unsigned bus_unknown_count;
  int unsigned bus_released_count;
  int unsigned bus_contention_count;


  // ==================================================
  // GENERAL STATISTICS
  // ==================================================

  int unsigned total_errors;
  int unsigned total_warnings;


  // ==================================================
  // PACKET TRACKING
  // ==================================================

  bit tx_packet_active;
  bit rx_packet_active;

  speed_t tx_packet_speed;
  speed_t rx_packet_speed;


  // ==================================================
  // CONSTRUCTOR
  // ==================================================

  function new(
    string name = "usb_phy_scb",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  // ==================================================
  // BUILD PHASE
  // ==================================================

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);


    // Create FIFOs
    phy_fifo       = new("phy_fifo", this);
    rx_fifo        = new("rx_fifo", this);
    rx_status_fifo = new("rx_status_fifo", this);
    bus_fifo       = new("bus_fifo", this);


    // TX counters
    tx_handshake_count = 0;
    tx_sop_count       = 0;
    tx_eop_count       = 0;
    tx_sof_count       = 0;


    // RX counters
    rx_byte_count        = 0;
    rx_sop_count         = 0;
    rx_eop_count         = 0;

    rx_error_count       = 0;
    rx_stuff_error_count = 0;
    rx_align_error_count = 0;
    rx_line_error_count  = 0;
    rx_sync_error_count  = 0;
    rx_bus_reset_count   = 0;


    // Bus counters
    bus_segment_count = 0;

    bus_dpdm_10_count = 0;
    bus_dpdm_01_count = 0;
    bus_se0_count     = 0;
    bus_se1_count     = 0;

    bus_unknown_count   = 0;
    bus_released_count  = 0;
    bus_contention_count = 0;


    // General counters
    total_errors   = 0;
    total_warnings = 0;


    // Packet tracking
    tx_packet_active = 1'b0;
    rx_packet_active = 1'b0;

  endfunction


  // ==================================================
  // RUN PHASE
  // ==================================================

  task run_phase(uvm_phase phase);

    `uvm_info(
      "USB_SCB",
      "USB PHY scoreboard started",
      UVM_LOW
    )

    fork

      process_tx();

      process_rx();

      process_rx_status();

      process_bus();

    join

  endtask


  // ==================================================
  // TX PROCESSING
  // ==================================================

  task process_tx();

    forever begin

      phy_fifo.get(tx_tr);


      if (tx_tr == null) begin

        total_errors++;

        `uvm_error(
          "USB_SCB",
          "NULL TX transaction"
        )

        continue;

      end


      // The PHY monitor must publish accepted
      // SIE transactions only.
      if (!(tx_tr.valid && tx_tr.ready)) begin

        total_errors++;

        `uvm_error(
          "USB_SCB",
          "TX monitor published a non-handshake transaction"
        )

        continue;

      end


      tx_handshake_count++;


      // --------------------------------------------
      // SOP
      // --------------------------------------------

      if (tx_tr.sop) begin

        tx_sop_count++;

        if (tx_packet_active) begin

          total_errors++;

          `uvm_error(
            "USB_SCB",
            "TX SOP received while previous packet is active"
          )

        end

        tx_packet_active = 1'b1;
        tx_packet_speed  = tx_tr.speed;

      end

      else if (!tx_packet_active) begin

        total_warnings++;

        `uvm_warning(
          "USB_SCB",
          "TX data received without preceding SOP"
        )

        tx_packet_active = 1'b1;
        tx_packet_speed  = tx_tr.speed;

      end


      // --------------------------------------------
      // Speed consistency
      // --------------------------------------------

      if (tx_packet_active &&
          tx_tr.speed != tx_packet_speed) begin

        total_errors++;

        `uvm_error(
          "USB_SCB",
          $sformatf(
            "TX speed changed during packet: expected=%0d actual=%0d",
            tx_packet_speed,
            tx_tr.speed
          )
        )

      end


      // --------------------------------------------
      // SOF
      // --------------------------------------------

      if (tx_tr.sof_packet) begin
        tx_sof_count++;
      end


      // --------------------------------------------
      // EOP
      // --------------------------------------------

      if (tx_tr.eop) begin

        tx_eop_count++;

        tx_packet_active = 1'b0;

      end


      `uvm_info(
        "USB_SCB_TX",
        tx_tr.convert2string(),
        UVM_MEDIUM
      )

    end

  endtask


  // ==================================================
  // RX BYTE PROCESSING
  // ==================================================

  task process_rx();

    forever begin

      rx_fifo.get(rx_tr);


      if (rx_tr == null) begin

        total_errors++;

        `uvm_error(
          "USB_SCB",
          "NULL RX transaction"
        )

        continue;

      end


      if (rx_tr.valid !== 1'b1) begin

        total_errors++;

        `uvm_error(
          "USB_SCB",
          "RX byte FIFO received transaction without RxValid"
        )

        continue;

      end


      rx_byte_count++;


      // --------------------------------------------
      // RX SOP
      // --------------------------------------------

      if (rx_tr.sop) begin

        rx_sop_count++;

        if (rx_packet_active) begin

          total_errors++;

          `uvm_error(
            "USB_SCB",
            "RX SOP received while previous RX packet is active"
          )

        end

        rx_packet_active = 1'b1;
        rx_packet_speed  = rx_tr.speed;

      end

      else if (!rx_packet_active) begin

        total_warnings++;

        `uvm_warning(
          "USB_SCB",
          "RX byte received without preceding RX SOP"
        )

        rx_packet_active = 1'b1;
        rx_packet_speed  = rx_tr.speed;

      end


      // --------------------------------------------
      // RX speed consistency
      // --------------------------------------------

      if (rx_packet_active &&
          rx_tr.speed != rx_packet_speed) begin

        total_errors++;

        `uvm_error(
          "USB_SCB",
          $sformatf(
            "RX speed changed during packet: expected=%0d actual=%0d",
            rx_packet_speed,
            rx_tr.speed
          )
        )

      end


      // --------------------------------------------
      // RX EOP
      // --------------------------------------------

      if (rx_tr.eop) begin

        rx_eop_count++;

        rx_packet_active = 1'b0;

      end


      `uvm_info(
        "USB_SCB_RX",
        rx_tr.convert2string(),
        UVM_MEDIUM
      )

    end

  endtask


  // ==================================================
  // RX STATUS PROCESSING
  // ==================================================

  task process_rx_status();

    forever begin

      rx_status_fifo.get(rx_status_tr);


      if (rx_status_tr == null) begin

        total_errors++;

        `uvm_error(
          "USB_SCB",
          "NULL RX status transaction"
        )

        continue;

      end


      // RX status event transactions have valid=0.
      if (rx_status_tr.valid !== 1'b0) begin

        total_errors++;

        `uvm_error(
          "USB_SCB",
          "Unexpected valid byte transaction in RX status FIFO"
        )

      end


      if (rx_status_tr.rx_error) begin

        rx_error_count++;

        `uvm_error(
          "USB_SCB_RX_STATUS",
          "RX error observed"
        )

      end


      if (rx_status_tr.rx_stuff_err) begin

        rx_stuff_error_count++;

        `uvm_error(
          "USB_SCB_RX_STATUS",
          "RX stuffing error observed"
        )

      end


      if (rx_status_tr.rx_align_err) begin

        rx_align_error_count++;

        `uvm_info(
          "USB_SCB_RX_STATUS",
          "RX alignment error observed",
          UVM_MEDIUM
        )

      end


      if (rx_status_tr.rx_line_err) begin

        rx_line_error_count++;

        `uvm_error(
          "USB_SCB_RX_STATUS",
          "RX line error observed"
        )

      end


      if (rx_status_tr.rx_sync_err) begin

        rx_sync_error_count++;

        `uvm_info(
          "USB_SCB_RX_STATUS",
          "RX SYNC error observed",
          UVM_MEDIUM
        )

      end


      if (rx_status_tr.rx_bus_reset) begin

        rx_bus_reset_count++;

        `uvm_info(
          "USB_SCB_RX_STATUS",
          "USB bus reset detected",
          UVM_MEDIUM
        )

      end

    end

  endtask


  // ==================================================
  // USB BUS PROCESSING
  // ==================================================

  task process_bus();

    forever begin

      bus_fifo.get(bus_tr);


      if (bus_tr == null) begin

        total_errors++;

        `uvm_error(
          "USB_SCB",
          "NULL USB bus transaction"
        )

        continue;

      end


      bus_segment_count++;


      // --------------------------------------------
      // Bus contention
      // --------------------------------------------

      if (bus_tr.bus_contention) begin

        bus_contention_count++;

        total_errors++;

        `uvm_error(
          "USB_SCB_BUS",
          $sformatf(
            "Bus contention: DUT_OE=%0b EXT_OE=%0b",
            bus_tr.phy_drive_enable,
            bus_tr.external_drive_enable
          )
        )

      end


      // --------------------------------------------
      // Released bus
      // --------------------------------------------

      if (!bus_tr.drive_enable) begin

        bus_released_count++;

        `uvm_info(
          "USB_SCB_BUS",
          $sformatf(
            "USB bus released: DP=%b DM=%b DURATION=%0d",
            bus_tr.dp,
            bus_tr.dm,
            bus_tr.duration_cycles
          ),
          UVM_HIGH
        )

      end


      // --------------------------------------------
      // Driven bus
      // --------------------------------------------

      else begin

        // A driven bus must have known DP and DM.
        if ((bus_tr.dp !== 1'b0 && bus_tr.dp !== 1'b1) ||
            (bus_tr.dm !== 1'b0 && bus_tr.dm !== 1'b1)) begin

          bus_unknown_count++;

          total_errors++;

          `uvm_error(
            "USB_SCB_BUS",
            $sformatf(
              {
                "Unknown X/Z bus state while driver enabled: ",
                "DP=%b DM=%b DUT_OE=%0b EXT_OE=%0b"
              },
              bus_tr.dp,
              bus_tr.dm,
              bus_tr.phy_drive_enable,
              bus_tr.external_drive_enable
            )
          )

        end

        else begin

          case ({bus_tr.dp, bus_tr.dm})

            2'b10: begin
              bus_dpdm_10_count++;
            end

            2'b01: begin
              bus_dpdm_01_count++;
            end

            2'b00: begin
              bus_se0_count++;
            end

            2'b11: begin

              bus_se1_count++;

              total_warnings++;

              `uvm_warning(
                "USB_SCB_BUS",
                "SE1 observed on USB bus"
              )

            end

          endcase

        end

      end


      // --------------------------------------------
      // Bus monitor debug
      // --------------------------------------------

      `uvm_info(
        "USB_SCB_BUS",
        bus_tr.convert2string(),
        UVM_HIGH
      )

    end

  endtask


  // ==================================================
  // CHECK PHASE
  // ==================================================

  function void check_phase(uvm_phase phase);

    super.check_phase(phase);


    if (tx_packet_active) begin

      total_errors++;

      `uvm_error(
        "USB_SCB",
        "TX packet remained active at end of simulation"
      )

    end


    if (rx_packet_active) begin

      total_warnings++;

      `uvm_warning(
        "USB_SCB",
        "RX packet remained active at end of simulation"
      )

    end

  endfunction


  // ==================================================
  // REPORT PHASE
  // ==================================================

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);


    `uvm_info(
      "USB_SCB",
      "==============================================",
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      "       USB 2.0 PHY SCOREBOARD REPORT",
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      "==============================================",
      UVM_NONE
    )


    // ----------------------------------------------
    // TX report
    // ----------------------------------------------

    `uvm_info(
      "USB_SCB",
      $sformatf("TX HANDSHAKES       : %0d", tx_handshake_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("TX SOP              : %0d", tx_sop_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("TX EOP              : %0d", tx_eop_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("TX SOF              : %0d", tx_sof_count),
      UVM_NONE
    )


    // ----------------------------------------------
    // RX report
    // ----------------------------------------------

    `uvm_info(
      "USB_SCB",
      "----------------------------------------------",
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("RX VALID BYTES      : %0d", rx_byte_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("RX SOP              : %0d", rx_sop_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("RX EOP              : %0d", rx_eop_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("RX ERROR EVENTS     : %0d", rx_error_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("RX STUFF ERRORS     : %0d", rx_stuff_error_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("RX ALIGN ERRORS     : %0d", rx_align_error_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("RX LINE ERRORS      : %0d", rx_line_error_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("RX SYNC ERRORS      : %0d", rx_sync_error_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("RX BUS RESETS       : %0d", rx_bus_reset_count),
      UVM_NONE
    )


    // ----------------------------------------------
    // Bus report
    // ----------------------------------------------

    `uvm_info(
      "USB_SCB",
      "----------------------------------------------",
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("BUS SEGMENTS        : %0d", bus_segment_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("BUS DPDM=10         : %0d", bus_dpdm_10_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("BUS DPDM=01         : %0d", bus_dpdm_01_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("BUS SE0             : %0d", bus_se0_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("BUS SE1             : %0d", bus_se1_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("BUS UNKNOWN         : %0d", bus_unknown_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("BUS RELEASED        : %0d", bus_released_count),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("BUS CONTENTION      : %0d", bus_contention_count),
      UVM_NONE
    )


    // ----------------------------------------------
    // General report
    // ----------------------------------------------

    `uvm_info(
      "USB_SCB",
      "----------------------------------------------",
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("TOTAL ERRORS        : %0d", total_errors),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      $sformatf("TOTAL WARNINGS      : %0d", total_warnings),
      UVM_NONE
    )

    `uvm_info(
      "USB_SCB",
      "==============================================",
      UVM_NONE
    )


    if (total_errors == 0) begin

      `uvm_info(
        "USB_SCB",
        "SCOREBOARD: NO ERRORS REPORTED",
        UVM_LOW
      )

    end

    else begin

      `uvm_error(
        "USB_SCB",
        $sformatf(
          "SCOREBOARD ERRORS = %0d",
          total_errors
        )
      )

    end

  endfunction

endclass
