module i2c_master (
    input logic clk,
    input logic reset,

    // I2C pins
    input  logic sda_i,
    output logic sda_o,
    output logic sda_oe,
    output logic scl,

    // memory interface
    input  logic [ 3:0] mask,
    input  logic [ 6:0] device_addr,
    input  logic [31:0] data_in,
    output logic [31:0] data_out,

    // status flags
    input  logic write,
    output logic busy,
    output logic valid
);

  typedef enum {
    RESET,
    START1,
    START2,
    SEND_ADDR,

    SEND_CMD,
    RECV_CMD_ACK,

    RECV_FRAME,
    SEND_FRAME_ACK,
    SEND_FRAME,
    RECV_FRAME_ACK,

    STOP1,
    STOP2,
    END
  } states_t;

  states_t        state = RESET;

  logic           scl_tmp = 1;
  logic           scl_trigger = 0;
  logic    [31:0] scl_counter = 0;

  logic    [ 1:0] frame_index = 3;
  logic           send_cmd = 1;
  logic    [ 7:0] frame;

  byte            index;
  logic           ack;
  byte            signal_stage = 0;

  always_ff @(posedge clk) begin
    // Step clock down to 100 kHz as supported by I2C
    scl_trigger <= 0;
    if (scl_counter == 31) begin
      scl_trigger <= 1;
      scl_counter <= 0;
    end else scl_counter <= scl_counter + 1;

    if (reset) begin
      scl_counter <= 31;
    end
  end

  // Posedge of scl. State transistions
  always_ff @(posedge clk) begin
    if (reset) begin
      state <= RESET;

      send_cmd <= 1;
      signal_stage <= 3;
    end else if (scl_trigger == 1) begin  // == negedge of scl
      if (signal_stage == 3) signal_stage <= 0;
      else signal_stage <= signal_stage + 1;

      if (signal_stage == 3) begin
        unique case (state)
          RESET:  state <= START1;
          START1: state <= START2;
          START2: begin
            state <= SEND_ADDR;
            index <= 6;
          end

          SEND_ADDR: begin
            if (index == 0) begin
              state <= SEND_CMD;
              index <= 7;
            end else index <= index - 1;
          end

          SEND_CMD: state <= RECV_CMD_ACK;
          RECV_CMD_ACK: begin
            if (write) state <= SEND_FRAME;
            else state <= RECV_FRAME;

            if (mask[3] == 1) frame_index <= 3;
            else if (mask[2] == 1) frame_index <= 2;
            else if (mask[1] == 1) frame_index <= 1;
            else frame_index <= 0;
          end

          RECV_FRAME: begin
            if (index == 0) begin
              state <= SEND_FRAME_ACK;
              index <= 7;
            end else index <= index - 1;

            data_out[frame_index*8+index] <= sda_i;
          end
          SEND_FRAME_ACK: state <= STOP1;

          SEND_FRAME: begin
            if (index == 0) begin
              state <= RECV_FRAME_ACK;
              index <= 7;
            end else index <= index - 1;
          end
          RECV_FRAME_ACK: begin
            state <= STOP1;
            if (frame_index == 3) begin

              if (mask[2] == 1) begin
                frame_index <= 2;
                state <= SEND_FRAME;
              end else if (mask[1] == 1) begin
                frame_index <= 1;
                state <= SEND_FRAME;
              end else if (mask[0] == 1) begin
                frame_index <= 0;
                state <= SEND_FRAME;
              end

            end else if (frame_index == 2) begin

              if (mask[1] == 1) begin
                frame_index <= 1;
                state <= SEND_FRAME;
              end else if (mask[0] == 1) begin
                frame_index <= 0;
                state <= SEND_FRAME;
              end

            end else if (frame_index == 1) begin
              if (mask[0] == 1) begin
                frame_index <= 0;
                state <= SEND_FRAME;
              end
            end
          end

          STOP1: state <= STOP2;
          STOP2: state <= END;
          END:   state <= END;
        endcase
      end
    end
  end

  always_comb begin
    sda_oe = 1;
    // sda_tmp = 1;
    sda_o = 1;
    busy = 1;
    scl = 0;
    valid = 0;

    if (signal_stage == 1 || signal_stage == 2) scl = 1;

    frame = data_in[frame_index*8+:8];

    unique case (state)
      // Initial stuff
      START1: begin  // First action of start condition
        sda_o = 0;
        scl   = 1;
      end
      START2: begin  // Second action of start condition
        sda_o = 0;
        scl   = 0;
      end

      SEND_ADDR: sda_o = device_addr[index];
      SEND_CMD:  sda_o = ~write;  // 0: write, 1: read
      RECV_CMD_ACK: begin
        // ack = sda;
        sda_oe = 0;
      end

      RECV_FRAME: begin
        sda_oe = 0;
      end
      SEND_FRAME_ACK: sda_o = 1;

      SEND_FRAME: sda_o = frame[index];
      RECV_FRAME_ACK: begin
        // ack = sda;
        sda_oe = 0;
      end

      // Final stuff
      STOP1: begin  // First action of stop condition
        scl   = 1;
        sda_o = 0;
      end
      STOP2: begin  // Second action of stop condition
        scl   = 1;
        sda_o = 1;
      end

      RESET, END: begin
        scl  = 1;
        busy = 0;
      end
    endcase
  end

  // assign sda = (tristate_en) ? sda_tmp : 1'bZ;

endmodule
