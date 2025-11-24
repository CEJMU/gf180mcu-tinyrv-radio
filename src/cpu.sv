module cpu (
`ifdef USE_POWER_PINS
    inout wire  VDD,
    inout wire  VSS,
`endif
    input logic clk,
    input logic reset,    // active low due to pico-ice button
    input logic intr_ext,

    input  logic so,
    output logic si,
    output logic sclk,
    output logic sram_ce,

    // output logic scl,
    // inout  logic sda,

    output logic tx,

    input  logic [3:0] gpio_in,
    output logic [3:0] gpio_out,

    output logic cos_ds,
    output logic cos_ds_n,
    output logic sin_ds,
    output logic sin_ds_n,
    output logic lo_i,
    output logic lo_q,
    output logic lo_ix,
    output logic lo_qx
);

`ifndef SIM
  `include "constants.sv"
`endif

  logic mem_ce, memwrite, mem_busy, mem_valid;
  logic [31:0] mem_addr;
  logic [31:0] mem_datain, mem_dataout;

  logic [31:0] iword, immediate;
  logic wbflag, memflag, pcflag, fetchflag;

  logic [5:0] control_flags;

  logic [1:0] jump;
  logic [15:0] imm, pc_new;

  logic [31:0] a, b, rd;
  logic [16:0] instruction;

  logic        regwrite;
  logic [31:0] rd_alu, rs1, rs2, alu_comb;

  // NOTE: Inverting reset on pico-ice board because the button is active low
  logic rst_h;
  assign rst_h = ~reset;

  always_ff @(posedge clk) begin
    rd_alu <= alu_comb;

    if (fetchflag) iword <= mem_dataout;
    if (rst_h) iword <= 0;
  end

  logic intr_timer;
  logic load_access_fault;
  logic [2:0] funct3;
   wire       scl, sda;
   wire       _unused = &{scl, sda};
  memory memory_i (
      .clk(clk),
      .reset(rst_h),
      .ce(mem_ce),
      .funct3(funct3),
      .addr(mem_addr),
      .datain(rs2),
      .memwrite(memwrite),
      .dataout(mem_dataout),
      .busy(mem_busy),
      .valid(mem_valid),
      .so(so),
      .si(si),
      .tx(tx),
      .sclk(sclk),
      .sram_ce(sram_ce),
      .scl(scl),
      .sda(sda),
      .gpio_in(gpio_in),
      .gpio_out(gpio_out),
      .cos_ds(cos_ds),
      .cos_ds_n(cos_ds_n),
      .sin_ds(sin_ds),
      .sin_ds_n(sin_ds_n),
      .lo_i(lo_i),
      .lo_q(lo_q),
      .lo_ix(lo_ix),
      .lo_qx(lo_qx),
      .intr_timer(intr_timer),
      .load_access_fault(load_access_fault)
  );

  // NOTE: memwrite may only be set to flag determined by SW/LW
  // if actually mem_phase is currently executed. If we are fetching
  // instructions we need to set memwrite to 0
  assign memwrite = (memflag) ? control_flags[1] : 1'b0;

  // If we are in memory phase, the addr is the calculated address by the ALU
  // Else we use the programcounter to fetch the new iword
  assign mem_addr = (memflag) ? rd_alu : {16'b0, pc_new};
  assign funct3   = (memflag) ? iword[14:12] : FUNCT3_MEM_W;

  logic       jump_to_isr;
  logic       mret;
  logic       interrupt_clear;
  logic       interrupt_pending;
  logic       csr_write;
  logic [2:0] exceptions;
  control control_i (
      .clk(clk),
      .reset(rst_h),
      .iword(iword),
      .mem_busy(mem_busy),
      .mem_valid(mem_valid),
      .immediate(immediate),
      .control_flags(control_flags),
      .wbflag(wbflag),
      .memflag(memflag),
      .pcflag(pcflag),
      .fetchflag(fetchflag),
      .mem_ce(mem_ce),
      .interrupt_pending(interrupt_pending),
      .exceptions(exceptions),
      .jump_to_isr(jump_to_isr),
      .mret(mret),
      .csr_write(csr_write)
  );

  logic [15:0] isr_return;
  logic [15:0] isr_target;
  logic [31:0] csr_dataout;
  csr csr_i (
      .clk(clk),
      .reset(rst_h),
      .intr_timer(intr_timer),
      .intr_ext(intr_ext),
      .exceptions(exceptions),
      .mret(mret),
      .enter_isr(jump_to_isr),
      .data_in(rs1),
      .addr(iword[31:20]),
      .write_en(csr_write),
      .data_out(csr_dataout),
      .pc(pc_new),
      .isr_return(isr_return),
      .isr_target(isr_target),
      .interrupt_pending(interrupt_pending)
  );

  logic pc_misaligned;
  instructioncounter inst_i (
      .clk(clk),
      .reset(rst_h),
      .pcflag(pcflag),
      .interrupt(jump_to_isr),
      .jump(jump),
      .imm(imm),
      .isr_target(isr_target),
      .isr_return(isr_return),
      .pc_new(pc_new),
      .pc_misaligned(pc_misaligned)
  );

  assign imm = (iword[6:0] == 7'b1100111) ? rd_alu[15:0] : immediate[15:0];

  // Branch behavior calculated by ALU with BNE, BEQ, ...
  always_comb begin
    jump[0] = (control_flags[5]) ? rd_alu[16] : 1'b0;
    jump[1] = (control_flags[5]) ? rd_alu[17] : 1'b1;

    if (mret) begin
      jump = 2'b11;
    end
  end

  logic illegal_instruction;
  alu alu_i (
      .a(a),
      .b(b),
      .instruction(instruction),
      .rd(alu_comb),
      .illegal_instruction(illegal_instruction)
  );

  assign exceptions = {load_access_fault, illegal_instruction, pc_misaligned};

  assign instruction = {iword[31:25], iword[14:12], iword[6:0]};
  assign a = (control_flags[3]) ? {16'h0000, pc_new} : rs1;
  assign b = (control_flags[4]) ? immediate : rs2;
  // alu result goes back to the regs only if we don't have a mem_phase
  // Then it's either LW or SW (where regwrite would be 0, so no problem)

  always_comb begin
    rd = rd_alu;

    if (iword[6:0] == OP_JALR || iword[6:0] == OP_JAL) rd = pc_new + 4;
    else if (iword[6:0] == OP_CSR && iword[14:12] == FUNCT3_CSRR) rd = csr_dataout;
    else if (control_flags[0]) rd = mem_dataout;
  end

  regs regs (
`ifdef USE_POWER_PINS
      .VDD(VDD),
      .VSS(VSS),
`endif
      .clk(clk),
      .reset(rst_h),
      .regwrite(wbflag),
      .rs1adr(iword[18:15]),
      .rs2adr(iword[23:20]),
      .rdadr(iword[10:7]),
      .rd(rd),
      .rs1(rs1),
      .rs2(rs2)
  );

endmodule  // cpu
