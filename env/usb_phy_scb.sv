class usb_phy_scb extends uvm_scoreboard;

  `uvm_component_utils(usb_phy_scb)
  virtual usb_phy_if #(8) vif;


  // ==================================================
  // ANALYSIS FIFOS
  // ==================================================

  uvm_tlm_analysis_fifo #(phy_transaction) phy_fifo;
  uvm_tlm_analysis_fifo #(phy_transaction) txd_fifo;
  uvm_tlm_analysis_fifo #(phy_transaction) rxd_fifo;
  phy_transaction expected_txd[$];
  int unsigned serial_tx_bytes_checked;
  int unsigned slave_rx_bytes_driven;
  bit allow_underrun;
  int unsigned tx_underrun_packets;

  uvm_tlm_analysis_fifo #(phy_transaction) rx_fifo;

  uvm_tlm_analysis_fifo #(phy_transaction) rx_status_fifo;

  uvm_tlm_analysis_fifo #(usb_bfm_transaction) bus_fifo;
  uvm_tlm_analysis_fifo #(usb_bfm_transaction) expected_rx_fifo;
  byte unsigned rx_expected_bytes[$];
  int unsigned rx_expected_lengths[$];
  int unsigned rx_bytes_remaining;
  int unsigned rx_expected_packet_count;
  bit require_expected_rx = 0;


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
  bit expect_rx_error,expect_stuff_err,expect_line_err,expect_sync_err;
  bit prev_rx_error,prev_stuff_err,prev_align_err,prev_line_err;
  bit prev_sync_err,prev_bus_reset;


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
    if (!uvm_config_db#(virtual usb_phy_if #(8))::get(this,"","vif",vif))
      `uvm_fatal("USB_SCB","Missing PHY interface for reset observation")


    // Create FIFOs
    phy_fifo       = new("phy_fifo", this);
    txd_fifo       = new("txd_fifo", this);
    rxd_fifo       = new("rxd_fifo", this);
    rx_fifo        = new("rx_fifo", this);
    rx_status_fifo = new("rx_status_fifo", this);
    bus_fifo       = new("bus_fifo", this);
    expected_rx_fifo = new("expected_rx_fifo", this);


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
    rx_bytes_remaining = 0;
    rx_expected_packet_count = 0;

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
      process_serial_tx();
      process_slave_rx();

      process_rx();

      process_rx_status();

      process_bus();

      process_expected_rx();
      process_reset();
      process_interface_contract();

    join

  endtask

  // Pin-level top integration checks. These use top outputs, independent of
  // the internal RX controller and of the TX reference-symbol generator.
  task process_interface_contract();
    logic [1:0] idle_level;
    forever begin
      @(vif.cb_mon);
      if (vif.cb_mon.rst_n!==1'b1) continue;
      if ((vif.cb_mon.rx_sop || vif.cb_mon.rx_eop) &&
          vif.cb_mon.RxValid!==1'b1) begin
        total_errors++;
        `uvm_error("USB_SCB_PINS","RX packet marker without RxValid")
      end
      if (vif.cb_mon.RxValid && !vif.cb_mon.RxActive) begin
        total_errors++;
        `uvm_error("USB_SCB_PINS","RxValid outside RxActive")
      end
      if (vif.cb_mon.RxError !==
          ((vif.cb_mon.rx_stuff_err || vif.cb_mon.rx_line_err) &&
           vif.cb_mon.RxActive)) begin
        total_errors++;
        `uvm_error("USB_SCB_PINS","RxError disagrees with active stuff/line status (ALIGN_IN_RXERROR=0)")
      end
      if (vif.cb_mon.usb_speed==HS && vif.cb_mon.rx_bus_reset) begin
        total_errors++;
        `uvm_error("USB_SCB_PINS","Bus reset incorrectly detected at HS")
      end
      idle_level=(vif.cb_mon.usb_speed==LS) ? 2'b01 :
                 (vif.cb_mon.usb_speed==HS) ? 2'b00 : 2'b10;
      if (vif.cb_mon.tx_valid===1'b0 &&
          {vif.cb_mon.dp,vif.cb_mon.dm} !== idle_level) begin
        total_errors++;
        `uvm_error("USB_SCB_PINS",$sformatf("TX idle pins=%b expected=%b at speed=%0d",
                   {vif.cb_mon.dp,vif.cb_mon.dm},idle_level,vif.cb_mon.usb_speed))
      end
    end
  endtask

  // A newly asserted asynchronous reset cancels the packet being received or
  // transmitted. The next packet must start with a fresh SOP and expectations.
  task process_reset();
    forever begin
      @(negedge vif.rst_n);
      expected_txd.delete();
      rx_expected_bytes.delete();
      rx_expected_lengths.delete();
      rx_bytes_remaining = 0;
      tx_packet_active = 0;
      rx_packet_active = 0;
      prev_rx_error=0;prev_stuff_err=0;prev_align_err=0;
      prev_line_err=0;prev_sync_err=0;prev_bus_reset=0;
      `uvm_info("USB_SCB_RESET","Canceled in-flight packet expectations",UVM_MEDIUM)
    end
  endtask

  // The external device publishes expected bytes before driving first SYNC.
  task process_expected_rx();
    usb_bfm_transaction exp_tr;
    forever begin
      expected_rx_fifo.get(exp_tr);
      if (exp_tr.expected_rx_bytes.size() == 0)
        `uvm_fatal("USB_SCB", "Empty expected RX packet")
      rx_expected_lengths.push_back(exp_tr.expected_rx_bytes.size());
      `uvm_info("USB_RX_EXPECT",$sformatf(
        "Peer queued RX packet id=%0d speed=%s length=%0d",
        exp_tr.transaction_id,exp_tr.speed.name(),exp_tr.expected_rx_bytes.size()),UVM_LOW)
      foreach (exp_tr.expected_rx_bytes[i]) begin
        rx_expected_bytes.push_back(exp_tr.expected_rx_bytes[i]);
        `uvm_info("USB_RX_EXPECT",$sformatf(
          "  byte[%0d] expected DataOut=0x%02h SOP=%0b EOP=%0b",
          i,exp_tr.expected_rx_bytes[i],i==0,
          i==exp_tr.expected_rx_bytes.size()-1),UVM_MEDIUM)
      end
      rx_expected_packet_count++;
    end
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
      expected_txd.push_back(tx_tr);
      `uvm_info("USB_TX_SIE",$sformatf(
        "SIE->PHY accepted byte id=%0d speed=%s data=0x%02h SOP=%0b EOP=%0b SOF=%0b",
        tx_tr.transaction_id,tx_tr.speed.name(),tx_tr.data,
        tx_tr.sop,tx_tr.eop,tx_tr.sof_packet),UVM_LOW)


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

  // Compare bytes reconstructed by the USB slave from the physical TX pins
  // with the bytes actually accepted at the DUT's SIE interface.
  task process_serial_tx();
    phy_transaction decoded, expected;
    bit byte_matches;
    forever begin
      txd_fifo.get(decoded);
      if (expected_txd.size() == 0) begin
        total_errors++;
        `uvm_error("USB_SCB_TXD","Slave decoded an unexpected TX byte")
        continue;
      end
      expected = expected_txd.pop_front();
      byte_matches = decoded.data === expected.data &&
                     decoded.speed == expected.speed &&
                     decoded.sop == expected.sop &&
                     (decoded.eop == expected.eop ||
                      (allow_underrun && decoded.eop && !expected.eop));
      `uvm_info("USB_TX_COMPARE",$sformatf(
        "byte[%0d] %s expected=0x%02h actual_wire=0x%02h speed_exp=%s speed_actual=%s SOP_exp/actual=%0b/%0b EOP_exp/actual=%0b/%0b",
        serial_tx_bytes_checked,byte_matches ? "MATCH" : "MISMATCH",
        expected.data,decoded.data,
        expected.speed.name(),decoded.speed.name(),expected.sop,decoded.sop,
        expected.eop,decoded.eop),UVM_LOW)
      if (!byte_matches) begin
        total_errors++;
        `uvm_error("USB_SCB_TXD",$sformatf(
          "byte[%0d] expected=0x%02h actual=0x%02h speed_exp/actual=%s/%s SOP_exp/actual=%0b/%0b EOP_exp/actual=%0b/%0b",
          serial_tx_bytes_checked,expected.data,decoded.data,
          expected.speed.name(),decoded.speed.name(),expected.sop,decoded.sop,
          expected.eop,decoded.eop))
      end
      if (allow_underrun && decoded.eop && !expected.eop) begin
        tx_underrun_packets++;
        tx_packet_active=0;
      end
      serial_tx_bytes_checked++;
    end
  endtask

  task process_slave_rx();
    phy_transaction sent;
    forever begin
      rxd_fifo.get(sent);
      slave_rx_bytes_driven++;
      `uvm_info("USB_SLAVE_SENT",$sformatf(
        "Peer->PHY scheduled byte[%0d] speed=%s data=0x%02h SOP=%0b EOP=%0b",
        slave_rx_bytes_driven-1,sent.speed.name(),sent.data,sent.sop,sent.eop),UVM_LOW)
    end
  endtask


  // ==================================================
  // RX BYTE PROCESSING
  // ==================================================

  task process_rx();

    byte unsigned expected_byte;
    bit have_expected;

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
      have_expected = 0;

      if (!rx_packet_active && rx_bytes_remaining == 0) begin
        if (rx_expected_lengths.size() != 0)
          rx_bytes_remaining = rx_expected_lengths.pop_front();
        else if (require_expected_rx) begin
          total_errors++;
          `uvm_error("USB_SCB_RX", "Received byte without a driven slave packet")
        end
      end
      if (!rx_packet_active && !rx_tr.sop) begin
        total_errors++;
        `uvm_error("USB_SCB_RX", "Expected rx_sop on first packet byte")
      end else if (rx_packet_active && rx_tr.sop) begin
        total_errors++;
        `uvm_error("USB_SCB_RX", "Unexpected rx_sop inside packet")
      end
      if (rx_expected_bytes.size() != 0) begin
        expected_byte = rx_expected_bytes.pop_front();
        have_expected = 1;
        if (rx_tr.data !== expected_byte) begin
          total_errors++;
          `uvm_error("USB_SCB_RX", $sformatf(
            "byte id=%0d expected DataOut=0x%02h actual DataOut=0x%02h",
            rx_tr.transaction_id,expected_byte,rx_tr.data))
        end
      end
      if (rx_bytes_remaining > 0) rx_bytes_remaining--;
      if (have_expected)
        `uvm_info("USB_RX_COMPARE",$sformatf(
          "byte id=%0d %s speed=%s expected=0x%02h actual=0x%02h SOP_exp/actual=%0b/%0b EOP_exp/actual=%0b/%0b RxError=%0b",
          rx_tr.transaction_id,
          (rx_tr.data === expected_byte &&
           rx_tr.eop == (rx_bytes_remaining==0) &&
           rx_tr.sop == !rx_packet_active) ? "MATCH" : "MISMATCH",
          rx_tr.speed.name(),expected_byte,rx_tr.data,
          !rx_packet_active,rx_tr.sop,
          rx_bytes_remaining==0,rx_tr.eop,rx_tr.rx_error),UVM_LOW)
      else
        `uvm_info("USB_RX_UNSCORED",$sformatf(
          "byte id=%0d actual=0x%02h SOP=%0b EOP=%0b; no expected byte (fault or unexpected output)",
          rx_tr.transaction_id,rx_tr.data,rx_tr.sop,rx_tr.eop),UVM_LOW)
      if ((require_expected_rx || rx_expected_packet_count != 0) &&
          rx_tr.eop != (rx_bytes_remaining == 0)) begin
        total_errors++;
        `uvm_error("USB_SCB_RX", "rx_eop does not tag the last expected byte")
      end


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

      `uvm_info("USB_RX_STATUS",$sformatf(
        "status id=%0d actual RxError/stuff/align/line/sync/bus_reset=%0b/%0b/%0b/%0b/%0b/%0b configured_expected RxError/stuff/line/sync=%0b/%0b/%0b/%0b",
        rx_status_tr.transaction_id,rx_status_tr.rx_error,
        rx_status_tr.rx_stuff_err,rx_status_tr.rx_align_err,
        rx_status_tr.rx_line_err,rx_status_tr.rx_sync_err,
        rx_status_tr.rx_bus_reset,expect_rx_error,expect_stuff_err,
        expect_line_err,expect_sync_err),UVM_LOW)


      if (rx_status_tr.rx_error && !prev_rx_error) begin

        rx_error_count++;
        if (!expect_rx_error) begin
          total_errors++;
          `uvm_error("USB_SCB_RX_STATUS","Unexpected RxError")
        end

      end


      if (rx_status_tr.rx_stuff_err && !prev_stuff_err) begin

        rx_stuff_error_count++;

        if (!expect_stuff_err) begin
          total_errors++;
          `uvm_error("USB_SCB_RX_STATUS","Unexpected rx_stuff_err")
        end

      end


      if (rx_status_tr.rx_align_err && !prev_align_err) begin

        rx_align_error_count++;

        `uvm_info(
          "USB_SCB_RX_STATUS",
          "RX alignment error observed",
          UVM_MEDIUM
        )

      end


      if (rx_status_tr.rx_line_err && !prev_line_err) begin

        rx_line_error_count++;

        if (!expect_line_err) begin
          total_errors++;
          `uvm_error("USB_SCB_RX_STATUS","Unexpected rx_line_err")
        end

      end


      if (rx_status_tr.rx_sync_err && !prev_sync_err) begin

        rx_sync_error_count++;

        if (!expect_sync_err) begin
          total_errors++;
          `uvm_error("USB_SCB_RX_STATUS","Unexpected rx_sync_err")
        end

      end


      if (rx_status_tr.rx_bus_reset && !prev_bus_reset) begin

        rx_bus_reset_count++;

        `uvm_info(
          "USB_SCB_RX_STATUS",
          "USB bus reset detected",
          UVM_MEDIUM
        )

      end

      prev_rx_error=rx_status_tr.rx_error;
      prev_stuff_err=rx_status_tr.rx_stuff_err;
      prev_align_err=rx_status_tr.rx_align_err;
      prev_line_err=rx_status_tr.rx_line_err;
      prev_sync_err=rx_status_tr.rx_sync_err;
      prev_bus_reset=rx_status_tr.rx_bus_reset;

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
    if (expected_txd.size()!=0) begin
      total_errors++;
      `uvm_error("USB_SCB_TXD",$sformatf("Slave failed to decode %0d accepted TX bytes",expected_txd.size()))
    end

    if (rx_expected_bytes.size() != 0 || rx_expected_lengths.size() != 0 ||
        rx_bytes_remaining != 0) begin
      total_errors++;
      `uvm_error("USB_SCB_RX", $sformatf(
        "Missing RX bytes: remaining=%0d queued=%0d",
        rx_bytes_remaining, rx_expected_bytes.size()))
    end


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
    `uvm_info("USB_SCB",$sformatf("SERIAL TX BYTES DECODED/CHECKED : %0d",
              serial_tx_bytes_checked),UVM_NONE)
    `uvm_info("USB_SCB",$sformatf("SLAVE RX BYTES DRIVEN           : %0d",
              slave_rx_bytes_driven),UVM_NONE)
    `uvm_info("USB_SCB",$sformatf("TX UNDERRUN PACKETS              : %0d",
              tx_underrun_packets),UVM_NONE)

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
