
class phy_simple_tx_seq extends uvm_sequence #(phy_transaction);

    `uvm_object_utils(phy_simple_tx_seq)

    // Packet configuration
    rand speed_t packet_speed;
    rand int unsigned packet_length;

    // SOF packet selection
    rand bit is_sof;

    constraint c_packet_length {
        packet_length inside {[1:64]};
    }

    constraint c_packet_speed {
        packet_speed inside {LS, FS, HS};
    }

    function new(string name = "phy_simple_tx_seq");
        super.new(name);
    endfunction

    virtual task body();

        phy_transaction req;

        // Generate packet configuration
        if (!randomize()) begin
            `uvm_fatal(
                "PHY_SEQ",
                "Failed to randomize packet configuration"
            )
        end

        `uvm_info(
            "PHY_SEQ",
            $sformatf(
                "Starting TX packet: SPEED=%0d LENGTH=%0d SOF=%0b",
                packet_speed,
                packet_length,
                is_sof
            ),
            UVM_MEDIUM
        )

        // Send packet bytes
        for (int unsigned i = 0; i < packet_length; i++) begin

            req = phy_transaction::type_id::create(
                $sformatf("req_%0d", i)
            );

            start_item(req);

            if (!req.randomize() with {
                speed == local::packet_speed;
                valid == 1'b1;
                sop == (i == 0);
                eop == (i == local::packet_length - 1);
                sof_packet == (local::is_sof && (i == 0));
            }) begin
                `uvm_fatal(
                    "PHY_SEQ",
                    $sformatf("Failed to randomize TX byte %0d", i)
                )
            end

            req.transaction_id = i;

            finish_item(req);

        end

        `uvm_info(
            "PHY_SEQ",
            "TX packet sequence completed",
            UVM_MEDIUM
        )

    endtask

endclass 
