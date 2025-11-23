module regs (
`ifdef USE_POWER_PINS
    inout wire  VDD,
    inout wire  VSS,
`endif
    input logic clk,
    input logic reset,
    input logic enable,

    input logic regwrite,

    input logic [3:0] rs1adr,
    input logic [3:0] rs2adr,
    input logic [3:0] rdadr,

    input logic [31:0] rd,
    output logic [31:0] rs1,
    output logic [31:0] rs2,
    output logic busy
);

  typedef enum {
    IDLE,
    PREP,
    RS1_0,
    RS1_1,
    RS1_2,
    RS1_3,
    RS2_0,
    RS2_1,
    RS2_2,
    RS2_3,
    READ_FINISH,
    RD_0,
    RD_1,
    RD_2,
    RD_3
  } states_t;

  states_t       state = IDLE;

  logic    [5:0] sram_addr;
  logic    [7:0] sram_in;
  logic    [7:0] sram_out;
  logic          sram_ce;
  gf180mcu_fd_ip_sram__sram64x8m8wm1 sram (
`ifdef USE_POWER_PINS
      .VDD(VDD),
      .VSS(VSS),
`endif
      .CLK (clk),
      .CEN (sram_ce),
      .GWEN(~regwrite),
      .WEN (8'b0),
      .A   (sram_addr),
      .D   (sram_in),
      .Q   (sram_out)
  );

  logic [31:0] rs1_reg;
  logic [31:0] rs2_reg;

  assign rs1 = (rs1adr == 0) ? 32'd0 : rs1_reg;
  assign rs2 = (rs2adr == 0) ? 32'd0 : rs2_reg;

  always_ff @(posedge clk) begin
    case (state)
      IDLE: begin
        if (enable) state <= PREP;
      end

      PREP: begin
        if (regwrite) state <= RD_0;
        else state <= RS1_0;
      end

      RS1_0: begin
        state <= RS1_1;
      end
      RS1_1: begin
        rs1_reg[7:0] <= sram_out;
        state <= RS1_2;
      end
      RS1_2: begin
        rs1_reg[15:8] <= sram_out;
        state <= RS1_3;
      end
      RS1_3: begin
        rs1_reg[23:16] <= sram_out;
        state <= RS2_0;
      end
      RS2_0: begin
        rs1_reg[31:24] <= sram_out;
        state <= RS2_1;
      end
      RS2_1: begin
        rs2_reg[7:0] <= sram_out;
        state <= RS2_2;
      end
      RS2_2: begin
        rs2_reg[15:8] <= sram_out;
        state <= RS2_3;
      end
      RS2_3: begin
        rs2_reg[23:16] <= sram_out;
        state <= READ_FINISH;
      end
      READ_FINISH: begin
        rs2_reg[31:24] <= sram_out;
        state <= IDLE;
      end

      RD_0: begin
        state <= RD_1;
      end
      RD_1: begin
        state <= RD_2;
      end
      RD_2: begin
        state <= RD_3;
      end
      RD_3: begin
        state <= IDLE;
      end
    endcase

    if (reset) begin
      state <= IDLE;
    end
  end

  always_comb begin
    sram_addr = 6'd0;
    sram_in = 8'd0;
    busy = 1;
    sram_ce = 0;

    case (state)
      IDLE: begin
        busy = 0;
        sram_ce = 1;
      end
      RS1_0: sram_addr = {rs1adr, 2'b00};
      RS1_1: sram_addr = {rs1adr, 2'b01};
      RS1_2: sram_addr = {rs1adr, 2'b10};
      RS1_3: sram_addr = {rs1adr, 2'b11};

      RS2_0: sram_addr = {rs2adr, 2'b00};
      RS2_1: sram_addr = {rs2adr, 2'b01};
      RS2_2: sram_addr = {rs2adr, 2'b10};
      RS2_3: sram_addr = {rs2adr, 2'b11};

      RD_0: begin
        sram_addr = {rdadr, 2'b00};
        sram_in   = rd[7:0];
      end
      RD_1: begin
        sram_addr = {rdadr, 2'b01};
        sram_in   = rd[15:8];
      end
      RD_2: begin
        sram_addr = {rdadr, 2'b10};
        sram_in   = rd[23:16];
      end
      RD_3: begin
        sram_addr = {rdadr, 2'b11};
        sram_in   = rd[31:24];
      end
    endcase
  end

  // // Internal register data structure
  // typedef logic [31:0] registers_t [16];
  // registers_t registers;

  // // Make sure x0 is always zero
  // initial registers[0] = 0;

  // always_ff @(posedge clk) begin
  //     if (reset) begin
  //         registers[0] <= 0;

  //         rs1 <= 0;
  //         rs2 <= 0;
  //     end else begin
  //         // Only perform write if control sets regwrite
  //         // and x0 isn't the target
  //         if (regwrite && rdadr != 0) begin
  //             registers[rdadr] <= rd;
  //         end

  //         // Perform read
  //         rs1 <= registers[rs1adr];
  //         rs2 <= registers[rs2adr];
  //     end
  // end
endmodule  // regs
