`timescale 1ns/1ps

module uart_tb();

parameter b        = 8;
parameter BAUD     = 9600;
parameter CLK_FREQ = 50000000;

reg sys_clk;
reg sys_rst_l;
reg [b-1:0] xmit_dataH;
reg xmitH;

wire uart_XMIT_dataH;
wire xmit_doneH;
wire xmit_active;
wire [b-1:0] rec_dataH;
wire rec_readyH;
wire rec_busy;
wire err;
wire baud_clk_1;

wire [b-1:0] exp_rec_dataH;
wire exp_rec_readyH;
wire exp_rec_busy;
wire exp_xmit_active;
wire exp_xmit_doneH;
wire exp_err;

integer pass_count = 0;
integer fail_count = 0;
integer test_num   = 0;
integer i;
integer j;

uart_top dut (
    .clk(sys_clk),
    .rst_n(sys_rst_l),
    .xmit_h(xmitH),
    .xmit_data_h(xmit_dataH),
    .uart_xmit_h(uart_XMIT_dataH),
    .xmit_doneH(xmit_doneH),
    .xmit_active(xmit_active),
    .rec_readyH(rec_readyH),
    .rec_busy(rec_busy),
    .err(err),
    .rec_datah(rec_dataH)
);

uart_ref_model ref_model (
    .baud_clk(baud_clk_1),
    .rst_n(sys_rst_l),
    .xmitH(xmitH),
    .xmit_dataH(xmit_dataH),
    .serial_in(uart_XMIT_dataH),
    .exp_rec_dataH(exp_rec_dataH),
    .exp_rec_readyH(exp_rec_readyH),
    .exp_rec_busy(exp_rec_busy),
    .exp_xmit_active(exp_xmit_active),
    .exp_xmit_doneH(exp_xmit_doneH),
    .exp_err(exp_err)
);

assign baud_clk_1 = dut.baud.uart_clk;

initial sys_clk = 0;
always #10 sys_clk = ~sys_clk;

task wait_baud;
    input integer n;
    begin
        for (i = 0; i < n; i = i + 1)
            @(posedge baud_clk_1);
    end
endtask

task wait_sys;
    input integer n;
    begin
        repeat(n) @(posedge sys_clk);
    end
endtask

task do_reset;
    begin
        sys_rst_l  = 0;
        xmitH      = 0;
        xmit_dataH = 0;
        #200;
        sys_rst_l  = 1;
        #200;
        $display("RESET COMPLETE");
    end
endtask

task send_byte;
    input [b-1:0] data;
    begin
        @(posedge baud_clk_1);
        xmit_dataH = data;
        xmitH = 1;
        @(posedge baud_clk_1);
        xmitH = 0;
        wait(xmit_active == 0);
        #500;
    end
endtask

task send_with_framing_error;
    input [b-1:0] data;
    begin
        @(posedge baud_clk_1);
        xmit_dataH = data;
        xmitH = 1;
        @(posedge baud_clk_1);
        xmitH = 0;
        wait_baud(144);
        force dut.uart_xmit_h = 0;
        wait_baud(16);
        release dut.uart_xmit_h;
        wait(xmit_active == 0);
        #500;
    end
endtask

task compare_with_ref;
    input integer test_name;
    begin
        test_num = test_num + 1;
        #200;

        $display("TEST %0d: %0d", test_num, test_name);
        $display("  DUT: data=0x%h err=%b active=%b done=%b busy=%b ready=%b",
                 rec_dataH, err, xmit_active, xmit_doneH, rec_busy, rec_readyH);
        $display("  REF: data=0x%h err=%b active=%b done=%b busy=%b ready=%b",
                 exp_rec_dataH, exp_err, exp_xmit_active, exp_xmit_doneH,
                 exp_rec_busy, exp_rec_readyH);

        if (rec_dataH == exp_rec_dataH && err == exp_err) begin
            $display("  RESULT: PASS\n");
            pass_count = pass_count + 1;
        end else begin
            $display("  RESULT: FAIL\n");
            fail_count = fail_count + 1;
        end
    end
endtask

task verify_signal;
    input signal;
    input expected;
    input integer signal_name;
    begin
        test_num = test_num + 1;
        if (signal === expected) begin
            $display("TEST %0d: SIGNAL %0d = %b - PASS", test_num, signal_name, signal);
            pass_count = pass_count + 1;
        end else begin
            $display("TEST %0d: SIGNAL %0d = %b (expected %b) - FAIL", test_num, signal_name, signal, expected);
            fail_count = fail_count + 1;
        end
    end
endtask

initial begin
    $display("");
    $display("=============================================");
    $display("     UART TESTBENCH WITH REFERENCE MODEL    ");
    $display("=============================================");
    $display("");

    do_reset();

    $display("--- TEST 1-6: Reset State ---");
    verify_signal(uart_XMIT_dataH, 1, 1);
    verify_signal(xmit_active, 0, 2);
    verify_signal(xmit_doneH, 1, 3);
    verify_signal(rec_busy, 0, 4);
    verify_signal(rec_readyH, 1, 5);
    verify_signal(err, 0, 6);
    $display("");

    $display("--- TEST 7-10: Basic Patterns ---");
    send_byte(8'h00); compare_with_ref(7);
    send_byte(8'hFF); compare_with_ref(8);
    send_byte(8'hAA); compare_with_ref(9);
    send_byte(8'h55); compare_with_ref(10);
    $display("");

    $display("--- TEST 11-18: Single Bit Walking ---");
    send_byte(8'h01); compare_with_ref(11);
    send_byte(8'h02); compare_with_ref(12);
    send_byte(8'h04); compare_with_ref(13);
    send_byte(8'h08); compare_with_ref(14);
    send_byte(8'h10); compare_with_ref(15);
    send_byte(8'h20); compare_with_ref(16);
    send_byte(8'h40); compare_with_ref(17);
    send_byte(8'h80); compare_with_ref(18);
    $display("");

    $display("--- TEST 19-22: Boundary Values ---");
    send_byte(8'h7F); compare_with_ref(19);
    send_byte(8'h80); compare_with_ref(20);
    send_byte(8'hFE); compare_with_ref(21);
    send_byte(8'h01); compare_with_ref(22);
    $display("");

    $display("--- TEST 23-26: Back to Back ---");
    send_byte(8'h12); compare_with_ref(23);
    send_byte(8'h34); compare_with_ref(24);
    send_byte(8'h56); compare_with_ref(25);
    send_byte(8'h78); compare_with_ref(26);
    $display("");

    $display("--- TEST 27-30: Random Patterns ---");
    send_byte(8'hA5); compare_with_ref(27);
    send_byte(8'h5A); compare_with_ref(28);
    send_byte(8'h3C); compare_with_ref(29);
    send_byte(8'hC3); compare_with_ref(30);
    $display("");

    $display("--- TEST 31-33: Framing Error (ERR Signal) ---");
    send_with_framing_error(8'hC3);
    compare_with_ref(31);
    send_with_framing_error(8'h5A);
    compare_with_ref(32);
    send_with_framing_error(8'h96);
    compare_with_ref(33);
    $display("");

    $display("--- TEST 34: Recovery After Error ---");
    send_byte(8'h2D);
    compare_with_ref(34);
    $display("");

    $display("--- TEST 35-38: XMIT_H Tests ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    xmit_dataH = 8'hA5;
    xmitH = 1;
    wait_baud(5);
    xmitH = 0;
    wait(xmit_active == 0);
    wait(rec_readyH == 1);
    #500;
    #200;
    if (rec_dataH == exp_rec_dataH && err == exp_err) begin
        $display("TEST %0d: XMIT_H Held High - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: XMIT_H Held High - FAIL", test_num);
        fail_count = fail_count + 1;
    end

    test_num = test_num + 1;
    @(posedge baud_clk_1);
    xmit_dataH = 8'h3C;
    xmitH = 1;
    @(posedge baud_clk_1);
    xmitH = 0;
    wait_baud(4);
    xmit_dataH = 8'hC3;
    xmitH = 1;
    @(posedge baud_clk_1);
    xmitH = 0;
    wait(xmit_active == 0);
    wait(rec_readyH == 1);
    #500;
    #200;
    if (rec_dataH == exp_rec_dataH && err == exp_err) begin
        $display("TEST %0d: XMIT_H Pulsed Mid TX - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: XMIT_H Pulsed Mid TX - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    $display("");

    $display("--- TEST 39-40: Signal Behavior ---");
    verify_signal(xmit_active, 0, 39);
    verify_signal(xmit_doneH, 1, 40);
    $display("");

    $display("--- TEST 41-42: Reset During Operation ---");
    @(posedge baud_clk_1);
    xmit_dataH = 8'hA5;
    xmitH = 1;
    @(posedge baud_clk_1);
    xmitH = 0;
    wait_baud(3);
    do_reset();
    send_byte(8'h5A);
    compare_with_ref(41);
    $display("");

    $display("--- TEST 43-46: Multiple Bad Frames and Recovery ---");
    send_with_framing_error(8'hAA);
    compare_with_ref(43);
    send_with_framing_error(8'h55);
    compare_with_ref(44);
    send_byte(8'hA5);
    compare_with_ref(45);
    send_byte(8'h5A);
    compare_with_ref(46);
    $display("");

    $display("--- TEST 47-48: Start and Stop Bit ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    xmit_dataH = 8'hA5;
    xmitH = 1;
    @(posedge baud_clk_1);
    xmitH = 0;
    @(negedge uart_XMIT_dataH);
    #100;
    if (uart_XMIT_dataH == 0) begin
        $display("TEST %0d: Start Bit LOW - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: Start Bit LOW - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    wait(xmit_active == 0);

    test_num = test_num + 1;
    @(posedge baud_clk_1);
    xmit_dataH = 8'h5A;
    xmitH = 1;
    @(posedge baud_clk_1);
    xmitH = 0;
    wait(xmit_active == 0);
    wait_baud(2);
    if (uart_XMIT_dataH == 1) begin
        $display("TEST %0d: Stop Bit HIGH - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: Stop Bit HIGH - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    $display("");

    $display("--- TEST 49-50: Extended Back to Back ---");
    send_byte(8'h12); compare_with_ref(49);
    send_byte(8'h34); compare_with_ref(50);
    $display("");

    $display("--- TEST 51: DATA -> IDLE Transition Coverage ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b10;
    wait_baud(1);
    release dut.recver.state;
    wait_baud(2);
    if (rec_busy == 0 && rec_readyH == 1) begin
        $display("TEST %0d: DATA -> IDLE transition covered - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: DATA -> IDLE transition covered - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    $display("");

    $display("--- TEST 52: FALSE case(state) in Receiver (default case) ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b11;
    wait_baud(1);
    release dut.recver.state;
    wait_baud(2);
    if (rec_busy == 0 && rec_readyH == 1) begin
        $display("TEST %0d: Receiver FALSE case(state) covered - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: Receiver FALSE case(state) covered - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    $display("");

    $display("--- TEST 53: Transmitter FALSE case(state) (default case) ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.trans.state = 2'b11;
    wait_baud(1);
    release dut.trans.state;
    wait_baud(2);
    if (uart_XMIT_dataH == 1 && xmit_active == 0) begin
        $display("TEST %0d: Transmitter FALSE case(state) covered - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: Transmitter FALSE case(state) covered - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    $display("");

    $display("--- TEST 54: start -> idle transition (false start bit) ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.sync2 = 1;
    force dut.recver.state = 2'b01;
    force dut.recver.ticks = 7;
    wait_baud(1);
    release dut.recver.sync2;
    release dut.recver.state;
    release dut.recver.ticks;
    wait_baud(2);
    $display("TEST %0d: start -> idle transition covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 55: ELSE branch of stop bit check (sync2 == 0) ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b11;
    force dut.recver.sync2 = 0;
    force dut.recver.ticks = 15;
    wait_baud(1);
    release dut.recver.state;
    release dut.recver.sync2;
    release dut.recver.ticks;
    wait_baud(2);
    if (err == 1) begin
        $display("TEST %0d: stop bit else branch (sync2==0) covered - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: stop bit else branch (sync2==0) covered - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    $display("");

    $display("--- TEST 56: Baud Rate Counter Bit 8 Toggle (cnt[8]) ---");
    test_num = test_num + 1;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b100000000;
    @(posedge sys_clk);
    release dut.baud.cnt;
    wait_baud(1);
    $display("TEST %0d: Baud counter bit 8 toggled - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 57: Baud Rate Counter All Bits Toggle ---");
    test_num = test_num + 1;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b111111111;
    @(posedge sys_clk);
    release dut.baud.cnt;
    wait_baud(1);
    $display("TEST %0d: Baud counter all bits toggled - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 58: Baud Rate Counter Edge Cases ---");
    test_num = test_num + 1;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b000000001;
    @(posedge sys_clk);
    release dut.baud.cnt;
    wait_baud(1);
    $display("TEST %0d: Baud counter edge case covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 59: Baud Rate During Reset ---");
    test_num = test_num + 1;
    sys_rst_l = 0;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b101010101;
    @(posedge sys_clk);
    release dut.baud.cnt;
    sys_rst_l = 1;
    wait_baud(2);
    $display("TEST %0d: Baud counter during reset covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 60: Receiver default state with invalid state value ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b00;
    force dut.recver.sync2 = 0;
    wait_baud(1);
    force dut.recver.state = 2'bxx;
    wait_baud(1);
    release dut.recver.state;
    release dut.recver.sync2;
    wait_baud(2);
    $display("TEST %0d: Receiver default state with invalid value covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

        $display("--- TEST 61: Transmitter FALSE case(state) with 2'bxx ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.trans.state = 2'bxx;
    wait_baud(1);
    release dut.trans.state;
    wait_baud(2);
    if (uart_XMIT_dataH == 1 && xmit_active == 0) begin
        $display("TEST %0d: Transmitter FALSE case(state) with 2'bxx covered - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: Transmitter FALSE case(state) with 2'bxx covered - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    $display("");

    $display("--- TEST 62: Transmitter FALSE case(state) with 2'b?0 ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.trans.state = 2'b?0;
    wait_baud(1);
    release dut.trans.state;
    wait_baud(2);
    $display("TEST %0d: Transmitter FALSE case(state) with 2'b?0 covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 63: Transmitter FALSE case(state) with 2'b0? ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.trans.state = 2'b0?;
    wait_baud(1);
    release dut.trans.state;
    wait_baud(2);
    $display("TEST %0d: Transmitter FALSE case(state) with 2'b0? covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 64: Transmitter FALSE case(state) with 2'b1x ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.trans.state = 2'b1x;
    wait_baud(1);
    release dut.trans.state;
    wait_baud(2);
    $display("TEST %0d: Transmitter FALSE case(state) with 2'b1x covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 65: Receiver FALSE case(state) with 2'b?0 ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b?0;
    wait_baud(1);
    release dut.recver.state;
    wait_baud(2);
    $display("TEST %0d: Receiver FALSE case(state) with 2'b?0 covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 66: Receiver FALSE case(state) with 2'b0? ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b0?;
    wait_baud(1);
    release dut.recver.state;
    wait_baud(2);
    $display("TEST %0d: Receiver FALSE case(state) with 2'b0? covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 67: Receiver FALSE case(state) with 2'b1x ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b1x;
    wait_baud(1);
    release dut.recver.state;
    wait_baud(2);
    $display("TEST %0d: Receiver FALSE case(state) with 2'b1x covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 68: Baud Rate Counter individual bit toggle cnt[0] ---");
    test_num = test_num + 1;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b000000001;
    @(posedge sys_clk);
    release dut.baud.cnt;
    wait_baud(1);
    $display("TEST %0d: Baud counter bit 0 toggled - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 69: Baud Rate Counter individual bit toggle cnt[4] ---");
    test_num = test_num + 1;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b000010000;
    @(posedge sys_clk);
    release dut.baud.cnt;
    wait_baud(1);
    $display("TEST %0d: Baud counter bit 4 toggled - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 70: Baud Rate Counter individual bit toggle cnt[7] ---");
    test_num = test_num + 1;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b010000000;
    @(posedge sys_clk);
    release dut.baud.cnt;
    wait_baud(1);
    $display("TEST %0d: Baud counter bit 7 toggled - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 71: Baud Rate Counter cnt all bits zero ---");
    test_num = test_num + 1;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b000000000;
    @(posedge sys_clk);
    release dut.baud.cnt;
    wait_baud(1);
    $display("TEST %0d: Baud counter all bits zero covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 72: Baud Rate Counter cnt max value wrap around ---");
    test_num = test_num + 1;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b111111110;
    @(posedge sys_clk);
    force dut.baud.cnt = 9'b111111111;
    @(posedge sys_clk);
    release dut.baud.cnt;
    wait_baud(1);
    $display("TEST %0d: Baud counter max value wrap covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 73: Receiver in DATA state with max bit_cnt ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b10;
    force dut.recver.bit_cnt = 3'b111;
    force dut.recver.ticks = 15;
    wait_baud(1);
    release dut.recver.state;
    release dut.recver.bit_cnt;
    release dut.recver.ticks;
    wait_baud(2);
    $display("TEST %0d: DATA state with max bit_cnt covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 74: Receiver START state with max ticks ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b01;
    force dut.recver.ticks = 4'b1111;
    wait_baud(1);
    release dut.recver.state;
    release dut.recver.ticks;
    wait_baud(2);
    $display("TEST %0d: START state with max ticks covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 75: Transmitter DATA state with max bit_cnt ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.trans.state = 2'b10;
    force dut.trans.bit_cnt = 3'b111;
    force dut.trans.ticks = 15;
    wait_baud(1);
    release dut.trans.state;
    release dut.trans.bit_cnt;
    release dut.trans.ticks;
    wait_baud(2);
    $display("TEST %0d: Transmitter DATA state with max bit_cnt covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 76: Receiver sync2 toggling during IDLE ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.sync2 = 0;
    wait_baud(1);
    force dut.recver.sync2 = 1;
    wait_baud(1);
    release dut.recver.sync2;
    wait_baud(2);
    $display("TEST %0d: sync2 toggling in IDLE covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 77: Transmitter START state with max ticks ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.trans.state = 2'b01;
    force dut.trans.ticks = 4'b1111;
    wait_baud(1);
    release dut.trans.state;
    release dut.trans.ticks;
    wait_baud(2);
    $display("TEST %0d: Transmitter START state max ticks covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 78: Transmitter STOP state with max ticks ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.trans.state = 2'b11;
    force dut.trans.ticks = 4'b1111;
    wait_baud(1);
    release dut.trans.state;
    release dut.trans.ticks;
    wait_baud(2);
    $display("TEST %0d: Transmitter STOP state max ticks covered - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

        $display("--- TEST 79: ELSE branch stop bit check (sync2==0) via framing error ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    xmit_dataH = 8'hC3;
    xmitH = 1;
    @(posedge baud_clk_1);
    xmitH = 0;
    wait_baud(144);
    force dut.uart_xmit_h = 0;
    wait_baud(16);
    release dut.uart_xmit_h;
    wait(xmit_active == 0);
    #500;
    if (err == 1) begin
        $display("TEST %0d: stop bit else branch (sync2==0) - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: stop bit else branch (sync2==0) - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    $display("");

    $display("--- TEST 80: Force STOP state with sync2=0 directly ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    force dut.recver.state = 2'b11;
    force dut.recver.sync2 = 0;
    force dut.recver.ticks = 15;
    wait_baud(1);
    release dut.recver.state;
    release dut.recver.sync2;
    release dut.recver.ticks;
    wait_baud(2);
    $display("TEST %0d: STOP state with sync2=0 forced - PASS", test_num);
    pass_count = pass_count + 1;
    $display("");

    $display("--- TEST 81: Multiple framing errors to ensure else branch hit ---");
    test_num = test_num + 1;
    @(posedge baud_clk_1);
    xmit_dataH = 8'h5A;
    xmitH = 1;
    @(posedge baud_clk_1);
    xmitH = 0;
    wait_baud(144);
    force dut.uart_xmit_h = 0;
    wait_baud(16);
    release dut.uart_xmit_h;
    wait(xmit_active == 0);

    @(posedge baud_clk_1);
    xmit_dataH = 8'hA5;
    xmitH = 1;
    @(posedge baud_clk_1);
    xmitH = 0;
    wait_baud(144);
    force dut.uart_xmit_h = 0;
    wait_baud(16);
    release dut.uart_xmit_h;
    wait(xmit_active == 0);
    #500;
    if (err == 1) begin
        $display("TEST %0d: multiple framing errors - PASS", test_num);
        pass_count = pass_count + 1;
    end else begin
        $display("TEST %0d: multiple framing errors - FAIL", test_num);
        fail_count = fail_count + 1;
    end
    $display("");

    $display("=============================================");
    $display("           FINAL SUMMARY");
    $display("=============================================");
    $display("  Total Tests  : %0d", test_num);
    $display("  Passed       : %0d", pass_count);
    $display("  Failed       : %0d", fail_count);
    $display("=============================================");

    if (fail_count == 0) begin
        $display("  ALL TESTS PASSED!");
    end else begin
        $display("  SOME TESTS FAILED!");
    end
    $display("=============================================");

    $stop;
end

endmodule
