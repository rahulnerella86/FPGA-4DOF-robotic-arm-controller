# run_simulation.do
# ModelSim DO script for FPGA 4DOF Robotic Arm Controller

# Create work library
vlib work
vmap work work

# Compile source files
vcom -work work ../hdl/debouncer.vhd
vcom -work work ../hdl/pwm_generator.vhd
vcom -work work ../hdl/button_mapper.vhd
vcom -work work ../hdl/servo_controller.vhd
vcom -work work ../hdl/display_controller.vhd
vcom -work work ../hdl/top.vhd

# Compile testbenches
vcom -work work ../hdl/tb/pwm_generator_tb.vhd
vcom -work work ../hdl/tb/debouncer_tb.vhd
vcom -work work ../hdl/tb/servo_controller_tb.vhd
vcom -work work ../tests/button_test.vhd
vcom -work work ../tests/pwm_verification.vhd
vcom -work work ../tests/integration_test.vhd

# Simulation procedures
proc run_pwm_test {} {
    vsim work.pwm_generator_tb
    add wave -position insertpoint sim:/pwm_generator_tb/*
    run -all
}

proc run_debouncer_test {} {
    vsim work.debouncer_tb
    add wave -position insertpoint sim:/debouncer_tb/*
    run -all
}

proc run_servo_test {} {
    vsim work.servo_controller_tb
    add wave -position insertpoint sim:/servo_controller_tb/*
    run -all
}

proc run_integration_test {} {
    vsim work.integration_test
    add wave -position insertpoint sim:/integration_test/*
    run -all
}

echo "Available commands:"
echo "  run_pwm_test"
echo "  run_debouncer_test"
echo "  run_servo_test"
echo "  run_integration_test"
