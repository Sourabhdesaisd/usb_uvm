
class usb_bfm_transaction extends uvm_sequence_item;

  // --------------------------------------------------
  // USB operating speed
  // --------------------------------------------------

  rand speed_t speed;


  // --------------------------------------------------
  // USB bus line states
  // --------------------------------------------------

  // Four-state variables preserve X/Z values observed
  // on the resolved DP/DM bus.
  rand logic dp;
  rand logic dm;


  // --------------------------------------------------
  // External BFM control
  // --------------------------------------------------

  rand bit drive_enable;


  // --------------------------------------------------
  // CDR input
  // --------------------------------------------------

  // Intentionally NOT randomized independently.
  // The sequence/model must assign this consistently
  // with the CDR architecture.
  bit analog_serial;


  // --------------------------------------------------
  // Segment timing
  // --------------------------------------------------

  rand int unsigned duration_cycles;
  rand int unsigned idle_cycles;


  // --------------------------------------------------
  // Packet boundary metadata
  // --------------------------------------------------

  // These fields are metadata only at this stage.
  // The line-segment driver does not construct packets.
  rand bit packet_start;
  rand bit packet_end;


  // --------------------------------------------------
  // Transaction identification
  // --------------------------------------------------

  int unsigned transaction_id;


  // --------------------------------------------------
  // Constraints
  // --------------------------------------------------

  constraint c_speed {

    speed inside {LS, FS, HS};

  }


  constraint c_duration {

    duration_cycles inside {[1:1000]};

  }


  constraint c_idle {

    idle_cycles inside {[0:100]};

  }


  // --------------------------------------------------
  // UVM factory registration and field automation
  // --------------------------------------------------

  `uvm_object_utils_begin(usb_bfm_transaction)

    `uvm_field_enum(
      speed_t,
      speed,
      UVM_ALL_ON
    )

    `uvm_field_int(
      dp,
      UVM_ALL_ON
    )

    `uvm_field_int(
      dm,
      UVM_ALL_ON
    )

    `uvm_field_int(
      drive_enable,
      UVM_ALL_ON
    )

    `uvm_field_int(
      analog_serial,
      UVM_ALL_ON
    )

    `uvm_field_int(
      duration_cycles,
      UVM_ALL_ON
    )

    `uvm_field_int(
      idle_cycles,
      UVM_ALL_ON
    )

    `uvm_field_int(
      packet_start,
      UVM_ALL_ON
    )

    `uvm_field_int(
      packet_end,
      UVM_ALL_ON
    )

    `uvm_field_int(
      transaction_id,
      UVM_ALL_ON
    )

  `uvm_object_utils_end


  // --------------------------------------------------
  // Constructor
  // --------------------------------------------------

  function new(
    string name = "usb_bfm_transaction"
  );

    super.new(name);

    // Explicit default values
    speed            = FS;

    dp               = 1'b1;
    dm               = 1'b0;

    drive_enable     = 1'b0;
    analog_serial    = 1'b1;

    duration_cycles = 40;
    idle_cycles     = 0;

    packet_start    = 1'b0;
    packet_end      = 1'b0;

    transaction_id  = 0;

  endfunction


  // --------------------------------------------------
  // Convert transaction to string
  // --------------------------------------------------

  function string convert2string();

    return $sformatf(
      "USB_BFM_TXN ID=%0d SPEED=%0d DP=%b DM=%b OE=%0b SERIAL=%0b DURATION=%0d IDLE=%0d START=%0b END=%0b",
      transaction_id,
      speed,
      dp,
      dm,
      drive_enable,
      analog_serial,
      duration_cycles,
      idle_cycles,
      packet_start,
      packet_end
    );

  endfunction


  // --------------------------------------------------
  // Check transaction validity
  // --------------------------------------------------

  function bit is_valid();

    if (!(speed inside {LS, FS, HS})) begin
      return 1'b0;
    end

    if (duration_cycles == 0) begin
      return 1'b0;
    end

    return 1'b1;

  endfunction


  // --------------------------------------------------
  // Print transaction
  // --------------------------------------------------

  function void do_print(uvm_printer printer);

    super.do_print(printer);

    printer.print_string(
      "transaction",
      convert2string()
    );

  endfunction

endclass

