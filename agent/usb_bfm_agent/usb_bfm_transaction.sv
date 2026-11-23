class usb_bfm_transaction extends uvm_sequence_item;

  // ==================================================
  // USB CONFIGURATION
  // ==================================================

  speed_t speed;


  // ==================================================
  // RESOLVED USB BUS VALUES
  // ==================================================

  // Four-state logic is intentional.
  // The monitor must preserve X and Z observations.

  logic dp;
  logic dm;


  // ==================================================
  // BUS DRIVER OWNERSHIP
  // ==================================================

  bit drive_enable;

  bit phy_drive_enable;
  bit external_drive_enable;

  bit bus_contention;


  // ==================================================
  // CDR / ANALOG OBSERVATION
  // ==================================================

  logic analog_serial;
  logic analog_enable;


  // ==================================================
  // SEGMENT TIMING
  // ==================================================

  int unsigned duration_cycles;
  int unsigned idle_cycles;


  // ==================================================
  // PACKET INFORMATION
  // ==================================================

  bit packet_start;
  bit packet_end;


  // ==================================================
  // TRANSACTION IDENTIFICATION
  // ==================================================

  int unsigned transaction_id;


  // ==================================================
  // UVM FACTORY AND FIELD REGISTRATION
  // ==================================================

  `uvm_object_utils_begin(usb_bfm_transaction)

    `uvm_field_enum(speed_t, speed, UVM_ALL_ON)

    `uvm_field_int(dp, UVM_ALL_ON)
    `uvm_field_int(dm, UVM_ALL_ON)

    `uvm_field_int(drive_enable, UVM_ALL_ON)
    `uvm_field_int(phy_drive_enable, UVM_ALL_ON)
    `uvm_field_int(external_drive_enable, UVM_ALL_ON)
    `uvm_field_int(bus_contention, UVM_ALL_ON)

    `uvm_field_int(analog_serial, UVM_ALL_ON)
    `uvm_field_int(analog_enable, UVM_ALL_ON)

    `uvm_field_int(duration_cycles, UVM_ALL_ON)
    `uvm_field_int(idle_cycles, UVM_ALL_ON)

    `uvm_field_int(packet_start, UVM_ALL_ON)
    `uvm_field_int(packet_end, UVM_ALL_ON)

    `uvm_field_int(transaction_id, UVM_ALL_ON)

  `uvm_object_utils_end


  // ==================================================
  // CONSTRUCTOR
  // ==================================================

  function new(string name = "usb_bfm_transaction");

    super.new(name);

    speed                 = FS;

    dp                    = 1'bz;
    dm                    = 1'bz;

    drive_enable          = 1'b0;
    phy_drive_enable      = 1'b0;
    external_drive_enable = 1'b0;
    bus_contention        = 1'b0;

    analog_serial         = 1'b0;
    analog_enable         = 1'b0;

    duration_cycles      = 0;
    idle_cycles          = 0;

    packet_start         = 1'b0;
    packet_end           = 1'b0;

    transaction_id       = 0;

  endfunction


  // ==================================================
  // CONVERT TO STRING
  // ==================================================

  function string convert2string();

    return $sformatf(
      {
        "USB_BFM_TXN ID=%0d SPEED=%0d ",
        "DP=%b DM=%b ",
        "DRIVE=%0b PHY_OE=%0b EXT_OE=%0b CONTENTION=%0b ",
        "SERIAL=%b ANALOG_EN=%b ",
        "DURATION=%0d IDLE=%0d"
      },

      transaction_id,
      speed,

      dp,
      dm,

      drive_enable,
      phy_drive_enable,
      external_drive_enable,
      bus_contention,

      analog_serial,
      analog_enable,

      duration_cycles,
      idle_cycles
    );

  endfunction

endclass
