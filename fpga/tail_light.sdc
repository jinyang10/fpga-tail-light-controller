# The board oscillator is 50 MHz.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty

# Buttons and switches are asynchronous human controls.
# KEY[1] enters a two-register synchronizer. KEY[0] resets asynchronously.
# Recovery/removal on reset release is excluded, not proven by these constraints.
set_false_path -from [get_ports {KEY[*] SW[*]}]

# LEDs and the seven-segment digit have no external capture clock.
set_false_path -to [get_ports {LEDR[*] HEX0[*]}]
