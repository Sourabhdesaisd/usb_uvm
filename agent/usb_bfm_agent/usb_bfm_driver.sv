
class usb_bfm_driver extends uvm_driver #(usb_bfm_transaction);

    `uvm_component_utils(usb_bfm_driver)

    usb_bfm_agent_config cfg;

    virtual usb_bus_if bus_vif;
    virtual usb_phy_if #(8) phy_vif;

    function new(
        string name = "usb_bfm_driver",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(usb_bfm_agent_config)::get(
                this, "", "cfg", cfg
            )) begin
            `uvm_fatal(
                "USB_BFM_DRV",
                "usb_bfm_agent_config not found in config_db"
            )
        end

        cfg.check_config();

        bus_vif = cfg.bus_vif;
        phy_vif = cfg.phy_vif;

    endfunction


    task run_phase(uvm_phase phase);

        usb_bfm_transaction tr;

        drive_bus_idle();

        wait_for_reset_release();

        forever begin

            seq_item_port.get_next_item(tr);

            if (tr == null) begin
                `uvm_error(
                    "USB_BFM_DRV",
                    "Received a NULL transaction"
                )
            end
            else begin
                drive_transaction(tr);
            end

            seq_item_port.item_done();

        end

    endtask


    task wait_for_reset_release();

        while (bus_vif.rst_n !== 1'b1) begin
            @(bus_vif.cb_drv);
        end

    endtask


    task drive_bus_idle();

        bus_vif.device_dp = 1'b1;
        bus_vif.device_dm = 1'b0;
        bus_vif.device_oe = 1'b0;

        phy_vif.analog_enable = 1'b0;
        phy_vif.analog_serial = 1'b1;

    endtask


    task drive_transaction(usb_bfm_transaction tr);

        int unsigned cycle_count;

        if (!(tr.speed inside {LS, FS, HS})) begin
            `uvm_error(
                "USB_BFM_DRV",
                $sformatf(
                    "Unsupported USB speed: %0d",
                    tr.speed
                )
            )
            return;
        end

        // Apply the requested USB speed.
        @(bus_vif.cb_drv);
        phy_vif.cb_drv.usb_speed <= tr.speed;

        // Apply the external line state.
        bus_vif.cb_drv.device_dp <= tr.dp;
        bus_vif.cb_drv.device_dm <= tr.dm;
        bus_vif.cb_drv.device_oe <= tr.drive_enable;

        // Configure the CDR analog input path.
        phy_vif.cb_bfm_drv.analog_enable <= tr.drive_enable;
        phy_vif.cb_bfm_drv.analog_serial <= tr.analog_serial;

        // Hold the requested line state.
        for (cycle_count = 0;
             cycle_count < tr.duration_cycles;
             cycle_count++) begin

            @(bus_vif.cb_drv);

        end

        // Release the external bus driver after this segment.
        bus_vif.cb_drv.device_oe <= 1'b0;

        phy_vif.cb_bfm_drv.analog_enable <= 1'b0;

        // Optional idle interval before the next transaction.
        repeat (tr.idle_cycles) begin
            @(bus_vif.cb_drv);
        end

    endtask

endclass 
