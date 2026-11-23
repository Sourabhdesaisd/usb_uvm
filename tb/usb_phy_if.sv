interface usb_phy_if #(
    parameter int WIDTH = 8
)(
    input logic clk
);


    import usb_phy_pkg::*;
    logic   rst_n;
    speed_t usb_speed;


               
    // SIE -> DUT TX PHY INPUTS
               

    logic             sof_packet;
    logic [WIDTH-1:0] sie_data;
    logic             sie_valid;
    logic             sie_sop;
    logic             sie_eop;

    // DUT TX handshake output
    logic             sie_ready;



    logic dp;
    logic dm;
    logic tx_valid;


               
    //EXTERNAL USB PARTNER -> DUT CDR INPUTS
               

    logic analog_d_plus;
    logic analog_d_minus;
    logic analog_enable;
    logic analog_serial;


               
    // DUT RX PHY -> SIE OUTPUTS
               

    logic [WIDTH-1:0] DataOut;

    logic             RxValid;
    logic             RxActive;
    logic             RxError;

    logic [1:0]       LineState;

    logic             rx_sop;
    logic             rx_eop;


               
    // DUT RX DEBUG / STATUS OUTPUTS
               

    logic rx_stuff_err;
    logic rx_align_err;
    logic rx_line_err;
    logic rx_babble_err;
    logic rx_sync_err;
    logic rx_bus_reset;


               
    // CLOCKING BLOCK 1: SIE DRIVER
               

    clocking cb_drv @(posedge clk);

        default input #1step output #0;

        // Inputs observed by PHY driver
        input rst_n;
        input sie_ready;

        // Outputs driven by PHY driver
        output usb_speed;

        output sof_packet;
        output sie_data;
        output sie_valid;
        output sie_sop;
        output sie_eop;

    endclocking


               
    //  EXTERNAL USB BFM DRIVER
               

    clocking cb_bfm_drv @(posedge clk);

        default input #1step output #0;

        // Reset observation
        input rst_n;

        // BFM-controlled CDR signals
        //
        // analog_d_plus and analog_d_minus are NOT
        // driven here. They are connected to the
        // resolved USB bus through continuous
        // assignments in tb_top.sv.

        output analog_enable;
        output analog_serial;

    endclocking
               

    clocking cb_mon @(posedge clk);

        default input #1step;

                  

        input rst_n;
        input usb_speed;
                  

        input sof_packet;
        input sie_data;
        input sie_valid;
        input sie_sop;
        input sie_eop;
        input sie_ready;


                  
        // DUT TX physical outputs
                  

        input dp;
        input dm;
        input tx_valid;


                  
        // External partner inputs to CDR
                  

        input analog_d_plus;
        input analog_d_minus;
        input analog_enable;
        input analog_serial;


                  
        // DUT RX outputs
                  

        input DataOut;
        input RxValid;
        input RxActive;
        input RxError;
        input LineState;

        input rx_sop;
        input rx_eop;


                  
        // DUT RX debug and status
                  

        input rx_stuff_err;
        input rx_align_err;
        input rx_line_err;
        input rx_babble_err;
        input rx_sync_err;
        input rx_bus_reset;

    endclocking

endinterface

