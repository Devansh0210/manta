`default_nettype none
`timescale 1ns / 1ps

/*
This manta definition was autogenerated on 15 Feb 2023 at 11:06:14 by fischerm

If this breaks or if you've got dank formal verification memes,
please contact fischerm [at] mit.edu.
*/

`define IDLE 0
`define ARM 1
`define FILL 2
`define DOWNLINK 3

`define ARM_BYTE 8'b00110000

module manta (
    input wire clk,
    input wire rst,

    /* Begin autogenerated probe definitions */
    input wire larry,
		input wire curly,
		input wire moe,
		input wire [3:0] shemp,
    /* End autogenerated probe definitions */

    input wire rxd,
    output logic txd);

    /* Begin autogenerated parameters */
    localparam SAMPLE_WIDTH = 7;
    localparam SAMPLE_DEPTH = 4096;

    localparam DATA_WIDTH = 8;
    localparam BAUDRATE = 115200;
    localparam CLK_FREQ_HZ = 100000000;

    logic trigger;
    assign trigger = (larry && curly && ~moe);

    logic [SAMPLE_WIDTH - 1 : 0] concat;
    assign concat = {larry, curly, moe, shemp};
    /* End autogenerated parameters */


    // FIFO
    logic [7:0] fifo_data_in;
    logic fifo_input_ready;

    logic fifo_request_output;
    logic [7:0] fifo_data_out;
    logic fifo_output_valid;

    logic [11:0] fifo_size;
    logic fifo_empty;
    logic fifo_full;

    fifo #(
        .WIDTH(SAMPLE_WIDTH),
        .DEPTH(SAMPLE_DEPTH)
    ) fifo (
        .clk(clk),
        .rst(rst),

        .data_in(fifo_data_in),
        .input_ready(fifo_input_ready),

        .request_output(fifo_request_output),
        .data_out(fifo_data_out),
        .output_valid(fifo_output_valid),

        .size(fifo_size),
        .empty(fifo_empty),
        .full(fifo_full));

    // Serial interface
    logic tx_start;
    logic [7:0] tx_data;
    logic tx_busy;

    logic [7:0] rx_data;
    logic rx_ready;
    logic rx_busy;


    uart_tx #(
		.DATA_WIDTH(DATA_WIDTH),
		.CLK_FREQ_HZ(CLK_FREQ_HZ),
		.BAUDRATE(BAUDRATE))
		tx (
		.clk(clk),
		.rst(rst),
		.start(tx_start),
		.data(tx_data),

		.busy(tx_busy),
		.txd(txd));

    uart_rx #(
		.DATA_WIDTH(DATA_WIDTH),
		.CLK_FREQ_HZ(CLK_FREQ_HZ),
		.BAUDRATE(BAUDRATE))
		rx (
		.clk(clk),
		.rst(rst),
		.rxd(rxd),

		.data(rx_data),
		.ready(rx_ready),
		.busy(rx_busy));


    /* State Machine */
    /*

    IDLE:
        - literally nothing is happening. the FIFO isn't being written to or read from. it should be empty.
        - an arm command over serial is what brings us into the ARM state

    ARM:
        - popping things onto FIFO. if the fifo is halfway full, we pop them off too.
        - meeting the trigger condition is what moves us into the filing state

    FILL:
        - popping things onto FIFO, until it's full. once it is full, we move into the downlinking state

    DOWNLINK:
        - popping thing off of the FIFO until it's empty. once it's empty, we move back into the IDLE state
    */

    /* Downlink State Machine Controller */
    /*

    - ila enters the downlink state
    - set fifo_output_request high for a clock cycle
    - when fifo_output_valid goes high, send fifo_data_out across the line
    - do nothing until tx_busy goes low
    - goto step 2

    */

    logic [1:0] state;
    logic [2:0] downlink_fsm_state;

    always_ff @(posedge clk) begin
        if(rst) begin
            state <= `IDLE;
            downlink_fsm_state <= 0;
            tx_data <= 0;
            tx_start <= 0;
        end
        else begin

            case (state)
                `IDLE : begin
                    fifo_input_ready <= 0;
                    fifo_request_output <= 0;

                    if (rx_ready && rx_data == `ARM_BYTE) state <= `ARM;

                end

                `ARM : begin
                    // place samples into FIFO
                    fifo_input_ready <= 1;
                    fifo_data_in <= concat;

                    // remove old samples if we're more than halfway full
                    fifo_request_output <= (fifo_size >= SAMPLE_DEPTH / 2);

                    if(trigger) state <= `FILL;
                end

                `FILL : begin
                    // place samples into FIFO
                    fifo_input_ready <= 1;
                    fifo_data_in <= concat;

                    // don't pop anything out the FIFO
                    fifo_request_output <= 0;

                    if(fifo_size == SAMPLE_DEPTH - 1) state <= `DOWNLINK;
                end

                `DOWNLINK : begin
                    // place no samples into FIFO
                    fifo_input_ready <= 0;


                    case (downlink_fsm_state)
                        0 : begin
                            if (~fifo_empty) begin
                                fifo_request_output <= 1;
                                downlink_fsm_state <= 1;
                            end

                            else state <= `IDLE;
                        end

                        1 : begin
                            fifo_request_output <= 0;

                            if (fifo_output_valid) begin
                                tx_data <= fifo_data_out;
                                tx_start <= 1;
                                downlink_fsm_state <= 2;
                            end
                        end

                        2 : begin
                            tx_start <= 0;

                            if (~tx_busy && ~tx_start) downlink_fsm_state <= 0;
                        end
                    endcase

                end
            endcase
        end
    end

endmodule


`default_nettype wire`default_nettype none
`timescale 1ns / 1ps

