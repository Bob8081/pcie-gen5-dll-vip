# 1. Compile files directly in the correct order
vlog -cover bcst ../tb/pcie_lpif_if.sv ../rtl/mock_phy_crossbar.sv pcie_dll_pkg.sv ../tb/tb_top.sv

# 2. Run the simulation
vsim -coverage -voptargs="+acc" +UVM_TESTNAME=pcie_dll_test_dlcmsm_fc_init work.tb_top


# 3. Simulation controls
set NoQuitOnFinish 1
onbreak {resume}
run -all
coverage report -file coverage_report.txt -cvg -details -all

# 4. Exit
#quit -f