
class phy_simple_tx_seq extends uvm_sequence #(phy_transaction);

  `uvm_object_utils(phy_simple_tx_seq)

  // Speed is selected by the test.
  // Do not randomize speed inside the sequence.
  speed_t packet_speed = FS;

  // Random packet configuration
  rand int unsigned packet_length;
  rand bit is_sof;

  // Transaction ID
  int unsigned transaction_id;

  constraint c_packet_length {
    packet_length inside {[1:64]};
  }


  // Constructor
  function new(string name = "phy_simple_tx_seq");
    super.new(name);

    packet_speed  = FS;
    packet_length = 8;
    is_sof        = 0;
    transaction_id = 0;
  endfunction


  // Sequence body
  virtual task body();

    phy_transaction req;

    // Validate speed selected by the test
    if (!(packet_speed inside {LS, FS, HS})) begin
      `uvm_fatal(
        "PHY_SEQ",
        $sformatf(
          "Invalid packet speed: %0d",
          packet_speed
        )
      )
    end

    // Randomize packet length and SOF selection only
    if (!randomize(packet_length, is_sof)) begin
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


    // Generate packet bytes
    for (int unsigned i = 0; i < packet_length; i++) begin

      req = phy_transaction::type_id::create(
        $sformatf("req_%0d", i)
      );

      start_item(req);

      // Randomize data while keeping speed and packet
      // boundary information controlled by the sequence.
      if (!req.randomize() with {

        speed == local::packet_speed;

        valid == 1'b1;

        sop == (i == 0);

        eop == (i == local::packet_length - 1);

        sof_packet == (local::is_sof && (i == 0));

        delay_cycles == 0;

        valid_gap_cycles == 0;

      }) begin

        `uvm_fatal(
          "PHY_SEQ",
          $sformatf(
            "Failed to randomize packet byte %0d",
            i
          )
        )

      end

      req.transaction_id = transaction_id;
      transaction_id++;

      `uvm_info(
        "PHY_SEQ",
        req.convert2string(),
        UVM_HIGH
      )

      finish_item(req);

    end


    `uvm_info(
      "PHY_SEQ",
      $sformatf(
        "TX packet completed. SPEED=%0d BYTES=%0d",
        packet_speed,
        packet_length
      ),
      UVM_MEDIUM
    )

  endtask

endclass

