
`define pcie_do_callbacks_one_hot(T, CB, METHOD) \
  begin \
    uvm_callback_iter#(T, CB) iter = new(this); \
    CB cb = iter.first(); \
    while (cb != null) begin \
      if (cb.METHOD) break; // to make at most one callback run in one iteration \
      //cb.METHOD; // to make the code run exactly as 'uvm_do_callbacks \
      cb = iter.next(); \
    end \
  end