module uart_tx #(parameter b = 8)(
    input sys_rst_l, xmitH, sys_clk, tx_enable,
    input [b-1:0] xmit_dataH,
    output reg uart_XMIT_dataH,
    output reg xmit_doneH,
    output reg xmit_active
);

localparam IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
reg [1:0] state;
reg [b-1:0] st_reg;
reg [3:0] count;
reg [$clog2(b)-1:0] count_b;

always @(posedge sys_clk or negedge sys_rst_l) begin
    if (!sys_rst_l)
        state <= IDLE;
    else if (tx_enable) begin
        case (state)
            IDLE    : state <= xmitH ? START : IDLE;
            START   : state <= (count == 15) ? DATA : START;
            DATA    : state <= (count == 15 && count_b == b-1) ? STOP : DATA;
            STOP    : state <= (count == 15) ? IDLE : STOP;
            default : state <= IDLE;
        endcase
    end
end

always @(posedge sys_clk or negedge sys_rst_l) begin
    if (!sys_rst_l) begin
        uart_XMIT_dataH <= 1;
        xmit_doneH      <= 1;
        xmit_active     <= 0;
        count           <= 0;
        count_b         <= 0;
        st_reg          <= 0;
    end else if (tx_enable) begin
        case (state)
            IDLE: begin
                uart_XMIT_dataH <= 1;
                xmit_active     <= 0;
                xmit_doneH      <= 1;
                count           <= 0;
                count_b         <= 0;
                if (xmitH) begin
                    st_reg      <= xmit_dataH;
                    xmit_active <= 1;
                    xmit_doneH  <= 0;
                end
            end

            START: begin
                uart_XMIT_dataH <= 0;
                xmit_active     <= 1;
                xmit_doneH      <= 0;
                count           <= count + 1;
                if (count == 15)
                    count <= 0;
            end

            DATA: begin
                uart_XMIT_dataH <= st_reg[0];
                xmit_active     <= 1;
                xmit_doneH      <= 0;
                count           <= count + 1;
                if (count == 15) begin
                    count  <= 0;
                    st_reg <= st_reg >> 1;
                    if (count_b == b-1)
                        count_b <= 0;
                    else
                        count_b <= count_b + 1;
                end
            end

            STOP: begin
                uart_XMIT_dataH <= 1;
                xmit_active     <= 1;
                xmit_doneH      <= 0;
                count           <= count + 1;
                if (count == 15) begin
                    count       <= 0;
                    xmit_active <= 0;
                    xmit_doneH  <= 1;
                end
            end

            default: begin
                uart_XMIT_dataH <= 1;
                xmit_active     <= 0;
                xmit_doneH      <= 1;
                count           <= 0;
                count_b         <= 0;
            end
        endcase
    end
end

endmodule
