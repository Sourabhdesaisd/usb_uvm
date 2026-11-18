// file: bit_en_generator.sv
// Bit-tick generator : one 1-clk pulse per USB bit time.
//   HS : every clk        (480 Mb/s @ 480 MHz)
//   FS : every 40 clks    (12  Mb/s @ 480 MHz)
//   LS : every 320 clks   (1.5 Mb/s @ 480 MHz)
// Every TX block advances ONLY on this pulse, so a symbol on the line
// lasts exactly one bit time.
module usb_speed_tick
#(
    parameter int CLK_HZ = 480_000_000
)(
    input  logic     clk,
    input  logic     rst_n,
    input  speed_t   usb_speed,
    output logic     bit_tick
);
    localparam int FS_DIV = CLK_HZ / 12_000_000;
    localparam int LS_DIV = CLK_HZ / 1_500_000;
    localparam int CNT_W  = $clog2(LS_DIV + 1);

    logic [CNT_W-1:0] counter;
    logic [CNT_W-1:0] terminal_count;

    always_comb begin
        unique case (usb_speed)
            LS:      terminal_count = CNT_W'(LS_DIV - 1);
            FS:      terminal_count = CNT_W'(FS_DIV - 1);
            default: terminal_count = '0;               // HS : tick every clk
        endcase
    end

    // period = terminal_count + 1 clks, tick is high for exactly 1 clk
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter  <= '0;
            bit_tick <= 1'b0;
        end else if (counter >= terminal_count) begin
            counter  <= '0;
            bit_tick <= 1'b1;
        end else begin
            counter  <= counter + 1'b1;
            bit_tick <= 1'b0;
        end
    end
endmodule

