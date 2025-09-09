// apb_uart.v
// APB3-like simple slave wrapper for UART
// Addresses (word addressed):
//  0x0000 -> CTRL_REG [bit0: tx_en, bit1: rx_en, bit2: tx_rst, bit3: rx_rst]
//  0x0001 -> STATUS_REG [bit0: rx_busy, bit1: tx_busy, bit2: rx_done, bit3: tx_done, bit4: rx_error]
//  0x0002 -> TX_DATA (write 8-bit in [7:0])
//  0x0003 -> RX_DATA (read 8-bit in [7:0])
//  0x0004 -> BAUDDIV (32-bit)

`timescale 1ns/1ps
module apb_uart (
    input  wire        pclk,
    input  wire        presetn,   // active-low reset (APB style)
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output reg         pready,
    // to UART modules
    output wire [31:0] baud_div,
    output reg         tx_start,    // single-cycle pulse
    output reg  [7:0]  tx_data,
    input  wire        tx_busy,
    input  wire        tx_done,
    output reg         rx_reset,    // optional resets to rx/t x
    input  wire [7:0]  rx_data,
    input  wire        rx_done,
    input  wire        rx_busy,
    input  wire        rx_error
);

    // internal reset active-high for our logic
    wire rst = ~presetn;

    // registers
    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg [31:0] tx_data_reg;
    reg [31:0] rx_data_reg;
    reg [31:0] bauddiv_reg;

    // address mapping (word-aligned addresses)
    localparam ADDR_CTRL  = 32'h0000;
    localparam ADDR_STATUS= 32'h0001;
    localparam ADDR_TX    = 32'h0002;
    localparam ADDR_RX    = 32'h0003;
    localparam ADDR_BAUD  = 32'h0004;

    
    always @(posedge pclk) begin
        if (rst) begin
            pready <= 1'b0;
            prdata <= 32'd0;
            ctrl_reg <= 32'd0;
            status_reg <= 32'd0;
            tx_data_reg <= 32'd0;
            rx_data_reg <= 32'd0;
            bauddiv_reg <= 32'd868; // default 115200 @100MHz approx
            tx_start <= 1'b0;
            tx_data <= 8'd0;
            rx_reset <= 1'b0;
        end else begin
            // default outputs
            pready <= 1'b0;
            tx_start <= 1'b0;
            rx_reset <= 1'b0;

            // update status_reg from UART live signals (bits placed accordingly)
            status_reg[0] <= rx_busy;
            status_reg[1] <= tx_busy;
            status_reg[2] <= rx_done;
            status_reg[3] <= tx_done;
            status_reg[4] <= rx_error;

            if (psel & penable) begin
                pready <= 1'b1; // we complete transaction in this cycle
                if (pwrite) begin
                    // write transaction
                    case (paddr)
                        ADDR_CTRL: begin
                            ctrl_reg <= pwdata;
                            // if tx_en bit set => generate tx_start pulse & load tx_data_reg to tx_data
                            if (pwdata[0]) begin
                                tx_data <= tx_data_reg[7:0]; // assume previously written
                                tx_start <= 1'b1;
                            end
                            // rx_rst or tx_rst handling (bits 2 & 3)
                            if (pwdata[2]) begin
                                
                            end
                            if (pwdata[3]) begin
                                rx_reset <= 1'b1; // pulse reset to RX if desired
                            end
                        end

                        ADDR_TX: begin
                            tx_data_reg <= pwdata;
                         
                        end

                        ADDR_BAUD: begin
                            bauddiv_reg <= pwdata;
                        end

                        default: begin
                            // ignore
                        end
                    endcase
                end else begin
                    // read transaction
                    case (paddr)
                        ADDR_CTRL: prdata <= ctrl_reg;
                        ADDR_STATUS: prdata <= status_reg;
                        ADDR_TX: prdata <= tx_data_reg;
                        ADDR_RX: prdata <= {24'd0, rx_data}; // low byte = rx_data
                        ADDR_BAUD: prdata <= bauddiv_reg;
                        default: prdata <= 32'hDEAD_BEEF;
                    endcase
                end
            end
        end
    end

    assign baud_div = bauddiv_reg;

endmodule
