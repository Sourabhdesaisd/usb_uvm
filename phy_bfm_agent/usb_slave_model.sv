// USB PHY external slave/peer: packet, reset, response, TX wire oracle and active agent.
// All peer behavior is defined in this source file.

// Independent bus peer for SIE -> PHY -> USB pins. Captures accepted SIE
// packets, builds a USB symbol stream and checks every driven bit slot.
class usb_tx_expected_packet extends uvm_object;
  `uvm_object_utils(usb_tx_expected_packet)
  byte unsigned bytes[$];
  speed_t speed;
  bit sof;
  function new(string name="usb_tx_expected_packet"); super.new(name); endfunction
endclass

class usb_tx_wire_checker extends uvm_component;
  `uvm_component_utils(usb_tx_wire_checker)
  virtual usb_phy_if #(8) vif;
  // Like UART's txd_rcvd_ap: bytes reconstructed from the DUT's serial pins.
  uvm_analysis_port #(phy_transaction) txd_rcvd_ap;
  usb_tx_expected_packet building;
  usb_tx_expected_packet pending[$];
  logic [1:0] observed[$]; // Preserve X/Z on the physical pins.
  int cycles_in_packet;
  int packets_checked;
  int stuffed_bits_checked;
  int long_eop_checked;
  int ready_stall_cycles;
  bit allow_underrun; // Enable only in the deliberate FIFO underrun test.
  int underrun_packets_checked;
  bit stalled_last_cycle;
  bit [7:0] stalled_data;
  bit stalled_sop, stalled_eop;

  function new(string name="usb_tx_wire_checker", uvm_component parent=null);
    super.new(name,parent);
    txd_rcvd_ap = new("txd_rcvd_ap",this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb_phy_if #(8))::get(this,"","vif",vif))
      `uvm_fatal("TX_WIRE","Missing usb_phy_if")
  endfunction

  function automatic int clocks_per_bit(speed_t speed);
    case (speed)
      LS: return 320;
      FS: return 40;
      HS: return 1;
      default: return 0;
    endcase
  endfunction

  function automatic bit [1:0] symbol_level(bit j, speed_t speed);
    if (speed == LS) return j ? 2'b01 : 2'b10;
    return j ? 2'b10 : 2'b01;
  endfunction

  function void build_expected(usb_tx_expected_packet pkt,
                               ref logic [1:0] symbols[$]);
    bit level_j;
    int ones;
    bit data_bit;
    int n_sync;
    symbols.delete();
    level_j = 1;
    ones = 0;
    n_sync = pkt.speed == HS ? 32 : 8;
    // NRZI begins at idle J. SYNC is (n_sync-1) zeros followed by 1.
    for (int i=0; i<n_sync; i++) begin
      data_bit = i == n_sync-1;
      if (!data_bit) level_j = !level_j;
      symbols.push_back(symbol_level(level_j,pkt.speed));
      ones = data_bit ? ones+1 : 0;
    end
    foreach (pkt.bytes[i]) begin
      for (int b=0; b<8; b++) begin
        data_bit = pkt.bytes[i][b];
        if (!data_bit) level_j = !level_j;
        symbols.push_back(symbol_level(level_j,pkt.speed));
        ones = data_bit ? ones+1 : 0;
        if (ones == 6) begin
          level_j = !level_j;
          symbols.push_back(symbol_level(level_j,pkt.speed));
          stuffed_bits_checked++;
          ones = 0;
        end
      end
    end
    if (pkt.speed == HS) begin
      if (pkt.sof) long_eop_checked++;
      repeat (pkt.sof ? 40 : 8)
        symbols.push_back(symbol_level(!level_j,pkt.speed));
    end else begin
      symbols.push_back(2'b00);
      symbols.push_back(2'b00);
      symbols.push_back(symbol_level(1,pkt.speed));
    end
  endfunction

  function void compare_packet();
    usb_tx_expected_packet pkt;
    logic [1:0] expected[$];
    int period;
    bit packet_match;
    if (pending.size() == 0) begin
      if (allow_underrun && building != null) begin
        pending.push_back(building);
        building = null;
        underrun_packets_checked++;
      end else begin
        `uvm_error("TX_WIRE","DUT drove a packet without accepted SIE SOP/EOP")
        observed.delete();
        return;
      end
    end
    pkt = pending.pop_front();
    packet_match = 1;
    period = clocks_per_bit(pkt.speed);
    build_expected(pkt,expected);
    if (cycles_in_packet != expected.size()*period) begin
      packet_match = 0;
      `uvm_error("TX_WIRE",$sformatf("TX duration=%0d clocks expected=%0d speed=%0d",cycles_in_packet,expected.size()*period,pkt.speed))
    end
    if (observed.size() != expected.size()) begin
      packet_match = 0;
      `uvm_error("TX_WIRE",$sformatf("TX symbols=%0d expected=%0d",observed.size(),expected.size()))
    end
    foreach (observed[i]) begin
      if (i < expected.size() && observed[i] !== expected[i]) begin
        packet_match = 0;
        `uvm_error("TX_WIRE",$sformatf("TX symbol %0d got {DP,DM}=%b expected=%b",i,observed[i],expected[i]))
      end
    end
    if (!decode_serial_bytes(pkt)) packet_match = 0;
    packets_checked++;
    `uvm_info("USB_TX_WIRE",$sformatf(
      "packet %0d %s speed=%s bytes=%0d symbols_expected=%0d symbols_actual=%0d cycles_expected=%0d cycles_actual=%0d",
      packets_checked,packet_match ? "MATCH" : "MISMATCH",pkt.speed.name(),
      pkt.bytes.size(),expected.size(),observed.size(),
      expected.size()*period,cycles_in_packet),UVM_LOW)
    observed.delete();
  endfunction

  // Decode the observed pins independently of the expected symbol builder.
  // SYNC and EOP are checked above; recover payload by NRZI and remove each
  // mandatory stuffed zero, including one after the last payload bit.
  function bit decode_serial_bytes(usb_tx_expected_packet pkt);
    byte unsigned decoded[$];
    byte unsigned byte_value;
    phy_transaction tr;
    bit previous_j, current_j, decoded_bit;
    int ones, bits_in_byte, sync_length, eop_length, stop_index;
    bit decode_ok;
    decode_ok = 1;
    sync_length = pkt.speed == HS ? 32 : 8;
    eop_length = pkt.speed == HS ? (pkt.sof ? 40 : 8) : 3;
    stop_index = observed.size() - eop_length;
    if (stop_index < sync_length) begin
      `uvm_error("TX_DECODE","Packet too short for SYNC and EOP")
      return 0;
    end
    previous_j = observed[sync_length-1] == symbol_level(1,pkt.speed);
    ones = 1; // The final SYNC bit is a one.
    bits_in_byte = 0;
    byte_value = '0;
    for (int i=sync_length; i<stop_index; i++) begin
      if (observed[i] !== symbol_level(0,pkt.speed) &&
          observed[i] !== symbol_level(1,pkt.speed)) begin
        decode_ok = 0;
        `uvm_error("TX_DECODE",$sformatf("Illegal data symbol at slot %0d",i))
        continue;
      end
      current_j = observed[i] == symbol_level(1,pkt.speed);
      decoded_bit = current_j == previous_j;
      previous_j = current_j;
      if (ones == 6) begin
        if (decoded_bit !== 1'b0) begin
          decode_ok = 0;
          `uvm_error("TX_DECODE",$sformatf("Missing stuffed zero at symbol %0d",i))
        end
        ones = 0;
        continue;
      end
      byte_value[bits_in_byte] = decoded_bit;
      bits_in_byte++;
      ones = decoded_bit ? ones+1 : 0;
      if (bits_in_byte == 8) begin
        decoded.push_back(byte_value);
        byte_value = '0;
        bits_in_byte = 0;
      end
    end
    if (bits_in_byte != 0 || decoded.size() != pkt.bytes.size()) begin
      decode_ok = 0;
      `uvm_error("TX_DECODE",$sformatf("Decoded %0d bytes and %0d residual bits; SIE wrote %0d bytes",
                 decoded.size(),bits_in_byte,pkt.bytes.size()))
    end
    foreach (decoded[i]) begin
      if (i < pkt.bytes.size() && decoded[i] !== pkt.bytes[i]) begin
        decode_ok = 0;
        `uvm_error("TX_DECODE",$sformatf("Serial byte %0d got %02h expected %02h",
                   i,decoded[i],pkt.bytes[i]))
      end
      tr = phy_transaction::type_id::create($sformatf("serial_tx_%0d",i));
      tr.speed = pkt.speed;
      tr.data = decoded[i];
      tr.valid = 1;
      tr.sop = i==0;
      tr.eop = i==decoded.size()-1;
      txd_rcvd_ap.write(tr);
    end
    return decode_ok;
  endfunction

  task run_phase(uvm_phase phase);
    bit previous_valid;
    int period;
    forever begin
      @(vif.cb_mon);
      if (vif.cb_mon.rst_n !== 1'b1) begin
        building = null;
        pending.delete();
        observed.delete();
        cycles_in_packet = 0;
        previous_valid = 0;
        stalled_last_cycle = 0;
        continue;
      end
      if (stalled_last_cycle &&
          (vif.cb_mon.sie_valid !== 1'b1 ||
           vif.cb_mon.sie_data !== stalled_data ||
           vif.cb_mon.sie_sop !== stalled_sop ||
           vif.cb_mon.sie_eop !== stalled_eop))
        `uvm_error("TX_WIRE","SIE changed a byte while sie_ready was low")
      stalled_last_cycle = vif.cb_mon.sie_valid === 1'b1 &&
                           vif.cb_mon.sie_ready !== 1'b1;
      if (stalled_last_cycle) begin
        ready_stall_cycles++;
        stalled_data = vif.cb_mon.sie_data;
        stalled_sop = vif.cb_mon.sie_sop;
        stalled_eop = vif.cb_mon.sie_eop;
      end
      if (vif.cb_mon.sie_valid === 1'b1 && vif.cb_mon.sie_ready === 1'b1) begin
        if (vif.cb_mon.sie_sop) begin
          if (building != null)
            `uvm_error("TX_WIRE","New SIE SOP before previous EOP")
          building = usb_tx_expected_packet::type_id::create("building");
          building.speed = (vif.cb_mon.usb_speed == speed_t'(2'b11)) ?
                           FS : vif.cb_mon.usb_speed;
          building.sof = vif.cb_mon.sof_packet;
        end
        if (building == null)
          `uvm_error("TX_WIRE","SIE byte without SOP")
        else begin
          building.bytes.push_back(vif.cb_mon.sie_data);
          if (vif.cb_mon.sie_eop) begin
            pending.push_back(building);
            building = null;
          end
        end
      end
      if (vif.cb_mon.tx_valid === 1'b1) begin
        if (!previous_valid) begin
          observed.delete();
          cycles_in_packet = 0;
        end
        period = clocks_per_bit((vif.cb_mon.usb_speed == speed_t'(2'b11)) ?
                                FS : vif.cb_mon.usb_speed);
        if (period == 0)
          `uvm_error("TX_WIRE","Invalid speed during TX")
        else if ((cycles_in_packet % period) == 0)
          observed.push_back({vif.cb_mon.dp,vif.cb_mon.dm});
        cycles_in_packet++;
      end else if (previous_valid) begin
        compare_packet();
        cycles_in_packet = 0;
      end
      previous_valid = vif.cb_mon.tx_valid === 1'b1;
    end
  endtask

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (pending.size() || building != null || cycles_in_packet)
      `uvm_error("TX_WIRE",$sformatf("Unfinished TX: queued=%0d active=%0d",pending.size(),cycles_in_packet))
  endfunction
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("TX_WIRE",$sformatf("Wire packets=%0d inserted stuff bits=%0d HS SOF EOP=%0d ready stalls=%0d underruns=%0d",
              packets_checked,stuffed_bits_checked,long_eop_checked,ready_stall_cycles,underrun_packets_checked),UVM_NONE)
  endfunction
endclass

// External USB device packet on the analog receiver pins. PHY payload is
// arbitrary bytes: token/CRC interpretation belongs to the SIE, not phy_top.
class usb_slave_packet_seq extends uvm_sequence #(usb_bfm_transaction);
  `uvm_object_utils(usb_slave_packet_seq)

  typedef enum bit [1:0] {SYM_SE0, SYM_J, SYM_K, SYM_SE1} sym_t;
  speed_t packet_speed = FS;
  byte unsigned payload[$];
  bit score_packet = 1;
  int unsigned packet_id;
  int unsigned eop_se0_bits = 2; // Detector accepts 1..3 at FS/LS.
  bit inject_se1 = 0;
  bit omit_stuffed_zero = 0;
  bit break_sync = 0;
  int unsigned jitter_cycles = 0; // alternating +/- system clocks per bit
  int unsigned dribble_bits = 0; // extra identical J/K bits before FS/LS EOP
  bit hs_sof_eop = 0; // HS SOF uses forty EOP symbols rather than eight.

  function new(string name = "usb_slave_packet_seq");
    super.new(name);
  endfunction

  function automatic sym_t opposite(sym_t s);
    return s == SYM_J ? SYM_K : SYM_J;
  endfunction

  function automatic int bit_clocks(speed_t s);
    case (s)
      FS: return 40;
      LS: return 320;
      HS: return 1; // USB 2.0: 480 Mb/s at the default 480 MHz clock.
      default: return 0; // Invalid encoding.
    endcase
  endfunction

  function automatic void line_levels(sym_t s, speed_t spd,
                                      output bit p, output bit m);
    case (s)
      SYM_SE0: begin p = 0; m = 0; end
      SYM_SE1: begin p = 1; m = 1; end
      SYM_J: begin p = (spd != LS); m = (spd == LS); end
      SYM_K: begin p = (spd == LS); m = (spd != LS); end
    endcase
  endfunction

  virtual task body();
    sym_t symbols[$];
    sym_t level;
    int ones;
    bit p, m;
    usb_bfm_transaction req;

    if (!(packet_speed inside {LS, FS, HS}))
      `uvm_fatal("USB_SLAVE", "Invalid USB speed")
    if (packet_speed == HS && score_packet)
      `uvm_fatal("USB_SLAVE", "HS waveform is supported, but supplied DUT CDR has no HS RX; set score_packet=0 for line-only stimulus")
    if (payload.size() == 0)
      `uvm_fatal("USB_SLAVE", "Use at least one byte for a scored packet")
    if (jitter_cycles > 1)
      `uvm_fatal("USB_SLAVE", "This directed CDR test supports at most +/-1 system clock")
    if (dribble_bits > 6 || (packet_speed == HS && dribble_bits != 0))
      `uvm_fatal("USB_SLAVE", "Dribble option is FS/LS only (at most six bits)")

    `uvm_info("USB_PEER_PACKET",$sformatf(
      "Peer->PHY packet id=%0d speed=%s bytes=%0d scored=%0b EOP_SE0_bits=%0d HS_SOF_EOP=%0b inject_SE1=%0b omit_stuff=%0b break_sync=%0b",
      packet_id,packet_speed.name(),payload.size(),score_packet,
      eop_se0_bits,hs_sof_eop,inject_se1,omit_stuffed_zero,break_sync),UVM_LOW)
    foreach (payload[i])
      `uvm_info("USB_PEER_DATA",$sformatf(
        "Peer->PHY packet id=%0d byte[%0d] sent=0x%02h",
        packet_id,i,payload[i]),UVM_LOW)

    // FS/LS source SYNC is 8 symbols; HS source SYNC is 32 symbols.
    // The last two symbols are K,K. break_sync is an FS/LS fault injection.
    for (int i = 0; i < (packet_speed == HS ? 31 : 7); i++)
      symbols.push_back((i % 2 == 0) ? SYM_K : SYM_J);
    symbols.push_back(break_sync ? SYM_J : SYM_K);
    level = break_sync ? SYM_J : SYM_K;
    ones = break_sync ? 0 : 1; // The last valid SYNC '1' counts.

    foreach (payload[i]) begin
      for (int b = 0; b < 8; b++) begin
        if (!payload[i][b]) level = opposite(level);
        symbols.push_back(level);
        ones = payload[i][b] ? ones + 1 : 0;
        if (ones == 6) begin
          if (!omit_stuffed_zero) begin
            level = opposite(level);
            symbols.push_back(level); // Mandatory stuffed zero.
          end
          ones = 0;
        end
      end
    end
    // NRZI ones hold the final differential line level. Select a payload
    // ending in zero in the alignment test so dribble cannot imply stuffing.
    repeat (dribble_bits) symbols.push_back(level);
    if (inject_se1) symbols.push_back(SYM_SE1);
    if (packet_speed == HS) begin
      // HS EOP is an unstuffed NRZ 01111111 (40 bits for SOF):
      // a transition, followed by an identical J/K symbol run.
      repeat (hs_sof_eop ? 40 : 8) symbols.push_back(opposite(level));
    end else begin
      repeat (eop_se0_bits) symbols.push_back(SYM_SE0);
      symbols.push_back(SYM_J);
    end

    foreach (symbols[i]) begin
      req = usb_bfm_transaction::type_id::create($sformatf("sym_%0d", i));
      start_item(req);
      line_levels(symbols[i], packet_speed, p, m);
      req.speed = packet_speed;
      req.dp = p;
      req.dm = m;
      // analog_serial is derived from the resolved DP/DM bus in top_tb.
      // Do not drive it independently from the slave sequence.
      req.drive_enable = 1;
      req.duration_cycles = bit_clocks(packet_speed) +
                            ((i%2)==0 ? int'(jitter_cycles) : -int'(jitter_cycles));
      req.packet_start = (i == 0);
      req.packet_end = (i == symbols.size()-1);
      req.transaction_id = packet_id;
      if (i == 0 && score_packet)
        foreach (payload[j]) req.expected_rx_bytes.push_back(payload[j]);
      finish_item(req);
    end
  endtask
endclass

// External host holds SE0 long enough for the LS/FS bus-reset detector.
class usb_slave_reset_seq extends uvm_sequence #(usb_bfm_transaction);
  `uvm_object_utils(usb_slave_reset_seq)
  speed_t reset_speed = FS;
  int unsigned reset_cycles = 1240; // > default 1200-clk threshold
  function new(string name="usb_slave_reset_seq"); super.new(name); endfunction
  virtual task body();
    usb_bfm_transaction req;
    if (reset_speed == HS)
      `uvm_fatal("SLAVE_RESET","Bus reset detector is LS/FS only")
    req = usb_bfm_transaction::type_id::create("reset_se0");
    start_item(req);
    req.speed = reset_speed;
    req.dp = 0; req.dm = 0;
    // analog_serial is derived from the resolved DP/DM bus in top_tb.
    req.drive_enable = 1;
    req.duration_cycles = reset_cycles;
    req.idle_cycles = reset_speed == LS ? 640 : 80;
    finish_item(req);
  endtask
endclass

// React to an observed DUT TX packet. USB token/PID policy belongs to SIE;
// for PHY testing this sends a configured device packet after bus turnaround.
class usb_slave_response_seq extends uvm_sequence #(usb_bfm_transaction);
  `uvm_object_utils(usb_slave_response_seq)
  speed_t packet_speed = FS;
  byte unsigned response_bytes[$];
  int unsigned turnaround_bits = 2;
  int unsigned timeout_clocks = 1_000_000;

  function new(string name = "usb_slave_response_seq");
    super.new(name);
  endfunction

  virtual task body();
    usb_bfm_sequencer seqr;
    usb_slave_packet_seq packet;
    bit seen_tx;
    if (!$cast(seqr, m_sequencer) || seqr.bus_vif == null)
      `uvm_fatal("SLAVE_RESP", "USB bus sequencer/interface missing")
    if (!(packet_speed inside {LS, FS}))
      `uvm_fatal("SLAVE_RESP", "HS RX is out of scope for this CDR")

    seen_tx = 0;
    for (int t = 0; t < timeout_clocks; t++) begin
      @(posedge seqr.bus_vif.clk);
      if (seqr.bus_vif.phy_tx_valid === 1'b1) begin
        seen_tx = 1;
        break;
      end
    end
    if (!seen_tx) `uvm_fatal("SLAVE_RESP", "Timed out waiting for host TX")

    for (int t = 0; t < timeout_clocks; t++) begin
      @(posedge seqr.bus_vif.clk);
      if (seqr.bus_vif.phy_tx_valid === 1'b0) break;
      if (t == timeout_clocks-1)
        `uvm_fatal("SLAVE_RESP", "Host TX never released the bus")
    end
    repeat (turnaround_bits * ((packet_speed == LS) ? 320 : 40))
      @(posedge seqr.bus_vif.clk);

    packet = usb_slave_packet_seq::type_id::create("response_packet");
    packet.packet_speed = packet_speed;
    foreach (response_bytes[i]) packet.payload.push_back(response_bytes[i]);
    packet.start(seqr);
  endtask
endclass

// UART-style active slave: drives the RX pins through the bus driver and
// receives/decodes DUT TX pins through the independent wire checker.
class usb_slave_model extends usb_bfm_agent;
  `uvm_component_utils(usb_slave_model)

  usb_tx_wire_checker tx_wire_checker;
  uvm_tlm_analysis_fifo #(phy_transaction) decoded_txd_fifo;
  uvm_tlm_analysis_fifo #(usb_bfm_transaction) driven_rxd_fifo;
  // Correspond to UART's txd_rcvd_ap and rxd_sent_ap.
  uvm_analysis_port #(phy_transaction) txd_rcvd_ap;
  uvm_analysis_port #(phy_transaction) rxd_sent_ap;

  function new(string name="usb_slave_model",uvm_component parent=null);
    super.new(name,parent);
    txd_rcvd_ap = new("txd_rcvd_ap",this);
    rxd_sent_ap = new("rxd_sent_ap",this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    decoded_txd_fifo = new("decoded_txd_fifo",this);
    driven_rxd_fifo = new("driven_rxd_fifo",this);
    uvm_config_db#(virtual usb_phy_if #(8))::set(
      this,"tx_wire_checker","vif",cfg.phy_vif);
    tx_wire_checker = usb_tx_wire_checker::type_id::create(
      "tx_wire_checker",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    tx_wire_checker.txd_rcvd_ap.connect(decoded_txd_fifo.analysis_export);
    if (driver != null)
      driver.expected_rx_port.connect(driven_rxd_fifo.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    fork
      forever begin
        phy_transaction txd_byte;
        decoded_txd_fifo.get(txd_byte);
        txd_rcvd_ap.write(txd_byte);
      end
      forever begin
        usb_bfm_transaction packet;
        phy_transaction rxd_byte;
        driven_rxd_fifo.get(packet);
        foreach (packet.expected_rx_bytes[i]) begin
          rxd_byte=phy_transaction::type_id::create("rxd_byte");
          rxd_byte.speed=packet.speed;
          rxd_byte.data=packet.expected_rx_bytes[i];
          rxd_byte.valid=1;
          rxd_byte.sop=i==0;
          rxd_byte.eop=i==packet.expected_rx_bytes.size()-1;
          rxd_sent_ap.write(rxd_byte);
        end
      end
    join
  endtask

  // The same two simple user-facing operations as the UART slave model:
  // queue a packet toward the DUT or respond after DUT TX bus release.
  task send_packet(input byte unsigned bytes[$],
                   input int unsigned se0_bits=2);
    usb_slave_packet_seq packet;
    if (sequencer == null) `uvm_fatal("USB_SLAVE","Active slave required")
    packet=usb_slave_packet_seq::type_id::create("slave_packet");
    packet.packet_speed=cfg.speed;
    packet.eop_se0_bits=se0_bits;
    foreach (bytes[i]) packet.payload.push_back(bytes[i]);
    packet.start(sequencer);
  endtask

  // Optional specification-level HS line stimulus. It is intentionally
  // unscored: phy_top's supplied LS/FS CDR produces no HS RX bit strobe.
  task send_hs_line_packet(input byte unsigned bytes[$], input bit sof_eop=0);
    usb_slave_packet_seq packet;
    if (sequencer == null) `uvm_fatal("USB_SLAVE","Active slave required")
    if (cfg.speed != HS) `uvm_fatal("USB_SLAVE","Set PHY speed to HS while idle")
    packet=usb_slave_packet_seq::type_id::create("hs_line_packet");
    packet.packet_speed=HS;
    packet.score_packet=0;
    packet.hs_sof_eop=sof_eop;
    foreach (bytes[i]) packet.payload.push_back(bytes[i]);
    packet.start(sequencer);
  endtask

  task respond_after_tx(input byte unsigned bytes[$]);
    usb_slave_response_seq response;
    if (sequencer == null) `uvm_fatal("USB_SLAVE","Active slave required")
    response=usb_slave_response_seq::type_id::create("slave_response");
    response.packet_speed=cfg.speed;
    foreach (bytes[i]) response.response_bytes.push_back(bytes[i]);
    response.start(sequencer);
  endtask
endclass

