# Design notes

## Timing and control

Everything runs from `CLOCK_50`; there are no fabric-generated clocks. `tick` measures the current delay and `step` selects a 10-bit LED pattern. A step ends at `duration - 1`, so it occupies exactly the configured number of rising edges.

The default parameters are `TWO_SEC = 100_000_000`, `ONE_SEC = 50_000_000`, and `SHORT_STEP = 5_000_000`. All must be positive integers that fit the 32-bit timer. Simulation overrides them with 7, 5, and 3 ticks to exercise complete runs quickly without forcing internal state.

Steps 11 and 31, numbered from zero, hold for one second. All other steps last 0.1 seconds. At step 43's final tick, the repeat counter decrements once. If the old count was one, the FSM returns to idle; otherwise the next sequence begins immediately.

## Start input

`KEY1` is active-low. Two registers sample the input, and a third stores the previous synchronized value for falling-edge detection. Starts are accepted only in `IDLE`. A held button does not keep restarting completed runs. A new press after returning to idle starts a new run.

The selector increments from 1 through 10 while reset is released. Press timing determines the sampled count. There is no claim of statistical randomness or a uniform distribution of real button presses.

## Reset and countdown

`KEY0` asynchronously resets the FSM, timer, step index, and start synchronizer. The repeat counter lives in a separate clocked block, initializes to zero on the FPGA, and holds its value while reset is asserted. The next accepted start replaces that value with a fresh selection.

Press and release reset after configuration before starting a run. Reset release is not synchronized. A production version should add synchronized release and reassess the retained-counter behavior around reset boundaries.

## Outputs

The LED lookup lists all 44 patterns explicitly. This makes the lab sequence easy to inspect and compare against the testbench. `LEDR[9]` is the leftmost LED. `SW9` clears bits 9 through 5; `SW0` clears bits 4 through 0. Masking changes visibility without pausing playback.

`HEX0` uses active-low segments, with the decimal point off. Ten is displayed as hexadecimal A. The decoder is a function driven by a continuous assignment, which also evaluates at simulation startup.

## Tradeoffs and next steps

- Button synchronization reduces metastability propagation but does not debounce contacts.
- Asynchronous switch masks can glitch during a transition; sampling them would make transitions clock-aligned.
- The 32-bit timer is simple and readable. A parameter-derived width could reduce register usage.
- The current pin file retains the supplied engineering-sample device. Check the physical FPGA marking before programming another board.
- Add a physical-board video and repeat the reset/button tests on hardware before claiming hardware validation of this revision.
