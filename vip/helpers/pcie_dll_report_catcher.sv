class pcie_dll_report_catcher extends uvm_report_catcher;

  `uvm_object_utils(pcie_dll_report_catcher)

  // All expected errors are matched by tag substring against get_message()
  string expected_msg_tags[$];

  // Per-tag hit counters  (tag -> count)
  int unsigned tag_counts[string];

  // Total errors demoted  // Statistics
  int unsigned caught_count;
  string unexpected_errors[$];

  function new(string name = "pcie_dll_report_catcher");
    super.new(name);
    caught_count = 0;
  endfunction

  // Register a message tag that is expected to fire as UVM_ERROR.
  // The tag must appear as a substring of the full message string.
  function void add_expected_tag(string tag);
    expected_msg_tags.push_back(tag);
    tag_counts[tag] = 0;
    `uvm_info("CATCHER",
      $sformatf("Registered expected error tag: \"%s\"", tag),
      UVM_MEDIUM)
  endfunction

  // Clear all expectations (useful between test iterations)
  function void clear();
    expected_msg_tags.delete();
    tag_counts.delete();
    unexpected_errors.delete();
    caught_count = 0;
  endfunction

  // Print a simple summary list at the end of the test.
  function void report();
    string sep = "--------------------------------------------------";
    `uvm_info("CATCHER", sep, UVM_NONE)
    `uvm_info("CATCHER", "   EXPECTED ERROR DEMOTION SUMMARY", UVM_NONE)
    `uvm_info("CATCHER", sep, UVM_NONE)
    foreach (expected_msg_tags[i]) begin
      string tag = expected_msg_tags[i];
      int hits = tag_counts.exists(tag) ? tag_counts[tag] : 0;
      `uvm_info("CATCHER", $sformatf("  %-25s : %0d", tag, hits), UVM_NONE)
    end
    `uvm_info("CATCHER", sep, UVM_NONE)
    `uvm_info("CATCHER", $sformatf("  Total demoted errors: %0d", caught_count), UVM_NONE)

    if (unexpected_errors.size() > 0) begin
      `uvm_info("CATCHER", sep, UVM_NONE)
      `uvm_info("CATCHER", $sformatf("  UNEXPECTED ERRORS: %0d", unexpected_errors.size()), UVM_NONE)
      `uvm_info("CATCHER", sep, UVM_NONE)
      foreach (unexpected_errors[i]) begin
        `uvm_info("CATCHER", $sformatf("  * %s", unexpected_errors[i]), UVM_NONE)
      end
    end

    `uvm_info("CATCHER", sep, UVM_NONE)
  endfunction

  // UVM catch override
  virtual function action_e catch();
    string tag;
    string msg;

    // Only act on UVM_ERROR (never touch FATAL)
    if (get_severity() != UVM_ERROR)
      return THROW;

    msg = get_message();

    // Check all registered tags as substrings of the message
    foreach (expected_msg_tags[i]) begin
      if (uvm_is_match({"*", expected_msg_tags[i], "*"}, msg)) begin
        tag = expected_msg_tags[i];
        caught_count++;
        tag_counts[tag]++;
        `uvm_info("CATCHER",
          $sformatf("[EXPECTED ERROR DEMOTED] tag=\"%s\" ID=\"%s\"",
            tag, get_id()),
          UVM_HIGH)
        set_severity(UVM_INFO);
        set_action(UVM_DISPLAY);
        return CAUGHT;
      end
    end

    // Not an expected error -> record and let it propagate
    unexpected_errors.push_back($sformatf("[%s] %s", get_id(), msg));
    return THROW;

  endfunction

endclass : pcie_dll_report_catcher
