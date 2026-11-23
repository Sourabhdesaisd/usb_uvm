
// ============================================================
// File       : usb_phy_ref_model.sv
// Description: Consolidated USB 2.0 PHY Reference Model
//              TX + RX + CDR + CRC + NRZI + Bit Stuffing
//              + EOP + Line State + Timing
//
// Clock      : 480 MHz
// Speeds     : LS / FS / HS
//
// Include this file inside usb_phy_tb_pkg after importing
// usb_phy_pkg::* and including uvm_macros.svh.
//
// IMPORTANT:
// This is a behavioral reference model. CDR phase/lock behavior
// is a configurable abstract model, not a cycle-exact replica
// of an undocumented RTL loop-filter implementation.
// ============================================================


// ------------------------------------------------------------
// Reference model types
// ------------------------------------------------------------

typedef enum logic [1:0] {
    REF_SE0 = 2'b00,
    REF_K   = 2'b01,
    REF_J   = 2'b10,
    REF_SE1 = 2'b11
} usb_ref_line_e;


typedef struct packed {
    logic dp;
    logic dm;
    logic tx_valid;
    logic is_stuffed;
    logic is_eop;
} usb_ref_tx_symbol_t;


typedef struct packed {
    logic [7:0] data;
    logic       valid;
    logic       sop;
    logic       eop;
    logic       error;
    logic       stuff_error;
    logic       align_error;
    logic       sync_error;
} usb_ref_rx_result_t;


typedef struct packed {
    logic recovered_bit_clk;
    logic locked;
    logic edge_detected;
    integer signed phase_error;
} usb_ref_cdr_result_t;


// ------------------------------------------------------------
// Consolidated reference model class
// ------------------------------------------------------------

