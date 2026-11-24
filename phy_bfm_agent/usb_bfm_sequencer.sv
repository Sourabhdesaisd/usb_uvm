

class usb_bfm_sequencer extends uvm_sequencer #(usb_bfm_transaction);

  `uvm_component_utils(usb_bfm_sequencer)
  virtual usb_bus_if bus_vif;

  // Constructor
  function new(
    string name = "usb_bfm_sequencer",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction

endclass

