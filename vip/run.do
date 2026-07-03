# 1. Compile files directly in the correct order
vlog ../tb/pcie_lpif_if.sv ../rtl/mock_phy_crossbar.sv pcie_dll_pkg.sv ../tb/tb_top.sv

# 2. Run the simulation
vsim -coverage -voptargs="+acc" +UVM_TESTNAME=test_base_delayed_packets work.tb_top -do "run -all; coverage save test2.ucdb; quit -sim"

# 3. Simulation controls
set NoQuitOnFinish 1
onbreak {resume}
run -all

# 4. 
quit -f