module fifo (
	input wire clk,
	input wire rst,

	input wire [WIDTH - 1:0] data_in,
	input wire input_ready,

	input wire request_output,
	output logic [WIDTH - 1:0] data_out,
	output logic output_valid,

	output logic [AW:0] size,
	output logic empty,
	output logic full
	);

	parameter WIDTH = 8;
	parameter DEPTH = 4096;
	localparam AW = $clog2(DEPTH);

	logic [AW:0] write_pointer;
	logic [AW:0] read_pointer;

	logic empty_int;
	assign empty_int = (write_pointer[AW] == read_pointer[AW]);

	logic full_or_empty;
	assign full_or_empty = (write_pointer[AW-1:0] ==	read_pointer[AW-1:0]);

	assign full = full_or_empty & !empty_int;
	assign empty = full_or_empty & empty_int;
	assign size = write_pointer - read_pointer;

	logic output_valid_pip_0;
	logic output_valid_pip_1;

	always @(posedge clk) begin
		if (input_ready && ~full)
			write_pointer <= write_pointer + 1'd1;

	 	if (request_output && ~empty)
			read_pointer <= read_pointer + 1'd1;
			output_valid_pip_0 <= request_output;
			output_valid_pip_1 <= output_valid_pip_0;
			output_valid <= output_valid_pip_1;

		if (rst) begin
			read_pointer  <= 0;
			write_pointer <= 0;
		end
	end

	xilinx_true_dual_port_read_first_2_clock_ram #(
		.RAM_WIDTH(WIDTH),
		.RAM_DEPTH(DEPTH),
		.RAM_PERFORMANCE("HIGH_PERFORMANCE")

		) buffer (

		// write port
		.clka(clk),
		.rsta(rst),
		.ena(1),
		.addra(write_pointer),
		.dina(data_in),
		.wea(input_ready),
		.regcea(1),
		.douta(),

		// read port
		.clkb(clk),
		.rstb(rst),
		.enb(1),
		.addrb(read_pointer),
		.dinb(),
		.web(0),
		.regceb(1),
		.doutb(data_out));
	endmodule

