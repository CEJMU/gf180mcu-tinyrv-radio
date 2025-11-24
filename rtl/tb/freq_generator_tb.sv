`timescale 1ns / 1ps

module freq_generator_tb ();

  logic        clk = 0;
  logic        reset_n = 0;
  logic [29:0] f_c = 30'b000000001011101001011110001101;
  logic [ 1:0] osr_level = 2'b11;
  logic [ 2:0] lo_div_sel = 3'd4;
  logic        start = 0;

  localparam real F_CLK = 56_000_000;
  realtime PERIOD_NS = (1 / F_CLK) * 1_000_000_000;
  realtime HALFPERIOD_NS = PERIOD_NS / 2;

  freq_generator dut (
      .clk(clk),
      .reset_n(reset_n),
      .start(start),
      .f_c(f_c),
      .osr_level(osr_level),
      .lo_div_sel(lo_div_sel)
  );

  always begin
    clk <= ~clk;
    #HALFPERIOD_NS;
  end

  int i;
  initial begin
    $dumpfile("freq_generator.vcd");
    $dumpvars(0, dut);
    reset_n = 0;
    start   = 0;

    #PERIOD_NS;
    #PERIOD_NS;
    #PERIOD_NS;

    reset_n = 1;
    #PERIOD_NS;
    #PERIOD_NS;

    start = 1;

    for (i = 0; i < 1_000_000; i++) begin
      #PERIOD_NS;
    end

    $finish;
  end

endmodule
