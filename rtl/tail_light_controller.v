`timescale 1ns/1ps

// DE10-Lite LED sequencer. KEY inputs are active-low.
module tail_light_controller #(
    parameter integer TWO_SEC = 100_000_000,
    parameter integer ONE_SEC = 50_000_000,
    parameter integer SHORT_STEP = 5_000_000
) ( 
    input wire CLOCK_50, 
    input wire [9:0] SW,
    input wire [1:0] KEY,
    output reg [9:0] LEDR,
    output wire [7:0] HEX0
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] WAITING = 2'd1;
    localparam [1:0] PLAYING = 2'd2;

    reg [1:0] state;
    reg [31:0] tick;
    reg [5:0] step;
    reg [3:0] random_count;
    // FPGA power-up value; reset intentionally preserves the remaining count.
    reg [3:0] repeat_count = 4'd0;
    // Two sampling stages reduce metastability risk; this is not a debouncer.
    reg key1_meta;
    reg key1_sync;
    reg key1_prev;

    // Steps 11 and 31 hold the end LEDs for one second.
    wire step_done = (tick == (((step == 6'd11) || (step == 6'd31)) ? ONE_SEC : SHORT_STEP) - 1);

    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            key1_meta <= 1'b1;
            key1_sync <= 1'b1;
            key1_prev <= 1'b1;
            random_count <= 4'd1;
        end else begin
            key1_meta <= KEY[1];
            key1_sync <= key1_meta;
            key1_prev <= key1_sync;
            if (random_count == 4'd10) begin
                random_count <= 4'd1;
            end else begin
                random_count <= random_count + 1'b1;
            end
        end
    end

    // Separate from the resettable FSM so KEY[0] holds the count.
    always @(posedge CLOCK_50) begin
        if (KEY[0]) begin
            if ((state == IDLE) && key1_prev && !key1_sync) begin
                repeat_count <= random_count;
            end else if ((state == PLAYING) && (step == 6'd43) && step_done) begin
                repeat_count <= repeat_count - 1'b1;
            end
        end
    end

    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            state <= IDLE;
            tick <= 32'd0;
            step <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    tick <= 32'd0;
                    step <= 6'd0;
                    if (key1_prev && !key1_sync) begin
                        state <= WAITING;
                    end
                end
                WAITING: begin
                    if (tick == TWO_SEC - 1) begin
                        tick <= 32'd0;
                        state <= PLAYING;
                    end else begin
                        tick <= tick + 1'b1;
                    end
                end
                PLAYING: begin
                    if (step_done) begin
                        tick <= 32'd0;
                        if (step == 6'd43) begin
                            step <= 6'd0;
                            if (repeat_count == 4'd1) begin
                                state <= IDLE;
                            end
                        end else begin
                            step <= step + 1'b1;
                        end
                    end else begin
                        tick <= tick + 1'b1;
                    end
                end
                default: begin
                    state <= IDLE;
                    tick <= 32'd0;
                    step <= 6'd0;
                end
            endcase
        end
    end

    // Bit 9 is the leftmost LED; switches mask the two five-LED banks.
    always @(*) begin
        LEDR = 10'b0000000000;
        if (KEY[0] && (state == PLAYING)) begin
            case (step)
                6'd0: LEDR = 10'b0000110000;
                6'd1: LEDR = 10'b0001111000;
                6'd2: LEDR = 10'b0011111100;
                6'd3: LEDR = 10'b0111111110;
                6'd4: LEDR = 10'b1111111111;
                6'd5: LEDR = 10'b0000000000;
                6'd6: LEDR = 10'b0000110000;
                6'd7: LEDR = 10'b0001111000;
                6'd8: LEDR = 10'b0011111100;
                6'd9: LEDR = 10'b0111111110;
                6'd10: LEDR = 10'b1111111111;
                6'd11: LEDR = 10'b1000000001;
                6'd12: LEDR = 10'b1100000001;
                6'd13: LEDR = 10'b1110000001;
                6'd14: LEDR = 10'b1011000001;
                6'd15: LEDR = 10'b1001100001;
                6'd16: LEDR = 10'b1000110001;
                6'd17: LEDR = 10'b1000011001;
                6'd18: LEDR = 10'b1000001101;
                6'd19: LEDR = 10'b1000000111;
                6'd20: LEDR = 10'b1000000011;
                6'd21: LEDR = 10'b1000000001;
                6'd22: LEDR = 10'b1000000011;
                6'd23: LEDR = 10'b1000000111;
                6'd24: LEDR = 10'b1000001101;
                6'd25: LEDR = 10'b1000011001;
                6'd26: LEDR = 10'b1000110001;
                6'd27: LEDR = 10'b1001100001;
                6'd28: LEDR = 10'b1011000001;
                6'd29: LEDR = 10'b1110000001;
                6'd30: LEDR = 10'b1100000001;
                6'd31: LEDR = 10'b1000000001;
                6'd32: LEDR = 10'b1100000011;
                6'd33: LEDR = 10'b1110000111;
                6'd34: LEDR = 10'b1111001111;
                6'd35: LEDR = 10'b1111111111;
                6'd36: LEDR = 10'b0000110000;
                6'd37: LEDR = 10'b0001111000;
                6'd38: LEDR = 10'b0011001100;
                6'd39: LEDR = 10'b0110000110;
                6'd40: LEDR = 10'b1100000011;
                6'd41: LEDR = 10'b1000000001;
                6'd42: LEDR = 10'b0000000000;
                6'd43: LEDR = 10'b0000000000;
                default: LEDR = 10'b0000000000;
            endcase
            if (SW[9]) LEDR[9:5] = 5'b00000;
            if (SW[0]) LEDR[4:0] = 5'b00000;
        end
    end

    function [7:0] decode_count;
        input [3:0] count;
        begin
            case (count)
                4'd0: decode_count = 8'hc0;
                4'd1: decode_count = 8'hf9;
                4'd2: decode_count = 8'ha4;
                4'd3: decode_count = 8'hb0;
                4'd4: decode_count = 8'h99;
                4'd5: decode_count = 8'h92;
                4'd6: decode_count = 8'h82;
                4'd7: decode_count = 8'hf8;
                4'd8: decode_count = 8'h80;
                4'd9: decode_count = 8'h90;
                // A represents ten on the single hexadecimal digit.
                4'd10: decode_count = 8'h88;
                default: decode_count = 8'hff;
            endcase
        end
    endfunction

    assign HEX0 = decode_count(repeat_count);

endmodule