`default_nettype wire
`default_nettype none
`timescale 1ns / 1ps


module uart_tx(
	input wire clk,
	input wire rst,
	input wire [DATA_WIDTH-1:0] data,
	input wire start,
	
	output logic busy,
	output logic txd
	);

	// Just going to stick to 8N1 for now, we'll come back and
	// parameterize this later.
	
	parameter DATA_WIDTH = 8;
	parameter CLK_FREQ_HZ = 100_000_000;
	parameter BAUDRATE = 115200;

	localparam PRESCALER = CLK_FREQ_HZ / BAUDRATE;

	logic [$clog2(PRESCALER) - 1:0] baud_counter;
	logic [$clog2(DATA_WIDTH + 2):0] bit_index;
	logic [DATA_WIDTH - 1:0] data_buf;

	// make secondary logic for baudrate
	always_ff @(posedge clk) begin
		if(rst) baud_counter <= 0;
		else begin
			baud_counter <= (baud_counter == PRESCALER - 1) ? 0 : baud_counter + 1;
		end
	end
	
	always_ff @(posedge clk) begin
		
		// reset logic
		if(rst) begin
			bit_index <= 0;
			busy <= 0;
			txd <= 1; // idle high
		end

		// enter transmitting state logic
		// don't allow new requests to interrupt current
		// transfers
		if(start && ~busy) begin
			busy <= 1;
			data_buf <= data;
		end


		// transmitting state logic
		else if(baud_counter == 0 && busy) begin

			if (bit_index == 0) begin
				txd <= 0;
				bit_index <= bit_index + 1;
			end

			else if ((bit_index < DATA_WIDTH + 1) && (bit_index > 0)) begin
				txd <= data_buf[bit_index - 1];
				bit_index <= bit_index + 1;
			end
			
			else if (bit_index == DATA_WIDTH + 1) begin
				txd <= 1;
				bit_index <= bit_index + 1;
			end

			else if (bit_index >= DATA_WIDTH + 1) begin
				busy <= 0;
				bit_index <= 0;
			end
		end
	end
endmodule


`default_nettype wire
`default_nettype none
`timescale 1ns / 1ps 

module uart_rx(
    input wire clk,
    input wire rst,
    input wire rxd,

    output logic [DATA_WIDTH - 1:0] data,
    output logic ready,
    output logic busy
    );

    // Just going to stick to 8N1 for now, we'll come back and
	// parameterize this later.
	
	parameter DATA_WIDTH = 8;
	parameter CLK_FREQ_HZ = 100_000_000;
	parameter BAUDRATE = 115200;

	localparam PRESCALER = CLK_FREQ_HZ / BAUDRATE;

	logic [$clog2(PRESCALER) - 1:0] baud_counter;
	logic [$clog2(DATA_WIDTH + 2):0] bit_index;
    logic [DATA_WIDTH + 2 : 0] data_buf;

    logic prev_rxd;

	always_ff @(posedge clk) begin
        prev_rxd <= rxd;
        ready <= 0;
        baud_counter <= (baud_counter == PRESCALER - 1) ? 0 : baud_counter + 1;
	
		// reset logic
		if(rst) begin
			bit_index <= 0;
            data <= 0;
            busy <= 0;
            baud_counter <= 0;
		end

        // start receiving if we see a falling edge, and not already busy
        else if (prev_rxd && ~rxd && ~busy) begin
            busy <= 1;
            data_buf <= 0;
            baud_counter <= 0;
        end

        // if we're actually receiving
        else if (busy) begin
            if (baud_counter == PRESCALER / 2) begin
                data_buf[bit_index] <= rxd;
                bit_index <= bit_index + 1;

                if (bit_index == DATA_WIDTH + 1) begin
                    busy <= 0;
                    bit_index <= 0;
                    

                    if (rxd && ~data_buf[0]) begin
                        data <= data_buf[DATA_WIDTH : 1];
                        ready <= 1;
                    end
                end
            end    
        end
    end

		
endmodule

