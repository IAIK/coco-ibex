create_clock -period 10.00 [get_ports clk_sys]
set_property DONT_TOUCH true [get_cells u_core]
set_property DONT_TOUCH true [get_cells u_ram]
set_property DONT_TOUCH true [get_cells instr_rom]
