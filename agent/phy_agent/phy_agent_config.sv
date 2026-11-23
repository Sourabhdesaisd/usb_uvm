
class phy_agent_config extends uvm_object;

    // Virtual interface connected to phy_top
    virtual usb_phy_if #(8) vif;

    // Agent operation mode
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // Enable or disable components
    bit enable_driver  = 1'b1;
    bit enable_monitor = 1'b1;

    // Default USB speed
    speed_t speed = FS;

    // Agent identification
    string agent_name = "PHY_AGENT";

    `uvm_object_utils_begin(phy_agent_config)

        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(enable_driver, UVM_ALL_ON)
        `uvm_field_int(enable_monitor, UVM_ALL_ON)
        `uvm_field_enum(speed_t, speed, UVM_ALL_ON)
        `uvm_field_string(agent_name, UVM_ALL_ON)

    `uvm_object_utils_end

    function new(string name = "phy_agent_config");
        super.new(name);
    endfunction

    function void set_speed(speed_t new_speed);

        if (!(new_speed inside {LS, FS, HS})) begin
            `uvm_error(
                "PHY_CFG",
                $sformatf("Invalid USB speed value: %0d", new_speed)
            )
        end
        else begin
            speed = new_speed;
        end

    endfunction

    function void check_config();

        if (vif == null) begin
            `uvm_fatal(
                "PHY_CFG",
                "PHY virtual interface is NULL"
            )
        end

        if (!(speed inside {LS, FS, HS})) begin
            `uvm_fatal(
                "PHY_CFG",
                "Invalid USB speed configuration"
            )
        end

    endfunction

endclass 

