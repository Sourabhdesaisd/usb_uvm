
class phy_transaction extends uvm_sequence_item;

    // USB operating speed
    rand speed_t speed;

    // TX data
    rand bit [7:0] data;

    // SIE handshake
    rand bit valid;
    bit ready;

    // Packet boundary indications
    rand bit sop;
    rand bit eop;

    // SOF packet indication
    rand bit sof_packet;

    // Number of cycles to wait before presenting this transaction
    rand int unsigned delay_cycles;

    // Optional valid/ready backpressure control
    rand int unsigned valid_gap_cycles;

    // Transaction identification
    int unsigned transaction_id;

    // Constraints
    constraint c_delay_cycles {
        delay_cycles inside {[0:20]};
    }

    constraint c_valid_gap_cycles {
        valid_gap_cycles inside {[0:10]};
    }

    constraint c_packet_boundary {
        if (sop)
            valid == 1'b1;

        if (eop)
            valid == 1'b1;
    }

    constraint c_speed {
        speed inside {LS, FS, HS};
    }

    // UVM factory registration
    `uvm_object_utils_begin(phy_transaction)

        `uvm_field_enum(speed_t, speed, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(valid, UVM_ALL_ON)
        `uvm_field_int(ready, UVM_ALL_ON)
        `uvm_field_int(sop, UVM_ALL_ON)
        `uvm_field_int(eop, UVM_ALL_ON)
        `uvm_field_int(sof_packet, UVM_ALL_ON)
        `uvm_field_int(delay_cycles, UVM_ALL_ON)
        `uvm_field_int(valid_gap_cycles, UVM_ALL_ON)
        `uvm_field_int(transaction_id, UVM_ALL_ON)

    `uvm_object_utils_end

    // Constructor
    function new(string name = "phy_transaction");
        super.new(name);
    endfunction

    // Print transaction details
    function string convert2string();

        return $sformatf(
            "PHY_TXN: ID=%0d SPEED=%0d DATA=0x%02h VALID=%0b READY=%0b SOP=%0b EOP=%0b SOF=%0b DELAY=%0d GAP=%0d",
            transaction_id,
            speed,
            data,
            valid,
            ready,
            sop,
            eop,
            sof_packet,
            delay_cycles,
            valid_gap_cycles
        );

    endfunction

endclass

