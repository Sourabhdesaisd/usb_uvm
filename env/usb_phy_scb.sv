
class usb_phy_scoreboard extends uvm_scoreboard;

           
  // Analysis FIFOs
           

  uvm_tlm_analysis_fifo #(phy_transaction) phy_fifo;

  uvm_tlm_analysis_fifo #(usb_bfm_transaction) bus_fifo;


           
  // UVM Factory Registration
           

  `uvm_component_utils(usb_phy_scoreboard)


           
  // Constructor
           

  function new(string name = "usb_phy_scoreboard",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction


           
  // Build Phase
           

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    phy_fifo = new("phy_fifo", this);

    bus_fifo = new("bus_fifo", this);

  endfunction


           
  // Run Phase
           

  task run_phase(uvm_phase phase);

    fork

          
      // PHY Monitor Transaction Receiver
          

      begin : PHY_RECEIVE_THREAD

        phy_transaction tr;

        forever begin

          phy_fifo.get(tr);

          if (tr == null) begin
            `uvm_error("SB_PHY", "Received null PHY transaction")
            continue;
          end

          `uvm_info("SB_PHY_RX",
            $sformatf(
              "PHY Observation: TX_VALID=%0b DP=%0b DM=%0b RX_VALID=%0b RX_ACTIVE=%0b RX_ERROR=%0b RX_DATA=0x%02h",
              tr.tx_valid,
              tr.dp,
              tr.dm,
              tr.RxValid,
              tr.RxActive,
              tr.RxError,
              tr.DataOut
            ),
            UVM_LOW
          )

          // Check RX error status
          if (tr.RxError) begin

            `uvm_warning("SB_PHY_RX_ERROR",
                         "PHY reported RX error")

          end

          // Check RX status flags
          if (tr.rx_stuff_err ||
              tr.rx_align_err ||
              tr.rx_line_err ||
              tr.rx_babble_err ||
              tr.rx_sync_err) begin

            `uvm_warning("SB_PHY_STATUS",
                         "One or more PHY RX error flags are asserted")

          end

        end

      end


          
      // USB BFM Monitor Transaction Receiver
          

      begin : BUS_RECEIVE_THREAD

        usb_bfm_transaction tr;

        forever begin

          bus_fifo.get(tr);

          if (tr == null) begin
            `uvm_error("SB_BUS", "Received null USB BFM transaction")
            continue;
          end

          `uvm_info("SB_BUS_RX",
            $sformatf(
              "USB Bus Observation: DEVICE_DP=%0b DEVICE_DM=%0b DEVICE_OE=%0b PHY_TX_VALID=%0b DEVICE_DRIVE=%0b PHY_TX=%0b",
              tr.device_dp,
              tr.device_dm,
              tr.device_oe,
              tr.phy_tx_valid,
              tr.is_device_drive,
              tr.is_phy_tx
            ),
            UVM_LOW
          )

          // Check possible bus contention
          if (tr.is_device_drive && tr.is_phy_tx) begin

            `uvm_error("SB_BUS_CONTENTION",
                       "Both DUT PHY and external USB BFM are driving the bus")

          end

        end

      end

    join

  endtask

endclass

