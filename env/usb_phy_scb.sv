
class usb_phy_scb extends uvm_scoreboard;

  `uvm_component_utils(usb_phy_scb)

  // Analysis FIFOs
  uvm_tlm_analysis_fifo #(phy_transaction) phy_fifo;
  uvm_tlm_analysis_fifo #(phy_transaction) rx_fifo;
  uvm_tlm_analysis_fifo #(usb_bfm_transaction) bus_fifo;

  // Transaction handles
  phy_transaction tx_tr;
  phy_transaction rx_tr;
  usb_bfm_transaction bus_tr;

  // TX statistics
  int unsigned tx_handshake_count;
  int unsigned tx_sop_count;
  int unsigned tx_eop_count;
  int unsigned tx_sof_count;

  // RX statistics
  int unsigned rx_byte_count;
  int unsigned rx_sop_count;
  int unsigned rx_eop_count;
  int unsigned rx_error_count;

  // USB bus statistics
  int unsigned bus_segment_count;
  int unsigned bus_dpdm_10_count;
  int unsigned bus_dpdm_01_count;
  int unsigned bus_se0_count;
  int unsigned bus_se1_count;
  int unsigned bus_unknown_count;

  // Error statistics
  int unsigned total_errors;
  int unsigned total_warnings;

  // Packet tracking
  bit tx_packet_active;
  bit rx_packet_active;

  speed_t tx_packet_speed;
  speed_t rx_packet_speed;

  // Constructor
  function new(
    string name = "usb_phy_scb",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    phy_fifo = new("phy_fifo", this);
    rx_fifo  = new("rx_fifo", this);
    bus_fifo = new("bus_fifo", this);

    tx_handshake_count = 0;
    tx_sop_count       = 0;
    tx_eop_count       = 0;
    tx_sof_count       = 0;

    rx_byte_count      = 0;
    rx_sop_count       = 0;
    rx_eop_count       = 0;
    rx_error_count     = 0;

    bus_segment_count  = 0;
    bus_dpdm_10_count  = 0;
    bus_dpdm_01_count  = 0;
    bus_se0_count      = 0;
    bus_se1_count      = 0;
    bus_unknown_count  = 0;

    total_errors       = 0;
    total_warnings     = 0;

    tx_packet_active   = 0;
    rx_packet_active   = 0;

  endfunction

  // Run phase
  task run_phase(uvm_phase phase);

    `uvm_info(
      "USB_SCB",
      "USB PHY scoreboard started",
      UVM_LOW
    )

    fork
      process_tx();
      process_rx();
      process_bus();
    join

  endtask

  // TX processing
  task process_tx();

    forever begin

      phy_fifo.get(tx_tr);

      if (tx_tr == null) begin
        total_errors++;
        `uvm_error("USB_SCB", "NULL TX transaction")
        continue;
      end

      if (!(tx_tr.valid && tx_tr.ready)) begin
        total_errors++;
        `uvm_error(
          "USB_SCB",
          "TX monitor published a non-handshake transaction"
        )
        continue;
      end

      tx_handshake_count++;

      if (tx_tr.sop) begin

        tx_sop_count++;

        if (tx_packet_active) begin
          total_errors++;
          `uvm_error(
            "USB_SCB",
            "TX SOP received while previous packet is active"
          )
        end

        tx_packet_active = 1;
        tx_packet_speed  = tx_tr.speed;

      end
      else if (!tx_packet_active) begin

        total_warnings++;

        `uvm_warning(
          "USB_SCB",
          "TX data received without preceding SOP"
        )

        tx_packet_active = 1;
        tx_packet_speed  = tx_tr.speed;

      end

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

      if (tx_tr.sof_packet)
        tx_sof_count++;

      if (tx_tr.eop) begin

        tx_eop_count++;
        tx_packet_active = 0;

      end

      `uvm_info(
        "USB_SCB_TX",
        tx_tr.convert2string(),
        UVM_MEDIUM
      )

    end

  endtask

  // RX processing
  task process_rx();

    forever begin

      rx_fifo.get(rx_tr);

      if (rx_tr == null) begin
        total_errors++;
        `uvm_error("USB_SCB", "NULL RX transaction")
        continue;
      end

      if (!rx_tr.valid) begin
        total_errors++;
        `uvm_error(
          "USB_SCB",
          "RX monitor published transaction without RxValid"
        )
        continue;
      end

      rx_byte_count++;

      if (rx_tr.sop) begin

        rx_sop_count++;

        if (rx_packet_active) begin
          total_errors++;
          `uvm_error(
            "USB_SCB",
            "RX SOP received while previous packet is active"
          )
        end

        rx_packet_active = 1;
        rx_packet_speed  = rx_tr.speed;

      end
      else if (!rx_packet_active) begin

        total_warnings++;

        `uvm_warning(
          "USB_SCB",
          "RX byte received without preceding RX SOP"
        )

        rx_packet_active = 1;
        rx_packet_speed  = rx_tr.speed;

      end

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

      if (rx_tr.eop) begin

        rx_eop_count++;
        rx_packet_active = 0;

      end

      if (rx_tr.rx_error ||
          rx_tr.rx_stuff_err ||
          rx_tr.rx_align_err ||
          rx_tr.rx_line_err ||
          rx_tr.rx_sync_err) begin

        rx_error_count++;
        total_errors++;

        `uvm_error(
          "USB_SCB",
          $sformatf(
            "RX error: DATA=0x%02h RXERR=%0b STUFF=%0b ALIGN=%0b LINE=%0b SYNC=%0b",
            rx_tr.data,
            rx_tr.rx_error,
            rx_tr.rx_stuff_err,
            rx_tr.rx_align_err,
            rx_tr.rx_line_err,
            rx_tr.rx_sync_err
          )
        )

      end

      if (rx_tr.rx_bus_reset) begin

        `uvm_info(
          "USB_SCB",
          "RX bus reset indication observed",
          UVM_MEDIUM
        )

      end

      `uvm_info(
        "USB_SCB_RX",
        rx_tr.convert2string(),
        UVM_MEDIUM
      )

    end

  endtask

  // Physical USB bus processing
  task process_bus();

    forever begin

      bus_fifo.get(bus_tr);

      if (bus_tr == null) begin
        total_errors++;
        `uvm_error("USB_SCB", "NULL USB bus transaction")
        continue;
      end

      bus_segment_count++;

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
            "USB_SCB",
            "SE1 observed on USB bus"
          )
        end

        default: begin
          bus_unknown_count++;
          total_warnings++;

          `uvm_warning(
            "USB_SCB",
            "Unknown/X/Z USB bus state observed"
          )
        end

      endcase

      `uvm_info(
        "USB_SCB_BUS",
        $sformatf(
          "BUS ID=%0d SPEED=%0d DP=%b DM=%b OE=%0b DURATION=%0d",
          bus_tr.transaction_id,
          bus_tr.speed,
          bus_tr.dp,
          bus_tr.dm,
          bus_tr.drive_enable,
          bus_tr.duration_cycles
        ),
        UVM_HIGH
      )

    end

  endtask

  // Check phase
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

  // Report phase
  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("USB_SCB",
      "==============================================",
      UVM_NONE)

    `uvm_info("USB_SCB",
      "       USB 2.0 PHY SCOREBOARD REPORT",
      UVM_NONE)

    `uvm_info("USB_SCB",
      "==============================================",
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("TX HANDSHAKES       : %0d", tx_handshake_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("TX SOP              : %0d", tx_sop_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("TX EOP              : %0d", tx_eop_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("TX SOF              : %0d", tx_sof_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      "----------------------------------------------",
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("RX VALID BYTES      : %0d", rx_byte_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("RX SOP              : %0d", rx_sop_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("RX EOP              : %0d", rx_eop_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("RX ERROR EVENTS     : %0d", rx_error_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      "----------------------------------------------",
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("BUS SEGMENTS        : %0d", bus_segment_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("BUS DPDM=10         : %0d", bus_dpdm_10_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("BUS DPDM=01         : %0d", bus_dpdm_01_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("BUS SE0             : %0d", bus_se0_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("BUS SE1             : %0d", bus_se1_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("BUS UNKNOWN         : %0d", bus_unknown_count),
      UVM_NONE)

    `uvm_info("USB_SCB",
      "----------------------------------------------",
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("TOTAL ERRORS        : %0d", total_errors),
      UVM_NONE)

    `uvm_info("USB_SCB",
      $sformatf("TOTAL WARNINGS      : %0d", total_warnings),
      UVM_NONE)

    `uvm_info("USB_SCB",
      "==============================================",
      UVM_NONE)

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
        $sformatf("SCOREBOARD ERRORS = %0d", total_errors)
      )

    end

  endfunction

endclass

