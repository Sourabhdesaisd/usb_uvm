// file: tx_holding_reg.sv   (module usb2_tx_fifo)
// SIE -> PHY holding FIFO.  Unchanged in function; "piso_ready" is now a
// 1-clk POP strobe driven by the PISO only on the clk where it really
// consumes fifo_data (so no second holding register is needed in the PISO).
module usb2_tx_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int FIFO_DEPTH = 16
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // SIE side
    input  logic [DATA_WIDTH-1:0] sie_data,
    input  logic                  sie_valid,
    input  logic                  sie_sop,
    input  logic                  sie_eop,
    output logic                  sie_ready,

    // PISO side
    output logic [DATA_WIDTH-1:0] fifo_data,
    output logic                  fifo_valid,
    output logic                  fifo_sop,
    output logic                  fifo_eop,
    input  logic                  piso_ready,   // pop strobe

    output logic                  fifo_full,
    output logic                  fifo_empty
);
    localparam int PTR_W   = $clog2(FIFO_DEPTH);
    localparam int COUNT_W = $clog2(FIFO_DEPTH+1);

    logic [DATA_WIDTH+1:0] mem [0:FIFO_DEPTH-1];
    logic [PTR_W-1:0]      wr_ptr, rd_ptr;
    logic [COUNT_W-1:0]    count;
    logic push, pop;

    assign fifo_empty = (count == 0);
    assign fifo_full  = (count == FIFO_DEPTH);
    assign sie_ready  = !fifo_full;
    assign fifo_valid = !fifo_empty;

    assign push = sie_valid && sie_ready;
    assign pop  = fifo_valid && piso_ready;

    assign {fifo_sop, fifo_eop, fifo_data} = mem[rd_ptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            if (push) begin
                mem[wr_ptr] <= {sie_sop, sie_eop, sie_data};
                wr_ptr <= (wr_ptr == PTR_W'(FIFO_DEPTH-1)) ? '0 : wr_ptr + 1'b1;
            end
            if (pop)
                rd_ptr <= (rd_ptr == PTR_W'(FIFO_DEPTH-1)) ? '0 : rd_ptr + 1'b1;

            unique case ({push, pop})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: ;
            endcase
        end
    end
endmodule