class usb_phy_ref_model;

    // --------------------------------------------------------
    // Configuration
    // --------------------------------------------------------

    speed_t speed;

    int unsigned system_clock_hz;

    int unsigned clocks_per_bit;

    int unsigned oversampling_ratio;

    int unsigned cdr_lock_threshold;

    int unsigned cdr_unlock_threshold;

    bit cdr_enabled;

    bit cdr_locked;


    // --------------------------------------------------------
    // TX reference-model state
    // --------------------------------------------------------

    bit tx_nrzi_previous;

    int unsigned tx_consecutive_ones;

    bit tx_packet_active;

    bit [7:0] tx_byte;

    bit [7:0] tx_pid;

    bit tx_pid_enabled;

    bit tx_crc_enabled;

    bit tx_stuff_enabled;

    bit tx_nrzi_enabled;

    bit tx_eop_enabled;


    // --------------------------------------------------------
    // RX reference-model state
    // --------------------------------------------------------

    bit rx_nrzi_previous;

    int unsigned rx_consecutive_ones;

    bit rx_packet_active;

    bit rx_sync_detected;

    bit rx_stuff_error;

    bit rx_align_error;

    bit rx_line_error;

    bit rx_sync_error;

    bit [7:0] rx_shift_register;

    int unsigned rx_bit_count;


    // --------------------------------------------------------
    // CDR reference-model state
    // --------------------------------------------------------

    int unsigned cdr_sample_count;

    int unsigned cdr_phase;

    int unsigned cdr_lock_count;

    int unsigned cdr_unlock_count;

    bit cdr_previous_sample;

    bit cdr_edge_seen;

    bit cdr_recovered_strobe;

    integer signed cdr_phase_error;


    // --------------------------------------------------------
    // Statistics
    // --------------------------------------------------------

    int unsigned tx_symbol_count;
    int unsigned tx_stuffed_bit_count;
    int unsigned tx_packet_count;

    int unsigned rx_byte_count;
    int unsigned rx_packet_count;
    int unsigned rx_error_count;

    int unsigned cdr_edge_count;
    int unsigned cdr_lock_events;
    int unsigned cdr_unlock_events;


    // --------------------------------------------------------
    // Constructor
    // --------------------------------------------------------

    function new();

        speed                  = FS;
        system_clock_hz        = 480_000_000;
        clocks_per_bit         = 40;
        oversampling_ratio     = 40;

        cdr_lock_threshold     = 8;
        cdr_unlock_threshold   = 8;

        cdr_enabled            = 1'b1;
        cdr_locked             = 1'b0;

        tx_nrzi_previous       = 1'b1;
        tx_consecutive_ones    = 0;
        tx_packet_active       = 1'b0;

        tx_pid_enabled         = 1'b0;
        tx_crc_enabled         = 1'b0;
        tx_stuff_enabled       = 1'b1;
        tx_nrzi_enabled        = 1'b1;
        tx_eop_enabled         = 1'b1;

        rx_nrzi_previous       = 1'b1;
        rx_consecutive_ones    = 0;
        rx_packet_active       = 1'b0;
        rx_sync_detected       = 1'b0;

        rx_stuff_error         = 1'b0;
        rx_align_error         = 1'b0;
        rx_line_error          = 1'b0;
        rx_sync_error          = 1'b0;

        rx_shift_register      = '0;
        rx_bit_count           = 0;

        cdr_sample_count       = 0;
        cdr_phase              = 0;
        cdr_lock_count         = 0;
        cdr_unlock_count       = 0;

        cdr_previous_sample    = 1'b1;
        cdr_edge_seen          = 1'b0;
        cdr_recovered_strobe   = 1'b0;
        cdr_phase_error        = 0;

        tx_symbol_count        = 0;
        tx_stuffed_bit_count   = 0;
        tx_packet_count        = 0;

        rx_byte_count          = 0;
        rx_packet_count        = 0;
        rx_error_count         = 0;

        cdr_edge_count         = 0;
        cdr_lock_events        = 0;
        cdr_unlock_events      = 0;

    endfunction


    // --------------------------------------------------------
    // Configure USB speed
    // --------------------------------------------------------

    function void configure_speed(speed_t new_speed);

        speed = new_speed;

        case (new_speed)

            LS: begin
                clocks_per_bit     = 320;
                oversampling_ratio = 40;
            end

            FS: begin
                clocks_per_bit     = 40;
                oversampling_ratio = 40;
            end

            HS: begin
                clocks_per_bit     = 1;
                oversampling_ratio = 1;
            end

            default: begin
                clocks_per_bit     = 0;
                oversampling_ratio = 0;
            end

        endcase

        reset_tx();
        reset_rx();
        reset_cdr();

    endfunction


    // --------------------------------------------------------
    // Speed-dependent J state
    // --------------------------------------------------------

    function automatic usb_ref_line_e get_j_state();

        if (speed == LS)
            return REF_K;
        else
            return REF_J;

    endfunction


    // --------------------------------------------------------
    // Speed-dependent K state
    // --------------------------------------------------------

    function automatic usb_ref_line_e get_k_state();

        if (speed == LS)
            return REF_J;
        else
            return REF_K;

    endfunction


    // --------------------------------------------------------
    // Convert physical DP/DM to line state
    // --------------------------------------------------------

    function automatic usb_ref_line_e decode_line(
        logic dp,
        logic dm
    );

        case ({dp, dm})

            2'b00: return REF_SE0;
            2'b01: return REF_K;
            2'b10: return REF_J;
            2'b11: return REF_SE1;

            default: return REF_SE0;

        endcase

    endfunction


    // --------------------------------------------------------
    // Convert line state to DP/DM
    // --------------------------------------------------------

    function automatic logic [1:0] encode_line(
        usb_ref_line_e line_state
    );

        return line_state;

    endfunction


    // --------------------------------------------------------
    // TX reset
    // --------------------------------------------------------

    function void reset_tx();

        tx_nrzi_previous    = 1'b1;
        tx_consecutive_ones = 0;
        tx_packet_active    = 1'b0;

        tx_symbol_count     = 0;
        tx_stuffed_bit_count = 0;

    endfunction


    // --------------------------------------------------------
    // RX reset
    // --------------------------------------------------------

    function void reset_rx();

        rx_nrzi_previous  = 1'b1;
        rx_consecutive_ones = 0;
        rx_packet_active  = 1'b0;
        rx_sync_detected  = 1'b0;

        rx_stuff_error    = 1'b0;
        rx_align_error    = 1'b0;
        rx_line_error     = 1'b0;
        rx_sync_error     = 1'b0;

        rx_shift_register = '0;
        rx_bit_count      = 0;

    endfunction


    // --------------------------------------------------------
    // CDR reset
    // --------------------------------------------------------

    function void reset_cdr();

        cdr_sample_count     = 0;
        cdr_phase            = 0;

        cdr_lock_count       = 0;
        cdr_unlock_count     = 0;

        cdr_locked           = 1'b0;

        cdr_previous_sample  = 1'b1;
        cdr_edge_seen        = 1'b0;

        cdr_recovered_strobe = 1'b0;
        cdr_phase_error      = 0;

    endfunction


    // --------------------------------------------------------
    // CRC5 calculation
    //
    // USB CRC5:
    // Polynomial: x^5 + x^2 + 1
    // Initial value: 5'h1F
    // Final complement: yes
    //
    // Bits are processed LSB first.
    // --------------------------------------------------------

    function automatic logic [4:0] calculate_crc5(
        input bit data_bits[$]
    );

        logic [4:0] crc;
        logic feedback;

        crc = 5'h1F;

        foreach (data_bits[i]) begin

            feedback = crc[0] ^ data_bits[i];

            crc = crc >> 1;

            if (feedback)
                crc = crc ^ 5'h14;

        end

        return ~crc;

    endfunction


    // --------------------------------------------------------
    // CRC16 calculation
    //
    // USB CRC16:
    // Polynomial: x^16 + x^15 + x^2 + 1
    // Initial value: 16'hFFFF
    // Final complement: yes
    //
    // Bits are processed LSB first.
    // --------------------------------------------------------

    function automatic logic [15:0] calculate_crc16(
        input bit data_bits[$]
    );

        logic [15:0] crc;
        logic feedback;

        crc = 16'hFFFF;

        foreach (data_bits[i]) begin

            feedback = crc[0] ^ data_bits[i];

            crc = crc >> 1;

            if (feedback)
                crc = crc ^ 16'hA001;

        end

        return ~crc;

    endfunction


    // --------------------------------------------------------
    // Convert byte to LSB-first bit queue
    // --------------------------------------------------------

    function void byte_to_bits(
        input logic [7:0] data,
        ref bit bits[$]
    );

        for (int i = 0; i < 8; i++)
            bits.push_back(data[i]);

    endfunction


    // --------------------------------------------------------
    // Append byte to a bit queue
    // --------------------------------------------------------

    function void append_byte(
        input logic [7:0] data,
        ref bit bits[$]
    );

        for (int i = 0; i < 8; i++)
            bits.push_back(data[i]);

    endfunction


    // --------------------------------------------------------
    // Append CRC16 to a bit queue
    // --------------------------------------------------------

    function void append_crc16(
        ref bit bits[$]
    );

        logic [15:0] crc;

        crc = calculate_crc16(bits);

        for (int i = 0; i < 16; i++)
            bits.push_back(crc[i]);

    endfunction


    // --------------------------------------------------------
    // NRZI encode one bit
    //
    // USB rule:
    // Data 0 -> transition
    // Data 1 -> no transition
    // --------------------------------------------------------

    function automatic bit nrzi_encode_bit(
        input bit data_bit,
        ref bit previous_level
    );

        if (data_bit == 1'b0)
            previous_level = ~previous_level;

        return previous_level;

    endfunction


    // --------------------------------------------------------
    // NRZI decode one bit
    //
    // Transition -> 0
    // No transition -> 1
    // --------------------------------------------------------

    function automatic bit nrzi_decode_bit(
        input bit current_level,
        ref bit previous_level
    );

        bit decoded;

        decoded = (current_level == previous_level);

        previous_level = current_level;

        return decoded;

    endfunction


    // --------------------------------------------------------
    // Bit stuffing
    //
    // Insert a zero after six consecutive ones.
    //
    // The input queue must contain the data bits to be
    // stuffed. SYNC handling is managed by the packet builder.
    // --------------------------------------------------------

    function void bit_stuff(
        input bit input_bits[$],
        ref bit output_bits[$]
    );

        int unsigned ones_count;

        ones_count = 0;

        foreach (input_bits[i]) begin

            output_bits.push_back(input_bits[i]);

            if (input_bits[i]) begin

                ones_count++;

                if (ones_count == 6) begin

                    output_bits.push_back(1'b0);

                    tx_stuffed_bit_count++;

                    ones_count = 0;

                end

            end
            else begin

                ones_count = 0;

            end

        end

    endfunction


    // --------------------------------------------------------
    // Bit unstuffing
    //
    // Returns 1 when no stuffing error is detected.
    // Returns 0 when a required stuffed zero is missing.
    // --------------------------------------------------------

    function bit bit_unstuff(
        input bit input_bits[$],
        ref bit output_bits[$]
    );

        int unsigned ones_count;
        int unsigned i;

        ones_count = 0;
        i = 0;

        while (i < input_bits.size()) begin

            output_bits.push_back(input_bits[i]);

            if (input_bits[i]) begin

                ones_count++;

                if (ones_count == 6) begin

                    i++;

                    if (i >= input_bits.size()) begin
                        rx_stuff_error = 1'b1;
                        return 1'b0;
                    end

                    if (input_bits[i] != 1'b0) begin
                        rx_stuff_error = 1'b1;
                        return 1'b0;
                    end

                    ones_count = 0;

                end

            end
            else begin

                ones_count = 0;

            end

            i++;

        end

        return 1'b1;

    endfunction


    // --------------------------------------------------------
    // Build USB SYNC bit pattern
    //
    // LS/FS: KJKJKJKK
    // HS:    (KJ)x15 followed by KK
    //
    // This function returns logical line symbols.
    // --------------------------------------------------------

    function void build_sync(
        ref usb_ref_line_e sync_symbols[$]
    );

        sync_symbols.delete();

        if (speed == HS) begin

            for (int i = 0; i < 15; i++) begin
                sync_symbols.push_back(get_k_state());
                sync_symbols.push_back(get_j_state());
            end

            sync_symbols.push_back(get_k_state());
            sync_symbols.push_back(get_k_state());

        end
        else begin

            sync_symbols.push_back(get_k_state());
            sync_symbols.push_back(get_j_state());
            sync_symbols.push_back(get_k_state());
            sync_symbols.push_back(get_j_state());
            sync_symbols.push_back(get_k_state());
            sync_symbols.push_back(get_j_state());
            sync_symbols.push_back(get_k_state());
            sync_symbols.push_back(get_k_state());

        end

    endfunction


    // --------------------------------------------------------
    // Generate TX line symbols from logical data bits
    //
    // Output symbols represent DP/DM line states.
    // --------------------------------------------------------

    function void encode_tx_bits(
        input bit data_bits[$],
        ref usb_ref_tx_symbol_t symbols[$]
    );

        bit encoded_level;
        bit stuffed_bits[$];

        usb_ref_line_e line_state;

        symbols.delete();
        stuffed_bits.delete();

        if (tx_stuff_enabled)
            bit_stuff(data_bits, stuffed_bits);
        else
            stuffed_bits = data_bits;

        tx_nrzi_previous = 1'b1;

        foreach (stuffed_bits[i]) begin

            if (tx_nrzi_enabled)
                encoded_level = nrzi_encode_bit(
                    stuffed_bits[i],
                    tx_nrzi_previous
                );
            else
                encoded_level = stuffed_bits[i];

            if (encoded_level)
                line_state = get_j_state();
            else
                line_state = get_k_state();

            symbols.push_back('{
                dp: encode_line(line_state)[1],
                dm: encode_line(line_state)[0],
                tx_valid: 1'b1,
                is_stuffed: 1'b0,
                is_eop: 1'b0
            });

            tx_symbol_count++;

        end

    endfunction


    // --------------------------------------------------------
    // Generate EOP symbols
    //
    // LS/FS:
    // SE0 for two bit times, then J for one bit time.
    //
    // HS:
    // EOP behavior is represented here as a configurable
    // symbol count. Confirm the exact HS EOP implementation
    // in the RTL before using this as a cycle-exact checker.
    // --------------------------------------------------------

    function void append_eop(
        ref usb_ref_tx_symbol_t symbols[$],
        input int unsigned eop_symbol_count = 3
    );

        usb_ref_line_e line_state;

        if (speed == HS)
            eop_symbol_count = 8;
        else
            eop_symbol_count = 3;

        for (int i = 0; i < eop_symbol_count; i++) begin

            if (speed == HS) begin

                // Abstract HS EOP marker.
                // Exact polarity must match the RTL architecture.
                line_state = get_j_state();

                symbols.push_back('{
                    dp: encode_line(line_state)[1],
                    dm: encode_line(line_state)[0],
                    tx_valid: 1'b1,
                    is_stuffed: 1'b0,
                    is_eop: 1'b1
                });

            end
            else if (i < 2) begin

                symbols.push_back('{
                    dp: 1'b0,
                    dm: 1'b0,
                    tx_valid: 1'b1,
                    is_stuffed: 1'b0,
                    is_eop: 1'b1
                });

            end
            else begin

                line_state = get_j_state();

                symbols.push_back('{
                    dp: encode_line(line_state)[1],
                    dm: encode_line(line_state)[0],
                    tx_valid: 1'b1,
                    is_stuffed: 1'b0,
                    is_eop: 1'b1
                });

            end

        end

    endfunction


    // --------------------------------------------------------
    // Build expected TX byte stream
    //
    // The input is a sequence of SIE bytes.
    // SOP indicates packet start.
    // EOP indicates packet end.
    //
    // PID/CRC are optional because they may be generated
    // outside the PHY in the SIE/link layer.
    // --------------------------------------------------------

    function void build_tx_packet(
        input logic [7:0] payload[$],
        input bit add_sync,
        input bit add_eop,
        ref usb_ref_tx_symbol_t expected_symbols[$]
    );

        bit data_bits[$];

        usb_ref_line_e sync_symbols[$];

        usb_ref_tx_symbol_t encoded_symbols[$];

        expected_symbols.delete();
        data_bits.delete();

        if (add_sync) begin

            build_sync(sync_symbols);

            foreach (sync_symbols[i]) begin

                expected_symbols.push_back('{
                    dp: encode_line(sync_symbols[i])[1],
                    dm: encode_line(sync_symbols[i])[0],
                    tx_valid: 1'b1,
                    is_stuffed: 1'b0,
                    is_eop: 1'b0
                });

            end

        end

        foreach (payload[i])
            append_byte(payload[i], data_bits);

        if (tx_crc_enabled)
            append_crc16(data_bits);

        encode_tx_bits(data_bits, encoded_symbols);

        foreach (encoded_symbols[i])
            expected_symbols.push_back(encoded_symbols[i]);

        if (add_eop && tx_eop_enabled)
            append_eop(expected_symbols);

        tx_packet_count++;

    endfunction


    // --------------------------------------------------------
    // RX: decode a sequence of sampled NRZI levels
    //
    // This API accepts already sampled logical NRZI levels.
    // CDR sampling and physical line-state qualification
    // are handled separately.
    // --------------------------------------------------------

    function void decode_rx_levels(
        input bit nrzi_levels[$],
        ref bit decoded_bits[$]
    );

        bit current_level;

        decoded_bits.delete();

        rx_nrzi_previous = 1'b1;

        foreach (nrzi_levels[i]) begin

            current_level = nrzi_levels[i];

            decoded_bits.push_back(
                nrzi_decode_bit(
                    current_level,
                    rx_nrzi_previous
                )
            );

        end

    endfunction


    // --------------------------------------------------------
    // RX: convert decoded bits into bytes
    //
    // USB bytes are transmitted LSB first.
    // --------------------------------------------------------

    function void bits_to_rx_bytes(
        input bit decoded_bits[$],
        ref usb_ref_rx_result_t rx_bytes[$]
    );

        usb_ref_rx_result_t result;

        logic [7:0] data;
        int unsigned bit_index;

        rx_bytes.delete();

        data = '0;
        bit_index = 0;

        foreach (decoded_bits[i]) begin

            data[bit_index] = decoded_bits[i];

            bit_index++;

            if (bit_index == 8) begin

                result = '{
                    data: data,
                    valid: 1'b1,
                    sop: 1'b0,
                    eop: 1'b0,
                    error: rx_stuff_error |
                           rx_align_error |
                           rx_line_error |
                           rx_sync_error,
                    stuff_error: rx_stuff_error,
                    align_error: rx_align_error,
                    sync_error: rx_sync_error
                };

                rx_bytes.push_back(result);

                rx_byte_count++;

                data = '0;
                bit_index = 0;

            end

        end

        if (bit_index != 0) begin
            rx_align_error = 1'b1;
            rx_error_count++;
        end

    endfunction


    // --------------------------------------------------------
    // RX: decode a packet's data bits
    //
    // Input must exclude SYNC and EOP symbols.
    // --------------------------------------------------------

    function void decode_rx_packet(
        input bit nrzi_levels[$],
        ref usb_ref_rx_result_t rx_bytes[$]
    );

        bit decoded_bits[$];
        bit unstuffed_bits[$];

        rx_stuff_error = 1'b0;
        rx_align_error = 1'b0;
        rx_line_error  = 1'b0;
        rx_sync_error  = 1'b0;

        decode_rx_levels(
            nrzi_levels,
            decoded_bits
        );

        if (!bit_unstuff(decoded_bits, unstuffed_bits)) begin
            rx_stuff_error = 1'b1;
            rx_error_count++;
        end

        bits_to_rx_bytes(
            unstuffed_bits,
            rx_bytes
        );

        if (rx_bytes.size() != 0)
            rx_packet_count++;

    endfunction


    // --------------------------------------------------------
    // RX: line-state validation
    // --------------------------------------------------------

    function bit check_rx_line_state(
        logic dp,
        logic dm
    );

        if ({dp, dm} == 2'b11) begin
            rx_line_error = 1'b1;
            rx_error_count++;
            return 1'b0;
        end

        return 1'b1;

    endfunction


    // --------------------------------------------------------
    // RX: EOP detection
    //
    // LS/FS EOP:
    // SE0 followed by J.
    //
    // This checks line-state sequence, not exact timing.
    // --------------------------------------------------------

    function bit check_rx_eop(
        input usb_ref_line_e line_history[$]
    );

        int unsigned size;

        size = line_history.size();

        if (size < 3)
            return 1'b0;

        if (
            line_history[size-3] == REF_SE0 &&
            line_history[size-2] == REF_SE0 &&
            line_history[size-1] == get_j_state()
        ) begin

            return 1'b1;

        end

        return 1'b0;

    endfunction


    // --------------------------------------------------------
    // RX: SYNC detection
    //
    // The caller supplies the decoded logical SYNC bits.
    // --------------------------------------------------------

    function bit check_rx_sync(
        input bit sync_bits[$]
    );

        bit expected_bits[$];

        expected_bits.delete();

        if (speed == HS) begin

            for (int i = 0; i < 15; i++) begin
                expected_bits.push_back(1'b0);
                expected_bits.push_back(1'b1);
            end

            expected_bits.push_back(1'b0);
            expected_bits.push_back(1'b0);

        end
        else begin

            expected_bits.push_back(1'b0);
            expected_bits.push_back(1'b1);
            expected_bits.push_back(1'b0);
            expected_bits.push_back(1'b1);
            expected_bits.push_back(1'b0);
            expected_bits.push_back(1'b1);
            expected_bits.push_back(1'b0);
            expected_bits.push_back(1'b0);

        end

        if (sync_bits.size() != expected_bits.size()) begin
            rx_sync_error = 1'b1;
            return 1'b0;
        end

        foreach (expected_bits[i]) begin

            if (sync_bits[i] != expected_bits[i]) begin
                rx_sync_error = 1'b1;
                return 1'b0;
            end

        end

        rx_sync_detected = 1'b1;

        return 1'b1;

    endfunction


    // --------------------------------------------------------
    // CDR: process one oversampled input sample
    //
    // This abstract model:
    // 1. Detects input transitions.
    // 2. Tracks phase error relative to expected bit center.
    // 3. Accumulates edge observations for lock.
    // 4. Generates a recovered sample strobe.
    //
    // It is not a cycle-exact model of a specific digital
    // loop filter or phase accumulator.
    // --------------------------------------------------------

    function usb_ref_cdr_result_t process_cdr_sample(
        input bit serial_sample
    );

        usb_ref_cdr_result_t result;

        bit edge_detected;

        edge_detected = (
            serial_sample != cdr_previous_sample
        );

        cdr_recovered_strobe = 1'b0;

        if (edge_detected) begin

            cdr_edge_count++;

            cdr_edge_seen = 1'b1;

            cdr_lock_count++;
            cdr_unlock_count = 0;

            cdr_phase_error = 0;

            if (
                !cdr_locked &&
                cdr_lock_count >= cdr_lock_threshold
            ) begin

                cdr_locked = 1'b1;
                cdr_lock_events++;

            end

        end
        else begin

            cdr_unlock_count++;

            if (
                cdr_locked &&
                cdr_unlock_count >= cdr_unlock_threshold *
                                    oversampling_ratio
            ) begin

                cdr_locked = 1'b0;
                cdr_unlock_events++;

            end

        end

        cdr_previous_sample = serial_sample;

        if (cdr_enabled && cdr_locked) begin

            cdr_sample_count++;

            if (
                cdr_sample_count >= oversampling_ratio
            ) begin

                cdr_sample_count = 0;
                cdr_recovered_strobe = 1'b1;

            end

        end
        else begin

            cdr_sample_count = 0;

        end

        result = '{
            recovered_bit_clk: cdr_recovered_strobe,
            locked: cdr_locked,
            edge_detected: edge_detected,
            phase_error: cdr_phase_error
        };

        return result;

    endfunction


    // --------------------------------------------------------
    // CDR enable / disable
    // --------------------------------------------------------

    function void enable_cdr(bit enable);

        cdr_enabled = enable;

        if (!enable)
            reset_cdr();

    endfunction


    // --------------------------------------------------------
    // Expected bit timing
    // --------------------------------------------------------

    function automatic int unsigned get_bit_period();

        return clocks_per_bit;

    endfunction


    // --------------------------------------------------------
    // Check TX symbol against actual DP/DM
    // --------------------------------------------------------

    function bit compare_tx_symbol(
        usb_ref_tx_symbol_t expected,
        logic actual_dp,
        logic actual_dm
    );

        if (
            expected.dp === actual_dp &&
            expected.dm === actual_dm
        ) begin

            return 1'b1;

        end

        return 1'b0;

    endfunction


    // --------------------------------------------------------
    // Print reference-model statistics
    // --------------------------------------------------------

    function void report_statistics();

        $display("");
        $display("==============================================");
        $display(" USB 2.0 PHY REFERENCE MODEL STATISTICS");
        $display("==============================================");

        $display("USB speed              : %0d", speed);
        $display("Clocks per USB bit     : %0d", clocks_per_bit);

        $display("TX packets             : %0d", tx_packet_count);
        $display("TX symbols             : %0d", tx_symbol_count);
        $display("TX stuffed bits        : %0d", tx_stuffed_bit_count);

        $display("RX packets             : %0d", rx_packet_count);
        $display("RX bytes               : %0d", rx_byte_count);
        $display("RX errors              : %0d", rx_error_count);

        $display("CDR edges              : %0d", cdr_edge_count);
        $display("CDR lock events        : %0d", cdr_lock_events);
        $display("CDR unlock events      : %0d", cdr_unlock_events);

        $display("==============================================");
        $display("");

    endfunction


endclass 
