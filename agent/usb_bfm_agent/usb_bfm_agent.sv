
class usb_bfm_agent extends uvm_agent;

    `uvm_component_utils(usb_bfm_agent)

    usb_bfm_agent_config cfg;

    usb_bfm_sequencer sequencer;
    usb_bfm_driver    driver;
    usb_bfm_monitor   monitor;


    function new(
        string name = "usb_bfm_agent",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Retrieve the BFM agent configuration.
        if (!uvm_config_db#(usb_bfm_agent_config)::get(
                this, "", "cfg", cfg
            )) begin

            `uvm_fatal(
                "USB_BFM_AGENT",
                "usb_bfm_agent_config not found in config_db"
            )

        end

        cfg.check_config();

        // Create monitor when enabled.
        if (cfg.enable_monitor) begin

            monitor = usb_bfm_monitor::type_id::create(
                "monitor",
                this
            );

            uvm_config_db#(usb_bfm_agent_config)::set(
                this,
                "monitor",
                "cfg",
                cfg
            );

        end

        // Create driver and sequencer only in active mode.
        if (cfg.is_active == UVM_ACTIVE) begin

            if (cfg.enable_driver) begin

                driver = usb_bfm_driver::type_id::create(
                    "driver",
                    this
                );

                uvm_config_db#(usb_bfm_agent_config)::set(
                    this,
                    "driver",
                    "cfg",
                    cfg
                );

            end

            // A driver requires a sequencer.
            if (cfg.enable_driver) begin

                sequencer = usb_bfm_sequencer::type_id::create(
                    "sequencer",
                    this
                );

            end

        end

    endfunction


    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect driver to sequencer.
        if (driver != null && sequencer != null) begin

            driver.seq_item_port.connect(
                sequencer.seq_item_export
            );

        end

    endfunction


    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        `uvm_info(
            "USB_BFM_AGENT",
            $sformatf(
                "Agent=%s, Mode=%s, Driver=%0b, Monitor=%0b",
                get_full_name(),
                (cfg.is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE",
                (driver != null),
                (monitor != null)
            ),
            UVM_LOW
        )

    endfunction

endclass
