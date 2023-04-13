    `timescale 1ns / 1ps
    `default_nettype none

    module top_level(
        input wire clk_100mhz,

        output logic [3:0] vga_r, vga_g, vga_b,
        output logic vga_hs, vga_vs,

        input wire btnc,
        output logic [15:0] led,
        output logic ca, cb, cc, cd, ce, cf, cg,
        output logic [7:0] an,

        input wire uart_txd_in,
	    output logic uart_rxd_out);

    logic clk_65mhz;

    clk_wiz_lab3 clk_gen(
        .clk_in1(clk_100mhz),
        .clk_out1(clk_65mhz));

    // VGA signals
    logic [10:0] hcount;
    logic [9:0] vcount;
    logic hsync, vsync, blank;

    vga vga_gen(
        .pixel_clk_in(clk_65mhz),
        .hcount_out(hcount),
        .vcount_out(vcount),
        .hsync_out(hsync),
        .vsync_out(vsync),
        .blank_out(blank));

    localparam WIDTH = 128;
    localparam HEIGHT = 128;

    localparam X = 0;
    localparam Y = 0;

    // calculate rom address
    logic [$clog2(WIDTH*HEIGHT)-1:0] image_addr;
    assign image_addr = (hcount - X) + ((vcount - Y) * WIDTH);

    logic in_sprite;
    assign in_sprite = ((hcount >= X && hcount < (X + WIDTH)) &&
                        (vcount >= Y && vcount < (Y + HEIGHT)));

    manta manta_inst (
        .clk(clk_65mhz),

        .rx(uart_txd_in),
        .tx(uart_rxd_out),

        .image_mem_clk(clk_65mhz),
        .image_mem_addr(image_addr),
        .image_mem_din(),
        .image_mem_dout(sprite_color),
        .image_mem_we(1'b0));

    logic [11:0] sprite_color;
    logic [11:0] color;
    assign color = in_sprite ? sprite_color : 12'h0;

    // the following lines are required for the Nexys4 VGA circuit - do not change
    assign vga_r = ~blank ? color[11:8]: 0;
    assign vga_g = ~blank ? color[7:4] : 0;
    assign vga_b = ~blank ? color[3:0] : 0;

    assign vga_hs = ~hsync;
    assign vga_vs = ~vsync;


    // debug
    assign led = manta_inst.brx_image_mem_addr;

    logic [6:0] cat;
	assign {cg,cf,ce,cd,cc,cb,ca} = cat;
    ssd ssd (
        .clk_in(clk_65mhz),
        .rst_in(btnc),
        .val_in( {manta_inst.image_mem_btx_rdata, manta_inst.brx_image_mem_wdata} ),
        .cat_out(cat),
        .an_out(an));
    endmodule

    `default_nettype wire
