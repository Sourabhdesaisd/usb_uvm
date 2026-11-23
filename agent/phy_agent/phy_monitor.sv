
class phy_monitor extends uvm_monitor;

    `uvm_component_utils(phy_monitor)

    // Virtual interface
    virtual usb_phy_if #(8) vif;

    // Agent configuration
    phy_agent_config cfg;

    // Analysis ports
    uvm_analysis_port #(phy_transaction) analysis_port;
    uvm_analysis_port #(phy_transaction) rx_analysis_port;

    // Counters
    int unsigned tx_handshake_count;
    int unsigned rx_valid_count;
    int unsigned tx_active_cycles;
    int unsigned rx_error_count;

    function new(
        string name = "phy_monitor",
        uvm_component parent = null
    );
        super.new(name, parent);

        analysis_port   = new("analysis_port", this);
        rx_analysis_port = new("rx_analysis_port", this);

        tx_handshake_count = 0;
        rx_valid_count     = 0;
        tx_active_cycles   = 0;
        rx_error_count     = 0;
    endfunction


              
    // BUILD PHASE
              

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(phy_agent_config)::get(
            this,
            "",
            "cfg",
            cfg
        )) begin
            `uvm_fatal(
                "PHY_MON",
                "Failed to get phy_agent_config"
            )
        end

        if (cfg == null || cfg.vif == null) begin
            `uvm_fatal(
                "PHY_MON",
                "PHY virtual interface is NULL"
            )
        end

        vif = cfg.vif;

    endfunction


              
    // RUN PHASE
              

    task run_phase(uvm_phase phase);

        fork
            monitor_tx();
            monitor_rx();
        join

    endtask


              
    // MONITOR SIE TX HANDSHAKE
              

    task monitor_tx();

        phy_transaction tr;

        forever begin

            @(vif.cb_mon);

            if (vif.cb_mon.rst_n !== 1'b1)
                continue;

            if ((vif.cb_mon.sie_valid === 1'b1) &&
                (vif.cb_mon.sie_ready === 1'b1)) begin

                tr = phy_transaction::type_id::create(
                    "tx_handshake_tr"
                );

                tr.speed      = vif.cb_mon.usb_speed;
                tr.data       = vif.cb_mon.sie_data;
                tr.valid      = vif.cb_mon.sie_valid;
                tr.ready      = vif.cb_mon.sie_ready;
                tr.sop        = vif.cb_mon.sie_sop;
                tr.eop        = vif.cb_mon.sie_eop;
                tr.sof_packet = vif.cb_mon.sof_packet;

                tx_handshake_count++;

                `uvm_info(
                    "PHY_MON_TX",
                    $sformatf(
                        "SIE transfer accepted: %s",
                        tr.convert2string()
                    ),
                    UVM_HIGH
                )

                analysis_port.write(tr);

            end

            if (vif.cb_mon.tx_valid === 1'b1)
                tx_active_cycles++;

        end

    endtask


              
    // MONITOR RX DATA AND STATUS
              

    task monitor_rx();

        phy_transaction tr;

        forever begin

            @(vif.cb_mon);

            if (vif.cb_mon.rst_n !== 1'b1)
                continue;

            if (vif.cb_mon.RxValid === 1'b1) begin

                tr = phy_transaction::type_id::create(
                    "rx_data_tr"
                );

                tr.speed      = vif.cb_mon.usb_speed;
                tr.data       = vif.cb_mon.DataOut;
                tr.valid      = vif.cb_mon.RxValid;
                tr.ready      = 1'b0;
                tr.sop        = vif.cb_mon.rx_sop;
                tr.eop        = vif.cb_mon.rx_eop;
                tr.sof_packet = 1'b0;

                rx_valid_count++;

                if (vif.cb_mon.RxError === 1'b1)
                    rx_error_count++;

                `uvm_info(
                    "PHY_MON_RX",
                    $sformatf(
                        "RX data=0x%02h SOP=%0b EOP=%0b RxError=%0b",
                        tr.data,
                        tr.sop,
                        tr.eop,
                        vif.cb_mon.RxError
                    ),
                    UVM_HIGH
                )

                rx_analysis_port.write(tr);

            end

        end

    endtask


              
    // REPORT PHASE
              

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info(
            "PHY_MON_REPORT",
            $sformatf(
                "TX handshakes=%0d TX active cycles=%0d RX valid bytes=%0d RX error cycles=%0d",
                tx_handshake_count,
                tx_active_cycles,
                rx_valid_count,
                rx_error_count
            ),
            UVM_LOW
        )

    endfunction

endclass 
