class phy_sequencer extends uvm_sequencer #(phy_transaction);

  `uvm_component_utils(phy_sequencer)

  function new(string name = "phy_sequencer",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction

endclass
