`timescale 1ns/1ps
module tb_uart_tx;
    reg clk;
    reg rst;
    reg [31:0] baud_div;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx;
    wire tx_busy;
    wire tx_done;

    // Clock 100MHz = 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT
    uart_tx uut (
        .clk(clk),
        .rst(rst),
        .baud_div(baud_div),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    initial begin
        $dumpfile("tb_uart_tx.vcd");
        $dumpvars(0, tb_uart_tx);

        // init
        rst = 1;
        baud_div = 32'd4;   
        tx_start = 0;
        tx_data  = 8'h00;

        // reset pulse
        #20 rst = 0;
        #20;

        // send 0x55
        tx_data = 8'h55;
        @(posedge clk);
        tx_start = 1;       // pulse
        @(posedge clk);
        tx_start = 0;

        wait (tx_done);
        $display("Finished sending 0x55 at time %0t", $time);

        // delay then send 0xA3
        #50;
        tx_data = 8'hA3;
        @(posedge clk);
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        wait (tx_done);
        $display("Finished sending 0xA3 at time %0t", $time);

        #200;
        $finish;
    end
endmodule
