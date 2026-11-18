class usb_phy_scoreboard extends uvm_scoreboard;
  uvm_tlm_analysis_fifo #(phy_transaction)      phy_fifo;
  uvm_tlm_analysis_fifo #(usb_bfm_transaction)  bus_fifo;

  `uvm_component_utils(usb_phy_scoreboard)

  function new(string name = "usb_phy_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    phy_fifo = new("phy_fifo", this);
    bus_fifo = new("bus_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    fork
      begin : PHY_RECEIVE_THREAD
        phy_transaction tr;
        forever begin
          phy_fifo.get(tr);
          `uvm_info("SB_PHY_RX",
            $sformatf("Received PHY observation: TX valid=%0b TX state=%b RX valid=%0b",
                      tr.tx_valid, tr.tx_line_state, tr.Rx_valid), UVM_LOW)
        end
      end
      begin : BUS_RECEIVE_THREAD
        usb_bfm_transaction tr;
        forever begin
          bus_fifo.get(tr);
          `uvm_info("SB_BUS_RX",
            $sformatf("Received USB bus observation: DP=%b DM=%b direction=%s",
                      tr.dp, tr.dm, tr.direction.name()), UVM_LOW)
          if (tr.direction == USB_BUS_CONTENTION)
            `uvm_warning("SB_BUS_CONTENTION",
              "Both DUT and external BFM drive enables are asserted")
        end
      end
    join
  endtask
endclass

