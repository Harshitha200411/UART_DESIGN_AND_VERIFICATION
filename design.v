//top module
module uart #(parameter b = 8)(
    input sys_rst_l, sys_clk, xmitH,
    input [b-1:0] data_in,
    input uart_REC_dataH,
    output wire uart_XMIT_dataH,
    output wire xmit_doneH,
    output wire [b-1:0] rec_dataH,
    output wire xmit_active, rec_busy, rec_readyH
);

wire clk_enable;

baud_rate baud (
    .rst(sys_rst_l),
    .clk(sys_clk),
    .clk_enable(clk_enable)
);

uart_tx #(b) tx (
    .sys_rst_l(sys_rst_l),
    .sys_clk(sys_clk),
    .tx_enable(clk_enable),
    .xmitH(xmitH),
    .xmit_dataH(data_in),
    .uart_XMIT_dataH(uart_XMIT_dataH),
    .xmit_doneH(xmit_doneH),
    .xmit_active(xmit_active)
);

uart_rx #(b) rx (
    .sys_rst_l(sys_rst_l),
    .sys_clk(sys_clk),
    .rx_enable(clk_enable),
    .rec_readyH(rec_readyH),
    .uart_REC_dataH(uart_REC_dataH),
    .rec_dataH(rec_dataH),
    .rec_busy(rec_busy)
);

endmodule


