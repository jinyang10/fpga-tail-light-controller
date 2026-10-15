`timescale 1ns/1ps

module tail_light_tb;
    localparam integer START_TICKS = 7;
    localparam integer LONG_TICKS = 5;
    localparam integer SHORT_TICKS = 3;
    reg clock = 0;
    reg [1:0] key = 2'b11;
    reg [9:0] sw = 0;
    wire [9:0] leds;
    wire [7:0] hex0;
    reg [9:0] pattern [0:43];
    reg [9:0] counts_seen = 0;
    integer checks = 0;
    integer completed_frames = 0;
    integer n;

    tail_light_controller #(
        .TWO_SEC(START_TICKS), .ONE_SEC(LONG_TICKS), .SHORT_STEP(SHORT_TICKS)
    ) dut (.CLOCK_50(clock), .SW(sw), .KEY(key), .LEDR(leds), .HEX0(hex0));

    always #10 clock = ~clock;

    task automatic check(input bit condition, input string message);
        checks = checks + 1;
        if (!condition) $fatal(1, "%s at %0t", message, $time);
    endtask

    task automatic cycle;
        @(posedge clock); #1;
    endtask

    function automatic [7:0] digit(input integer count);
        case (count)
            0: digit = 8'hc0; 1: digit = 8'hf9; 2: digit = 8'ha4;
            3: digit = 8'hb0; 4: digit = 8'h99; 5: digit = 8'h92;
            6: digit = 8'h82; 7: digit = 8'hf8; 8: digit = 8'h80;
            9: digit = 8'h90; 10: digit = 8'h88;
            default: digit = 8'hff;
        endcase
    endfunction

    task automatic reset_and_check(input integer expected_count);
        @(negedge clock); #2; key[0] = 0; #1;
        check(leds === 0 && dut.state === 0, "Asynchronous reset stops playback");
        check(hex0 === digit(expected_count), "Reset preserves countdown");
        repeat (3) cycle();
        check(dut.repeat_count === expected_count, "Count holds throughout reset");
        key[1] = 1;
        @(negedge clock); key[0] = 1;
        repeat (4) cycle();
    endtask

    task automatic start_run(input integer desired);
        integer sample_before_press;
        // The selector advances twice before the synchronized edge is accepted.
        sample_before_press = ((desired + 7) % 10) + 1;
        @(negedge clock);
        while (dut.random_count != sample_before_press) @(negedge clock);
        key[1] = 0;
        cycle(); check(dut.state === 0, "First sampling stage does not start FSM");
        cycle(); check(dut.state === 0, "Second sampling stage precedes edge detection");
        cycle();
        check(dut.state === 1 && dut.tick === 0, "One start edge enters WAITING");
        check(dut.repeat_count === desired, "Press timing samples expected count");
        check(hex0 === digit(desired), "Selected count reaches seven-segment output");
        counts_seen[desired - 1] = 1;
    endtask

    task automatic wait_for_playback;
        integer i;
        for (i = 1; i < START_TICKS; i = i + 1) begin
            cycle();
            check(dut.state === 1 && dut.tick === i, "Startup delay has exact length");
            check(leds === 0, "LEDs stay dark during startup delay");
        end
        cycle();
        check(dut.state === 2 && dut.step === 0 && dut.tick === 0, "Playback begins at step zero");
    endtask

    task automatic verify_run(input integer selected, input bit busy_presses);
        integer remaining, s, elapsed, duration;
        reg [9:0] expected;
        for (remaining = selected; remaining > 0; remaining = remaining - 1) begin
            for (s = 0; s < 44; s = s + 1) begin
                duration = (s == 11 || s == 31) ? LONG_TICKS : SHORT_TICKS;
                for (elapsed = 0; elapsed < duration; elapsed = elapsed + 1) begin
                    check(dut.state === 2 && dut.step === s && dut.tick === elapsed,
                          "State, step, and tick match scoreboard");
                    check(dut.repeat_count === remaining && hex0 === digit(remaining),
                          "Countdown changes only after a complete frame");
                    expected = pattern[s];
                    sw = 0; #1;
                    check(leds === expected, "Unmasked pattern matches golden sequence");
                    sw[9] = 1; #1;
                    check(leds === (expected & 10'b0000011111), "Left-bank mask");
                    sw[9] = 0; sw[0] = 1; #1;
                    check(leds === (expected & 10'b1111100000), "Right-bank mask");
                    sw[9] = 1; #1;
                    check(leds === 0, "Both banks masked");
                    sw = 10'b0111111110; #1;
                    check(leds === expected, "Unused switches do not affect playback");
                    if (busy_presses) key[1] = (s % 2 == 0);
                    cycle();
                end
            end
            completed_frames = completed_frames + 1;
            check(dut.repeat_count === remaining - 1, "Frame completion decrements once");
        end
        check(dut.state === 0 && leds === 0 && hex0 === digit(0), "Last frame returns to idle");
    endtask

    initial begin
        $dumpfile("tail_light.vcd");
        $dumpvars(0, tail_light_tb);
        pattern[0]=10'b0000110000; pattern[1]=10'b0001111000;
        pattern[2]=10'b0011111100; pattern[3]=10'b0111111110;
        pattern[4]=10'b1111111111; pattern[5]=10'b0000000000;
        pattern[6]=10'b0000110000; pattern[7]=10'b0001111000;
        pattern[8]=10'b0011111100; pattern[9]=10'b0111111110;
        pattern[10]=10'b1111111111; pattern[11]=10'b1000000001;
        pattern[12]=10'b1100000001; pattern[13]=10'b1110000001;
        pattern[14]=10'b1011000001; pattern[15]=10'b1001100001;
        pattern[16]=10'b1000110001; pattern[17]=10'b1000011001;
        pattern[18]=10'b1000001101; pattern[19]=10'b1000000111;
        pattern[20]=10'b1000000011; pattern[21]=10'b1000000001;
        pattern[22]=10'b1000000011; pattern[23]=10'b1000000111;
        pattern[24]=10'b1000001101; pattern[25]=10'b1000011001;
        pattern[26]=10'b1000110001; pattern[27]=10'b1001100001;
        pattern[28]=10'b1011000001; pattern[29]=10'b1110000001;
        pattern[30]=10'b1100000001; pattern[31]=10'b1000000001;
        pattern[32]=10'b1100000011; pattern[33]=10'b1110000111;
        pattern[34]=10'b1111001111; pattern[35]=10'b1111111111;
        pattern[36]=10'b0000110000; pattern[37]=10'b0001111000;
        pattern[38]=10'b0011001100; pattern[39]=10'b0110000110;
        pattern[40]=10'b1100000011; pattern[41]=10'b1000000001;
        pattern[42]=10'b0000000000; pattern[43]=10'b0000000000;

        #1; check(hex0 === digit(0), "FPGA initialization sets countdown to zero");
        reset_and_check(0);
        for (n = 1; n <= 10; n = n + 1) begin
            start_run(n);
            if (n != 1) key[1] = 1;
            wait_for_playback();
            verify_run(n, n != 1);
            if (n == 1) begin
                repeat (8) cycle();
                check(dut.state === 0, "Held start does not retrigger after completion");
            end
            key[1] = 1;
            repeat (5) cycle();
        end
        check(counts_seen === 10'b1111111111, "Every repeat selection from 1 to 10 is covered");
        check(completed_frames == 55, "All 55 expected frames completed");

        start_run(4);
        reset_and_check(4);
        check(dut.state === 0, "Reset cancels startup delay");
        start_run(3);
        key[1] = 1;
        wait_for_playback();
        repeat (17) cycle();
        reset_and_check(3);
        check(dut.tick === 0 && dut.step === 0, "Reset cancels playback and clears timing");
        start_run(2);
        key[1] = 1;
        wait_for_playback();
        verify_run(2, 0);
        $display("PASS: %0d checks, %0d complete frames, all 10 repeat counts", checks, completed_frames);
        $finish;
    end

    initial begin
        #1_000_000;
        $fatal(1, "Watchdog: test did not complete");
    end
endmodule
