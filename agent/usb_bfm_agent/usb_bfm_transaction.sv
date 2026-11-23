
class usb_bfm_transaction extends uvm_sequence_item;

  rand speed_t speed;

  // Use logic to preserve X/Z from the resolved bus.
  rand logic dp;
  rand logic dm;

  rand bit drive_enable;
  rand bit analog_serial;

  rand int unsigned duration_cycles;
  rand int unsigned idle_cycles;

  rand bit packet_start;
  rand bit packet_end;

  int unsigned transaction_id;

  constraint c_speed {
    speed inside {LS, FS, HS};
  }

  constraint c_duration {
    duration_cycles inside {[1:1000]};
  }

  constraint c_idle {
    idle_cycles inside {[0:100]};
  }

  `uvm_object_utils_begin(usb_bfm_transaction)
    `uvm_field_enum(speed_t, speed, UVM_ALL_ON)
    `uvm_field_int(dp, UVM_ALL_ON)
    `uvm_field_int(dm, UVM_ALL_ON)
    `uvm_field_int(drive_enable, UVM_ALL_ON)
    `uvm_field_int(analog_serial, UVM_ALL_ON)
    `uvm_field_int(duration_cycles, UVM_ALL_ON)
    `uvm_field_int(idle_cycles, UVM_ALL_ON)
    `uvm_field_int(packet_start, UVM_ALL_ON)
    `uvm_field_int(packet_end, UVM_ALL_ON)
    `uvm_field_int(transaction_id, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "usb_bfm_transaction");
    super.new(name);
  endfunction

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

endclass

