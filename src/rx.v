module uart_rx #(parameter b = 8)(
    input sys_rst_l, sys_clk, rx_enable, uart_REC_dataH,
    output reg [b-1:0] rec_dataH,
    output reg rec_busy,
    output reg rec_readyH
);

localparam IDLE = 2'b00, START = 2'b01, DATAOUT = 2'b10, STOP = 2'b11;
reg [1:0] state;
reg [$clog2(b)-1:0] count_b;
reg [3:0] count;
reg [b-1:0] st_reg;
reg F1, F2;

always @(posedge sys_clk or negedge sys_rst_l) begin
    if (!sys_rst_l) begin
        F1 <= 1;
        F2 <= 1;
    end else begin
        F1 <= uart_REC_dataH;
        F2 <= F1;
    end
end

always @(posedge sys_clk or negedge sys_rst_l) begin
    if (!sys_rst_l)
        state <= IDLE;
    else if (rx_enable) begin
        case (state)
            IDLE    : state <= (F2 == 0) ? START : IDLE;
            START   : state <= (count == 7) ? (F2 == 0 ? DATAOUT : IDLE) : START;
            DATAOUT : state <= (count == 15 && count_b == b-1) ? STOP : DATAOUT;
            STOP    : state <= (count == 15) ? IDLE : STOP;
            default : state <= IDLE;
        endcase
    end
end

always @(posedge sys_clk or negedge sys_rst_l) begin
    if (!sys_rst_l) begin
        rec_busy   <= 0;
        rec_readyH <= 1;
        rec_dataH  <= 0;
        count      <= 0;
        count_b    <= 0;
        st_reg     <= 0;
    end else if (rx_enable) begin
        case (state)
            IDLE: begin
                rec_busy   <= 0;
                rec_readyH <= 1;
                count      <= 0;
                count_b    <= 0;
                if (F2 == 0) begin
                    rec_busy   <= 1;
                    rec_readyH <= 0;
                end
            end

            START: begin
                rec_busy   <= 1;
                rec_readyH <= 0;
                count      <= count + 1;
                if (count == 7) begin
                    count <= 0;
                    if (F2 != 0) begin
                        rec_busy   <= 0;
                        rec_readyH <= 1;
                    end
                end
            end

            DATAOUT: begin
                rec_busy   <= 1;
                rec_readyH <= 0;
                count      <= count + 1;
                if (count == 15) begin
                    count           <= 0;
                    st_reg[count_b] <= F2;
                    if (count_b == b-1)
                        count_b <= 0;
                    else
                        count_b <= count_b + 1;
                end
            end

            STOP: begin
                rec_busy   <= 1;
                rec_readyH <= 0;
                count      <= count + 1;
                if (count == 15) begin
                    count      <= 0;
                    rec_busy   <= 0;
                    rec_readyH <= 1;
                    if (F2 == 1)
                        rec_dataH <= st_reg;
                end
            end
        endcase
    end
end

endmodule
