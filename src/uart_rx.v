`timescale 1ns/1ps
module uart_rx (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] baud_div,
    input  wire        rx_pin,       
    output reg [7:0]   rx_data,
    output reg         rx_done,      
    output reg         rx_busy,
    output reg         rx_error
);

    // states
    localparam R_IDLE   = 3'd0;
    localparam R_START  = 3'd1;
    localparam R_DATA   = 3'd2;
    localparam R_STOP   = 3'd3;
    localparam R_DONE   = 3'd4;

    reg [2:0] state, nxt_state;
    reg [31:0] baud_cnt;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;

    // synchronizer for rx_pin (2-flop)
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        if (rst) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_pin;
            rx_sync2 <= rx_sync1;
        end
    end
    wire rx_synced = rx_sync2;

    // sequential FSM
    always @(posedge clk) begin
        if (rst) begin
            state <= R_IDLE;
            baud_cnt <= 32'd0;
            bit_cnt <= 3'd0;
            shift_reg <= 8'd0;
            rx_data <= 8'd0;
            rx_done <= 1'b0;
            rx_busy <= 1'b0;
            rx_error <= 1'b0;
        end else begin
            state <= nxt_state;
            
            // Default outputs
            rx_done <= 1'b0;

            case (state)
                R_IDLE: begin
                    rx_busy <= 1'b0;
                    rx_error <= 1'b0;
                    if (rx_synced == 1'b0) begin // Start bit detected
                        baud_cnt <= (baud_div >> 1) - 1; // Sample at middle of start bit
                        rx_busy <= 1'b1;
                    end
                end

                R_START: begin
                    if (baud_cnt == 32'd0) begin
                        // Verify start bit is still low
                        if (rx_synced == 1'b0) begin
                            baud_cnt <= baud_div - 1; // Full bit period for data bits
                            bit_cnt <= 3'd0;
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                R_DATA: begin
                    if (baud_cnt == 32'd0) begin
                        // Shift in LSB first
                        shift_reg <= {rx_synced, shift_reg[7:1]};
                        bit_cnt <= bit_cnt + 1;
                        baud_cnt <= baud_div - 1;
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                R_STOP: begin
                    if (baud_cnt == 32'd0) begin
                        // Check stop bit
                        if (rx_synced == 1'b1) begin
                            rx_data <= shift_reg;
                            rx_error <= 1'b0;
                        end else begin
                            rx_data <= shift_reg;
                            rx_error <= 1'b1; // Framing error
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                R_DONE: begin
                    rx_done <= 1'b1;
                    rx_busy <= 1'b0;
                end
            endcase
        end
    end

    // next-state combinational logic
    always @(*) begin
        nxt_state = state;
        case (state)
            R_IDLE: begin
                if (rx_synced == 1'b0) // Start bit detected
                    nxt_state = R_START;
            end

            R_START: begin
                if (baud_cnt == 32'd0) begin
                    if (rx_synced == 1'b0) // Valid start bit
                        nxt_state = R_DATA;
                    else // False start
                        nxt_state = R_IDLE;
                end
            end

            R_DATA: begin
                if ((baud_cnt == 32'd0) && (bit_cnt == 3'd7))
                    nxt_state = R_STOP;
            end

            R_STOP: begin
                if (baud_cnt == 32'd0)
                    nxt_state = R_DONE;
            end

            R_DONE: begin
                nxt_state = R_IDLE;
            end

            default: nxt_state = R_IDLE;
        endcase
    end

endmodule
