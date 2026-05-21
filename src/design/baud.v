module baud_rate (
    input clk,rst,
    output reg clk_enable
);

parameter br = 2400, clk_freq  = 50000000;
parameter clk_value = clk_freq / (br * 16 * 2);

reg [$clog2(clk_value)-1:0] count;

always @ (posedge clk or negedge rst) begin
    if (!rst) begin
        count      <= 0;
        clk_enable <= 0;
    end else begin
        clk_enable <= 0;
        if(count == clk_value - 1) begin
            count <= 0;
            clk_enable <= 1;
        end
        else
            count <= count + 1;
    end
end

endmodule
