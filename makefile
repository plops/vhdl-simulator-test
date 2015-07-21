run_adder: adder.vhdl adder_tb.vhdl
	ghdl -a adder_tb.vhdl
	ghdl -e adder_tb
	ghdl -r adder_tb --vcd=adder.vcd

view_adder: adder.vcd
	gtkwave adder.vcd
