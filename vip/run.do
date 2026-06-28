# 1. Compile files directly in the correct order
vlog ../tb/pcie_lpif_if.sv ../rtl/mock_phy_crossbar.sv pcie_dll_pkg.sv ../tb/tb_top.sv

# 2. Run the simulation
vsim -voptargs=+acc work.tb_top

# 3. Simulation controls
set NoQuitOnFinish 1
onbreak {resume}
run -all

# 4. Exit