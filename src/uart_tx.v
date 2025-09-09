`timescale 1ns/1ps
module uart_tx (
    input  wire        clk,
    input  wire        rst,        // synchronous active-high
    input  wire [31:0] baud_div,
    input  wire        tx_start,   // 1-cycle pulse
    input  wire [7:0]  tx_data,
    output reg         tx,
    output reg         tx_busy,
    output reg         tx_done
);

    // states
    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA  = 3'd2;
    localparam S_STOP  = 3'd3;
    localparam S_DONE  = 3'd4;

    reg [2:0] state, nxt_state;
    reg [31:0] baud_cnt;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;

    // sequential
    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            baud_cnt <= 32'd0;
            bit_cnt <= 3'd0;
            shift_reg <= 8'd0;
            tx <= 1'b1;
            tx_busy <= 1'b0;
            tx_done <= 1'b0;
        end else begin
            state <= nxt_state;

            // default tx_done low; pulse one cycle when entering DONE
            if (state == S_DONE)
                tx_done <= 1'b1;
            else
                tx_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        // load counter for one bit: use baud_div-1 so it counts down to 0 inclusive
                        baud_cnt <= (baud_div == 0) ? 32'd1 : baud_div - 1;
                        bit_cnt <= 3'd0;
                        tx_busy <= 1'b1;
                    end
                end

                S_START: begin
                    tx <= 1'b0; // start bit
                    tx_busy <= 1'b1;
                    if (baud_cnt == 0) begin
                        // finished start bit; reload for data bit
                        baud_cnt <= (baud_div == 0) ? 32'd1 : baud_div - 1;
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                S_DATA: begin
                    tx <= shift_reg[0];
                    tx_busy <= 1'b1;
                    if (baud_cnt == 0) begin
                        // shift after bit time
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        bit_cnt <= bit_cnt + 1;
                        baud_cnt <= (baud_div == 0) ? 32'd1 : baud_div - 1;
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1; // stop bit
                    tx_busy <= 1'b1;
                    if (baud_cnt == 0) begin
                        // finished
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                S_DONE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                end

                default: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                end
            endcase
        end
    end

    // combinational next-state
    always @(*) begin
        nxt_state = state;
        case (state)
            S_IDLE: if (tx_start) nxt_state = S_START;
            S_START: if (baud_cnt == 32'd0) nxt_state = S_DATA;
            S_DATA: if ((baud_cnt == 32'd0) && (bit_cnt == 3'd7)) nxt_state = S_STOP;
            S_STOP: if (baud_cnt == 32'd0) nxt_state = S_DONE;
            S_DONE: nxt_state = S_IDLE;
        endcase
    end

endmodule
