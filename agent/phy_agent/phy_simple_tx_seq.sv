
class phy_simple_tx_seq extends uvm_sequence #(phy_transaction);

  `uvm_object_utils(phy_simple_tx_seq)

  function new(string name = "phy_simple_tx_seq");
    super.new(name);
  endfunction


  task body();

    phy_transaction req;


    // ==============================================
    // BYTE 1: SOP
    // ==============================================

    req = phy_transaction::type_id::create("req_1");

    start_item(req);

    req.sie_valid  = 1'b1;
    req.sie_data   = 8'hA5;
    req.sop        = 1'b1;
    req.eop        = 1'b0;
    req.sof_packet = 1'b0;

    finish_item(req);


    `uvm_info("PHY_SEQ",
              "First byte sent: DATA=A5 SOP=1 EOP=0",
              UVM_MEDIUM)


    // ==============================================
    // BYTE 2: EOP
    // ==============================================

    req = phy_transaction::type_id::create("req_2");

    start_item(req);

    req.sie_valid  = 1'b1;
    req.sie_data   = 8'h3C;
    req.sop        = 1'b0;
    req.eop        = 1'b1;
    req.sof_packet = 1'b0;

    finish_item(req);


    `uvm_info("PHY_SEQ",
              "Second byte sent: DATA=3C SOP=0 EOP=1",
              UVM_MEDIUM)


    `uvm_info("PHY_SEQ",
              "Simple TX sequence completed",
              UVM_LOW)

  endtask

endclass