`default_nettype wire
//  Xilinx True Dual Port RAM, Read First, Dual Clock
//  This code implements a parameterizable true dual port memory (both ports can read and write).
//  The behavior of this RAM is when data is written, the prior memory contents at the write
//  address are presented on the output port.  If the output data is
//  not needed during writes or the last read value is desired to be retained,
//  it is suggested to use a no change RAM as it is more power efficient.
//  If a reset or enable is not necessary, it may be tied off or removed from the code.

module xilinx_true_dual_port_read_first_2_clock_ram #(
  parameter RAM_WIDTH = 18,                       // Specify RAM data width
  parameter RAM_DEPTH = 1024,                     // Specify RAM depth (number of entries)
  parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE", // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
  parameter INIT_FILE = ""                        // Specify name/location of RAM initialization file if using one (leave blank if not)
) (
  input [clogb2(RAM_DEPTH-1)-1:0] addra,  // Port A address bus, width determined from RAM_DEPTH
  input [clogb2(RAM_DEPTH-1)-1:0] addrb,  // Port B address bus, width determined from RAM_DEPTH
  input [RAM_WIDTH-1:0] dina,           // Port A RAM input data
  input [RAM_WIDTH-1:0] dinb,           // Port B RAM input data
  input clka,                           // Port A clock
  input clkb,                           // Port B clock
  input wea,                            // Port A write enable
  input web,                            // Port B write enable
  input ena,                            // Port A RAM Enable, for additional power savings, disable port when not in use
  input enb,                            // Port B RAM Enable, for additional power savings, disable port when not in use
  input rsta,                           // Port A output reset (does not affect memory contents)
  input rstb,                           // Port B output reset (does not affect memory contents)
  input regcea,                         // Port A output register enable
  input regceb,                         // Port B output register enable
  output [RAM_WIDTH-1:0] douta,         // Port A RAM output data
  output [RAM_WIDTH-1:0] doutb          // Port B RAM output data
);

  reg [RAM_WIDTH-1:0] BRAM [RAM_DEPTH-1:0];
  reg [RAM_WIDTH-1:0] ram_data_a = {RAM_WIDTH{1'b0}};
  reg [RAM_WIDTH-1:0] ram_data_b = {RAM_WIDTH{1'b0}};

  //this loop below allows for rendering with iverilog simulations!
  /*
  integer idx;
  for(idx = 0; idx < RAM_DEPTH; idx = idx+1) begin: cats
    wire [RAM_WIDTH-1:0] tmp;
    assign tmp = BRAM[idx];
  end
  */

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  generate
    if (INIT_FILE != "") begin: use_init_file
      initial
        $readmemh(INIT_FILE, BRAM, 0, RAM_DEPTH-1);
    end else begin: init_bram_to_zero
      integer ram_index;
      initial
        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
          BRAM[ram_index] = {RAM_WIDTH{1'b0}};
    end
  endgenerate
  integer idx;
  // initial begin
  //   for (idx = 0; idx < RAM_DEPTH; idx = idx + 1) begin
  //     $dumpvars(0, BRAM[idx]);
  //   end
  // end
  always @(posedge clka)
    if (ena) begin
      if (wea)
        BRAM[addra] <= dina;
      ram_data_a <= BRAM[addra];
    end

  always @(posedge clkb)
    if (enb) begin
      if (web)
        BRAM[addrb] <= dinb;
      ram_data_b <= BRAM[addrb];
    end

  //  The following code generates HIGH_PERFORMANCE (use output register) or LOW_LATENCY (no output register)
  generate
    if (RAM_PERFORMANCE == "LOW_LATENCY") begin: no_output_register

      // The following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
       assign douta = ram_data_a;
       assign doutb = ram_data_b;

    end else begin: output_register

      // The following is a 2 clock cycle read latency with improve clock-to-out timing

      reg [RAM_WIDTH-1:0] douta_reg = {RAM_WIDTH{1'b0}};
      reg [RAM_WIDTH-1:0] doutb_reg = {RAM_WIDTH{1'b0}};

      always @(posedge clka)
        if (rsta)
          douta_reg <= {RAM_WIDTH{1'b0}};
        else if (regcea)
          douta_reg <= ram_data_a;

      always @(posedge clkb)
        if (rstb)
          doutb_reg <= {RAM_WIDTH{1'b0}};
        else if (regceb)
          doutb_reg <= ram_data_b;

      assign douta = douta_reg;
      assign doutb = doutb_reg;

    end
  endgenerate

  //  The following function calculates the address width based on specified RAM depth
  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule

// The following is an instantiation template for xilinx_true_dual_port_read_first_2_clock_ram
/*
  //  Xilinx True Dual Port RAM, Read First, Dual Clock
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(18),                       // Specify RAM data width
    .RAM_DEPTH(1024),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
    .INIT_FILE("")                        // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) your_instance_name (
    .addra(addra),   // Port A address bus, width determined from RAM_DEPTH
    .addrb(addrb),   // Port B address bus, width determined from RAM_DEPTH
    .dina(dina),     // Port A RAM input data, width determined from RAM_WIDTH
    .dinb(dinb),     // Port B RAM input data, width determined from RAM_WIDTH
    .clka(clka),     // Port A clock
    .clkb(clkb),     // Port B clock
    .wea(wea),       // Port A write enable
    .web(web),       // Port B write enable
    .ena(ena),       // Port A RAM Enable, for additional power savings, disable port when not in use
    .enb(enb),       // Port B RAM Enable, for additional power savings, disable port when not in use
    .rsta(rsta),     // Port A output reset (does not affect memory contents)
    .rstb(rstb),     // Port B output reset (does not affect memory contents)
    .regcea(regcea), // Port A output register enable
    .regceb(regceb), // Port B output register enable
    .douta(douta),   // Port A RAM output data, width determined from RAM_WIDTH
    .doutb(doutb)    // Port B RAM output data, width determined from RAM_WIDTH
  );
*/


