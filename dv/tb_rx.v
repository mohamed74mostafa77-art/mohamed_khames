`timescale 1ns/1ps
module tb_uart_rx;
    reg clk = 0;
    always #5 clk = ~clk; // 100MHz

    reg rst;
    reg [31:0] baud_div;
    reg rx_pin;
    wire [7:0] rx_data;
    wire rx_done;
    wire rx_busy;
    wire rx_error;

    uart_rx uut (
        .clk(clk),
        .rst(rst),
        .baud_div(baud_div),
        .rx_pin(rx_pin),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_busy(rx_busy),
        .rx_error(rx_error)
    );

    // helper task: send serial byte LSB-first with start/stop
    task send_byte;
        input [7:0] b;
        integer i;
        reg [31:0] bit_ticks;
        begin
            bit_ticks = baud_div;
            // start bit
            rx_pin = 0;
            repeat(bit_ticks) @(posedge clk);
            // data bits LSB first
            for (i=0;i<8;i=i+1) begin
                rx_pin = b[i];
                repeat(bit_ticks) @(posedge clk);
            end
            // stop bit
            rx_pin = 1;
            repeat(bit_ticks) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("tb_uart_rx.vcd");
        $dumpvars(0,tb_uart_rx);
        rst = 1; rx_pin = 1; baud_div = 32'd868;
        #20;
        rst = 0;
        #20;

        // send 0xA5
        send_byte(8'hA5);

        // wait for rx_done
        wait(rx_done);
        $display("RX got %02h at time %0t (err=%0b)", rx_data, $time, rx_error);

        #200;
        $finish;
    end
endmodule
