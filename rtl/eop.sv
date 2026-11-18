// file: eop.sv   (module usb_eop_gen)
//
// EOP generator.  Runs on the same bit_tick as the data path.
//  FS / LS : SE0, SE0, J            (2 bit times SE0 + 1 bit time J)
//            J is the *speed-correct* J  (FS: DP=1,DM=0   LS: DP=0,DM=1)
//  HS      : NRZ 0111_1111 with no stuffing = 8 symbols (40 for SOF) of the
//            polarity opposite to the last data symbol
//            (last data symbol J -> K x8, last K -> J x8)
//
// eop_start is the nrzi "valid && last" level.  It is sampled on the bit_tick
// that ends the last data bit time, so the first EOP symbol follows the last
// data symbol with no gap.
// eop_done is high during the final EOP slot and releases the PISO from HOLD
// on that same tick.  The next packet can start only after it has travelled
// through FIFO -> PISO again, which provides the gap between packets.
module usb_eop_gen
(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       bit_tick,
    input  speed_t     usb_speed,

    input  logic       eop_start,          // last data symbol is on the line
    input  logic       sof_packet,         // HS only: 40-bit EOP
    input  logic       last_nrzi_state,    // 1 = last symbol was J, 0 = K

    output logic [1:0] eop_line_state,     // {DP, DM}
    output logic       eop_valid,
    output logic       eop_done,
    output logic       busy
);
    localparam logic [1:0] LINE_SE0  = 2'b00;
    localparam logic [1:0] LINE_J_FS = 2'b10;   // FS / HS J
    localparam logic [1:0] LINE_J_LS = 2'b01;   // LS J (inverted)

    typedef enum logic [2:0] { IDLE, SE0_1, SE0_2, FS_J, HS_EOP } state_t;
    state_t state;

    logic [5:0] cnt;
    logic [5:0] hs_len;
    logic       force_k;               // HS: 1 = drive K, 0 = drive J

    logic [1:0] line_j, line_k;
    assign line_j = (usb_speed == LS) ? LINE_J_LS : LINE_J_FS;
    assign line_k = ~line_j;

    assign eop_done = (state == FS_J) ||
                      (state == HS_EOP && cnt == hs_len - 1'b1);

    always_comb begin
        eop_line_state = line_j;
        eop_valid      = 1'b0;
        busy           = (state != IDLE);
        unique case (state)
            SE0_1, SE0_2: begin eop_line_state = LINE_SE0; eop_valid = 1'b1; end
            FS_J:         begin eop_line_state = line_j;   eop_valid = 1'b1; end
            HS_EOP:       begin eop_line_state = force_k ? line_k : line_j;
                                eop_valid = 1'b1; end
            default: ;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            cnt     <= '0;
            hs_len  <= 6'd8;
            force_k <= 1'b0;
        end else if (bit_tick) begin
            unique case (state)
                IDLE: if (eop_start) begin
                    cnt <= '0;
                    if (usb_speed == HS) begin
                        force_k <= last_nrzi_state;          // last J -> K
                        hs_len  <= sof_packet ? 6'd40 : 6'd8;
                        state   <= HS_EOP;
                    end else
                        state <= SE0_1;
                end

                SE0_1: state <= SE0_2;
                SE0_2: state <= FS_J;
                FS_J:  state <= IDLE;

                HS_EOP: begin
                    if (cnt == hs_len - 1'b1) begin
                        cnt   <= '0;
                        state <= IDLE;
                    end else
                        cnt <= cnt + 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

