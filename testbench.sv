// Code your testbench here
// or browse Examples
module tb;
  reg clk;
  reg rst;
  wire s1, s2, s3, s4, s5, s6, s7;
  wire [3:0] shown;
  wire halt;

  // port order: clk, rst, seg1..seg7, shown, halt
  computer dut(clk, rst, s1, s2, s3, s4, s5, s6, s7, shown, halt);

  // clock: flips every 5 time units
  initial clk = 0;
  always #5 clk = ~clk;

  // The program should print 0, 3, 6, 9, 12 (adds 3 each time).
  // 'expected' is the number we think comes next.
  reg [3:0] expected;
  integer count;     // how many numbers were displayed
  integer errors;    // how many wrong things we found

  initial begin
    expected = 0;
    count = 0;
    errors = 0;
  end

  // every time the CPU sends a number to the display, check it
  always @(posedge clk) begin
    if (dut.display_in) begin
      $display("CPU displayed: %0d (expected %0d)", dut.common_bus[3:0], expected);
      if (dut.common_bus[3:0] != expected) errors = errors + 1;
      expected = expected + 3;
      count = count + 1;
    end
  end

  // main test
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);
    rst = 1;
    #25 rst = 0;            // let go of reset after a few clocks
    wait (halt == 1);       // wait for the HLT instruction
    #20;

    if (count != 5) begin
      $display("FAIL: displayed %0d numbers, expected 5", count);
      errors = errors + 1;
    end
    if (dut.mar1.ram[13] != 8'd15) begin
      $display("FAIL: RAM[13] is %0d, expected 15", dut.mar1.ram[13]);
      errors = errors + 1;
    end

    if (errors == 0) $display("*** PASS ***");
    else $display("*** FAIL: %0d errors ***", errors);
    $finish;
  end

  // safety: stop if the CPU never halts
  initial begin
    #100000;
    $display("FAIL: timeout, CPU never halted");
    $finish;
  end
endmodule
