


interface usb_phy_if #(
    parameter int WIDTH = 8
)(
    input logic clk
);

    // Import the actual RTL package.
    // Confirm its declaration in ../rtl/pkg.sv.
    import usb_phy_pkg::*;


       
    // RESET AND USB CONFIGURATION
       

    logic   rst_n;
    speed_t usb_speed;


       
    // SIE -> DUT TX PHY INPUTS
       

    logic             sof_packet;
    logic [WIDTH-1:0] sie_data;
    logic             sie_valid;
    logic             sie_sop;
    logic             sie_eop;

    logic             sie_ready;


       
    // DUT TX PHY -> EXTERNAL USB PARTNER OUTPUTS
       

    logic dp;
    logic dm;
    logic tx_valid;


       
    // EXTERNAL USB PARTNER -> DUT CDR INPUTS
       

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

        input rst_n;
        input sie_ready;

        output usb_speed;

        output sof_packet;
        output sie_data;
        output sie_valid;
        output sie_sop;
        output sie_eop;

    endclocking


       
    // CLOCKING BLOCK 2: EXTERNAL USB BFM DRIVER
       

    clocking cb_bfm_drv @(posedge clk);

        default input #1step output #0;

        input rst_n;

        output analog_d_plus;
        output analog_d_minus;
        output analog_enable;
        output analog_serial;

    endclocking


       
    // CLOCKING BLOCK 3: PHY MONITOR
       

    clocking cb_mon @(posedge clk);

        default input #1step;

        // Configuration
        input rst_n;
        input usb_speed;

        // SIE TX observation
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

        // External partner inputs
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

        // RX status
        input rx_stuff_err;
        input rx_align_err;
        input rx_line_err;
        input rx_babble_err;
        input rx_sync_err;
        input rx_bus_reset;

    endclocking

endinterface

