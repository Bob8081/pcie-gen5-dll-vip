class pcie_dll_scoreboard extends uvm_scoreboard;
  
  pcie_dll_role_e role;

  `uvm_component_utils(pcie_dll_scoreboard)

  function new(string name = "pcie_dll_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
endclass : pcie_dll_scoreboard
