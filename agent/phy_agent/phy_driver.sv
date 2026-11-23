
class phy_driver extends uvm_driver #(phy_transaction);

    `uvm_component_utils(phy_driver)

    // Virtual interface
    virtual usb_phy_if #(8) vif;

    // Agent configuration
    phy_agent_config cfg;

    // Transaction counter
    int unsigned driven_transactions;

    function new(
        string name = "phy_driver",
        uvm_component parent = null
    );
        super.new(name, parent);
        driven_transactions = 0;
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
                "PHY_DRV",
                "Failed to get phy_agent_config"
            )
        end

        if (cfg == null) begin
            `uvm_fatal(
                "PHY_DRV",
                "PHY agent configuration is NULL"
            )
        end

        if (cfg.vif == null) begin
            `uvm_fatal(
                "PHY_DRV",
                "PHY virtual interface is NULL"
            )
        end

        vif = cfg.vif;

    endfunction


              
    // RUN PHASE
              

    task run_phase(uvm_phase phase);

        phy_transaction req;

        drive_idle();

        wait_for_reset_release();

        forever begin

            seq_item_port.get_next_item(req);

            if (req == null) begin
                `uvm_fatal(
                    "PHY_DRV",
                    "Received NULL transaction"
                )
            end

            drive_transaction(req);

            seq_item_port.item_done();

        end

    endtask


              
    // WAIT FOR RESET RELEASE
              

    task wait_for_reset_release();

        @(vif.cb_drv);

        while (vif.cb_drv.rst_n !== 1'b1) begin
            @(vif.cb_drv);
        end

    endtask


              
    // DRIVE IDLE VALUES
              

    task drive_idle();

        vif.cb_drv.usb_speed  <= cfg.speed;
        vif.cb_drv.sof_packet <= 1'b0;

        vif.cb_drv.sie_data   <= '0;
        vif.cb_drv.sie_valid  <= 1'b0;
        vif.cb_drv.sie_sop    <= 1'b0;
        vif.cb_drv.sie_eop    <= 1'b0;

    endtask


              
    // DRIVE ONE SIE TRANSACTION
              

    task drive_transaction(phy_transaction tr);

        int unsigned wait_count;

        // Apply configured USB speed
        @(vif.cb_drv);

        vif.cb_drv.usb_speed <= tr.speed;

        // Optional delay before this transfer
        repeat (tr.delay_cycles) begin
            @(vif.cb_drv);
        end

        // Drive byte and packet controls
        vif.cb_drv.sie_data   <= tr.data;
        vif.cb_drv.sie_sop    <= tr.sop;
        vif.cb_drv.sie_eop    <= tr.eop;
        vif.cb_drv.sof_packet <= tr.sof_packet;
        vif.cb_drv.sie_valid  <= tr.valid;

        wait_count = 0;

        // Hold the transaction until DUT accepts it
        do begin

            @(vif.cb_drv);

            wait_count++;

            if (wait_count > 10000) begin
                `uvm_fatal(
                    "PHY_DRV_TIMEOUT",
                    $sformatf(
                        "DUT did not assert sie_ready. DATA=0x%02h SPEED=%0d",
                        tr.data,
                        tr.speed
                    )
                )
            end

        end while (vif.cb_drv.sie_ready !== 1'b1);

        // Deassert valid after acceptance
        vif.cb_drv.sie_valid  <= 1'b0;
        vif.cb_drv.sie_sop    <= 1'b0;
        vif.cb_drv.sie_eop    <= 1'b0;
        vif.cb_drv.sof_packet <= 1'b0;

        driven_transactions++;

        `uvm_info(
            "PHY_DRV",
            $sformatf(
                "Accepted transaction %0d: %s",
                driven_transactions,
                tr.convert2string()
            ),
            UVM_MEDIUM
        )

        // Optional gap between transfers
        repeat (tr.valid_gap_cycles) begin
            @(vif.cb_drv);
        end

    endtask


              
    // REPORT PHASE
              

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info(
            "PHY_DRV_REPORT",
            $sformatf(
                "Total accepted SIE transactions = %0d",
                driven_transactions
            ),
            UVM_LOW
        )

    endfunction

endclass 
