
class usb_bfm_agent_config extends uvm_object;

    // Virtual interface for the shared USB bus
    virtual usb_bus_if bus_vif;

    // PHY interface for analog CDR control
    virtual usb_phy_if #(8) phy_vif;

    // Agent mode
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // Component enable controls
    bit enable_driver  = 1'b1;
    bit enable_monitor = 1'b1;

    // Default USB speed
    speed_t speed = FS;

    // Default timing configuration
    int unsigned default_bit_time_cycles = 40;
    int unsigned default_idle_cycles     = 0;

    // Agent name
    string agent_name = "USB_BFM_AGENT";

    `uvm_object_utils_begin(usb_bfm_agent_config)

        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(enable_driver, UVM_ALL_ON)
        `uvm_field_int(enable_monitor, UVM_ALL_ON)
        `uvm_field_enum(speed_t, speed, UVM_ALL_ON)
        `uvm_field_int(default_bit_time_cycles, UVM_ALL_ON)
        `uvm_field_int(default_idle_cycles, UVM_ALL_ON)
        `uvm_field_string(agent_name, UVM_ALL_ON)

    `uvm_object_utils_end

    function new(string name = "usb_bfm_agent_config");
        super.new(name);
    endfunction


    // Set USB speed and corresponding system-clock bit period
    function void set_speed(speed_t new_speed);

        if (!(new_speed inside {LS, FS, HS})) begin

            `uvm_error(
                "USB_BFM_CFG",
                $sformatf(
                    "Invalid USB speed: %0d",
                    new_speed
                )
            )

            return;

        end

        speed = new_speed;

        case (new_speed)

            LS: default_bit_time_cycles = 320;
            FS: default_bit_time_cycles = 40;
            HS: default_bit_time_cycles = 1;

            default: default_bit_time_cycles = 40;

        endcase

    endfunction


    // Validate configuration before simulation
    function void check_config();

        if (bus_vif == null) begin
            `uvm_fatal(
                "USB_BFM_CFG",
                "USB bus virtual interface is NULL"
            )
        end

        if (phy_vif == null) begin
            `uvm_fatal(
                "USB_BFM_CFG",
                "PHY virtual interface is NULL"
            )
        end

        if (!(speed inside {LS, FS, HS})) begin
            `uvm_fatal(
                "USB_BFM_CFG",
                "Invalid USB speed configuration"
            )
        end

        if (default_bit_time_cycles == 0) begin
            `uvm_fatal(
                "USB_BFM_CFG",
                "default_bit_time_cycles cannot be zero"
            )
        end

    endfunction

endclass 
