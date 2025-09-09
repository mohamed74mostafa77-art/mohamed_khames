`timescale 1ns/1ps
module tb_apb_uart;
    reg pclk = 0;
    always #5 pclk = ~pclk; // 100MHz

    reg presetn;

    reg [31:0] paddr;
    reg psel;
    reg penable;
    reg pwrite;
    reg [31:0] pwdata;
    wire [31:0] prdata;
    wire pready;

    // regs for status and rx
    reg [31:0] s;
    reg [31:0] rxd;

    // wires to UART modules
    wire [31:0] baud_div;
    wire tx_start;
    wire [7:0] tx_data;
    wire tx_busy;
    wire tx_done;
    wire [7:0] rx_data;
    wire rx_done;
    wire rx_busy;
    wire rx_error;

    // instantiate apb_uart
    apb_uart uut_apb (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .baud_div(baud_div),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .rx_reset(),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_busy(rx_busy),
        .rx_error(rx_error)
    );

    // loopback
    wire tx_line;
    uart_tx UTX (
        .clk(pclk),
        .rst(~presetn),
        .baud_div(baud_div),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx_line),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    uart_rx URX (
        .clk(pclk),
        .rst(~presetn),
        .baud_div(baud_div),
        .rx_pin(tx_line),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_busy(rx_busy),
        .rx_error(rx_error)
    );

    // APB tasks
    task apb_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge pclk);
            paddr   <= addr;
            pwdata  <= data;
            pwrite  <= 1;
            psel    <= 1;
            penable <= 1;
            @(posedge pclk);
            while (!pready) @(posedge pclk);
            psel    <= 0;
            penable <= 0;
            pwrite  <= 0;
            @(posedge pclk);
        end
    endtask

    task apb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge pclk);
            paddr   <= addr;
            pwrite  <= 0;
            psel    <= 1;
            penable <= 1;
            @(posedge pclk);
            while (!pready) @(posedge pclk);
            data = prdata;
            psel    <= 0;
            penable <= 0;
            @(posedge pclk);
        end
    endtask

    initial begin
        $dumpfile("tb_apb_uart.vcd");
        $dumpvars(0,tb_apb_uart);
        presetn = 0;
        psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
        #40;
        presetn = 1;
        #40;

        // write TX_DATA = 0x5A
        apb_write(32'h0002, 32'h0000005A);

        // pulse CTRL.tx_en = bit0
        apb_write(32'h0000, 32'h1);

        // poll STATUS until tx_done
        repeat (2000) begin
            apb_read(32'h0001, s);
            if (s[3]) begin
                $display("APB saw tx_done at time %0t", $time);
                disable poll_loop;
            end
            #100;
        end
        poll_loop ;

        // read RX_DATA
        apb_read(32'h0003, rxd);
        $display("APB read RX_DATA = %02h", rxd[7:0]);

        #200;
        $finish;
    end
endmodule
