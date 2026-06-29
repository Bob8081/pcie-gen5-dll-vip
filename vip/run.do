# 1. Compile
vlog -cover bcst ../tb/pcie_lpif_if.sv ../rtl/mock_phy_crossbar.sv pcie_dll_pkg.sv ../tb/tb_top.sv

set NoQuitOnFinish 1
onbreak {resume}

# 2. Run tests
vsim -coverage -voptargs="+acc" +UVM_TESTNAME=test_base_without_feature   work.tb_top -do "run -all; coverage save test1.ucdb; quit -sim"
vsim -coverage -voptargs="+acc" +UVM_TESTNAME=test_base_with_feature      work.tb_top -do "run -all; coverage save test2.ucdb; quit -sim"
vsim -coverage -voptargs="+acc" +UVM_TESTNAME=test_base_zero_credits      work.tb_top -do "run -all; coverage save test3.ucdb; quit -sim"
vsim -coverage -voptargs="+acc" +UVM_TESTNAME=test_base_corrupted_initfc  work.tb_top -do "run -all; coverage save test4.ucdb; quit -sim"
vsim -coverage -voptargs="+acc" +UVM_TESTNAME=test_base_error_injected    work.tb_top -do "run -all; coverage save test5.ucdb; quit -sim"
vsim -coverage -voptargs="+acc" +UVM_TESTNAME=test_base_delayed_packets   work.tb_top -do "run -all; coverage save test6.ucdb; quit -sim"

# 3. Merge
vcover merge merged_coverage.ucdb test1.ucdb test2.ucdb test3.ucdb test4.ucdb test5.ucdb test6.ucdb

# 4. Report
vcover report -file coverage_report.txt -cvg -details -all merged_coverage.ucdb

quit -f