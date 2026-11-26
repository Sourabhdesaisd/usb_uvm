
  
// USB 2.0 PHY - COMPLETE SIMULATION FILE LIST
  

// INCLUDE DIRECTORIES
   
+incdir+../rtl
+incdir+../phy_agent
+incdir+../phy_bfm_agent
+incdir+../env
+incdir+../test
+incdir+../test_pkg


  
//  RTL PACKAGE
  

../rtl/pkg.sv


  
// RTL - TX PATH
  

../rtl/bit_enable.sv
../rtl/tx_holding_reg.sv
../rtl/piso.sv
../rtl/bit_stuffer.sv
../rtl/nrzi_encoder.sv
../rtl/tx_data_line_state_converter.sv
../rtl/eop.sv
../rtl/tx_phy_mux.sv
../rtl/phy_tx_top.sv


  
//  RTL - RX PATH
  

../rtl/line_state_detector.sv
../rtl/bus_reset.sv
../rtl/rx_ctrl.sv
../rtl/sync_eop_detector.sv
../rtl/nrzi_decoder.sv
../rtl/bit_unstuffer.sv
../rtl/sipo.sv
../rtl/phy_rx_top.sv


  
//  RTL - CLOCK AND DATA RECOVERY
  

../rtl/edge_err_detection.sv
../rtl/FSM.sv
../rtl/loop_filter.sv
../rtl/oversampler.sv
../rtl/phase_acc.sv
../rtl/sampler.sv
../rtl/sync_deglitch.sv
../rtl/top.sv


  
//  RTL - TOP LEVEL
  

../rtl/phy_top.sv


  
//  TESTBENCH INTERFACES
  

../rtl/usb_phy_if.sv
../rtl/usb_bus_if.sv


  
//  UVM PACKAGE
  

../test_pkg/usb_phy_tb_pkg.sv


//TESTBENCH TOP

../env/top_tb.sv
