module uart_ref_model(
    input            baud_clk,
    input            rst_n,
    input            xmitH,
    input [7:0]      xmit_dataH,
    input            serial_in,
    output reg [7:0] exp_rec_dataH,
    output reg       exp_rec_readyH,
    output reg       exp_rec_busy,
    output reg       exp_xmit_active,
    output reg       exp_xmit_doneH,
    output reg       exp_err
);

localparam BAUD_TICKS = 16;
localparam SAMP_TICK = 7;

reg [7:0] tx_shift;
reg [3:0] tx_counter;
reg [2:0] tx_bit_index;
reg [7:0] rx_shifter;
reg [3:0] rx_counter;
reg [2:0] rx_bit_index;
reg sync1, sync2;

parameter TX_IDLE = 2'd0, TX_START = 2'd1, TX_DATA = 2'd2, TX_STOP = 2'd3;
parameter RX_IDLE = 2'd0, RX_START = 2'd1, RX_DATA = 2'd2, RX_STOP = 2'd3;

reg [1:0] tx_state;
reg [1:0] rx_state;

always @(posedge baud_clk or negedge rst_n) begin
    if (!rst_n) begin
        sync1 <= 1'b1;
        sync2 <= 1'b1;
    end else begin
        sync1 <= serial_in;
        sync2 <= sync1;
    end
end

always @(posedge baud_clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_state <= TX_IDLE;
        tx_shift <= 8'b0;
        tx_counter <= 4'b0;
        tx_bit_index <= 3'b0;
        exp_xmit_active <= 1'b0;
        exp_xmit_doneH <= 1'b1;
    end else begin
        case (tx_state)
            TX_IDLE: begin
                exp_xmit_active <= 1'b0;
                exp_xmit_doneH <= 1'b1;
                tx_counter <= 4'b0;
                tx_bit_index <= 3'b0;
                if (xmitH) begin
                    tx_shift <= xmit_dataH;
                    tx_state <= TX_START;
                    exp_xmit_doneH <= 1'b0;
                end
            end

            TX_START: begin
                exp_xmit_active <= 1'b1;
                exp_xmit_doneH <= 1'b0;
                if (tx_counter == BAUD_TICKS - 1) begin
                    tx_counter <= 4'b0;
                    tx_state <= TX_DATA;
                end else begin
                    tx_counter <= tx_counter + 1'b1;
                end
            end

            TX_DATA: begin
                exp_xmit_active <= 1'b1;
                exp_xmit_doneH <= 1'b0;
                if (tx_counter == BAUD_TICKS - 1) begin
                    tx_counter <= 4'b0;
                    if (tx_bit_index == 7) begin
                        tx_state <= TX_STOP;
                    end else begin
                        tx_shift <= tx_shift >> 1;
                        tx_bit_index <= tx_bit_index + 1'b1;
                    end
                end else begin
                    tx_counter <= tx_counter + 1'b1;
                end
            end

            TX_STOP: begin
                exp_xmit_active <= 1'b1;
                exp_xmit_doneH <= 1'b0;
                if (tx_counter == BAUD_TICKS - 1) begin
                    tx_counter <= 4'b0;
                    tx_state <= TX_IDLE;
                    exp_xmit_active <= 1'b0;
                    exp_xmit_doneH <= 1'b1;
                end else begin
                    tx_counter <= tx_counter + 1'b1;
                end
            end
        endcase
    end
end

always @(posedge baud_clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_state <= RX_IDLE;
        rx_shifter <= 8'b0;
        rx_counter <= 4'b0;
        rx_bit_index <= 3'b0;
        exp_rec_dataH <= 8'b0;
        exp_rec_readyH <= 1'b1;
        exp_rec_busy <= 1'b0;
        exp_err <= 1'b0;
    end else begin
        case (rx_state)
            RX_IDLE: begin
                exp_rec_readyH <= 1'b1;
                exp_rec_busy <= 1'b0;
                exp_err <= 1'b0;
                rx_counter <= 4'b0;
                rx_bit_index <= 3'b0;
                if (sync2 == 1'b0) begin
                    rx_state <= RX_START;
                    exp_rec_readyH <= 1'b0;
                    exp_rec_busy <= 1'b1;
                end
            end

            RX_START: begin
                exp_rec_readyH <= 1'b0;
                exp_rec_busy <= 1'b1;
                if (rx_counter == SAMP_TICK) begin
                    if (sync2 == 1'b0) begin
                        rx_state <= RX_DATA;
                        rx_counter <= 4'b0;
                        rx_bit_index <= 3'b0;
                    end else begin
                        rx_state <= RX_IDLE;
                    end
                end else begin
                    rx_counter <= rx_counter + 1'b1;
                end
            end

            RX_DATA: begin
                exp_rec_readyH <= 1'b0;
                exp_rec_busy <= 1'b1;
                if (rx_counter == BAUD_TICKS - 1) begin
                    rx_shifter <= {sync2, rx_shifter[7:1]};
                    rx_counter <= 4'b0;
                    if (rx_bit_index == 7) begin
                        rx_state <= RX_STOP;
                    end else begin
                        rx_bit_index <= rx_bit_index + 1'b1;
                    end
                end else begin
                    rx_counter <= rx_counter + 1'b1;
                end
            end

            RX_STOP: begin
                exp_rec_readyH <= 1'b0;
                exp_rec_busy <= 1'b1;
                if (rx_counter == BAUD_TICKS - 1) begin
                    rx_counter <= 4'b0;
                    rx_state <= RX_IDLE;
                    exp_rec_readyH <= 1'b1;
                    exp_rec_busy <= 1'b0;
                    if (sync2 == 1'b1) begin
                        exp_rec_dataH <= rx_shifter;
                    end else begin
                        exp_err <= 1'b1;
                    end
                end else begin
                    rx_counter <= rx_counter + 1'b1;
                end
            end
        endcase
    end
end

endmodule
