module block_memory (
    input wire clk,

    // input port
    input wire [15:0] addr_i,
    input wire [15:0] wdata_i,
    input wire [15:0] rdata_i,
    input wire rw_i,
    input wire valid_i,

    // output port
    output reg [15:0] addr_o,
    output reg [15:0] wdata_o,
    output reg [15:0] rdata_o,
    output reg rw_o,
    output reg valid_o,

    // BRAM itself
    input wire user_clk,
    input wire [ADDR_WIDTH-1:0] user_addr,
    input wire [BRAM_WIDTH-1:0] user_din,
    output reg [BRAM_WIDTH-1:0] user_dout,
    input wire user_we);

    parameter BASE_ADDR = 0;
    parameter BRAM_WIDTH = 0;
    parameter BRAM_DEPTH = 0;
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);

    // ugly typecasting, but just computes ceil(BRAM_WIDTH / 16)
    localparam N_BRAMS = int'($ceil(real'(BRAM_WIDTH) / 16.0));
    localparam MAX_ADDR = BASE_ADDR + (BRAM_DEPTH * N_BRAMS);

    // Port A of BRAMs
    reg [N_BRAMS-1:0][ADDR_WIDTH-1:0] addra = 0;
    reg [N_BRAMS-1:0][15:0] dina = 0;
    reg [N_BRAMS-1:0][15:0] douta;
    reg [N_BRAMS-1:0] wea = 0;

    // Port B of BRAMs
    reg [N_BRAMS-1:0][15:0] dinb;
    reg [N_BRAMS-1:0][15:0] doutb;
    assign dinb = user_din;

    // kind of a hack to part select from a 2d array that's been flattened to 1d
    reg [(N_BRAMS*16)-1:0] doutb_flattened;
    assign doutb_flattened = doutb;
    assign user_dout = doutb_flattened[BRAM_WIDTH-1:0];

    // Pipelining
    reg [3:0][15:0] addr_pipe = 0;
    reg [3:0][15:0] wdata_pipe = 0;
    reg [3:0][15:0] rdata_pipe = 0;
    reg [3:0] valid_pipe = 0;
    reg [3:0] rw_pipe = 0;

    always @(posedge clk) begin
        addr_pipe[0] <= addr_i;
        wdata_pipe[0] <= wdata_i;
        rdata_pipe[0] <= rdata_i;
        valid_pipe[0] <= valid_i;
        rw_pipe[0] <= rw_i;

        addr_o <= addr_pipe[2];
        wdata_o <= wdata_pipe[2];
        rdata_o <= rdata_pipe[2];
        valid_o <= valid_pipe[2];
        rw_o <= rw_pipe[2];

        for(int i=1; i<4; i=i+1) begin
            addr_pipe[i] <= addr_pipe[i-1];
            wdata_pipe[i] <= wdata_pipe[i-1];
            rdata_pipe[i] <= rdata_pipe[i-1];
            valid_pipe[i] <= valid_pipe[i-1];
            rw_pipe[i] <= rw_pipe[i-1];
        end

        // throw BRAM operations into the front of the pipeline
        wea <= 0;
        if( (valid_i) && (addr_i >= BASE_ADDR) && (addr_i <= MAX_ADDR)) begin
            wea[addr_i % N_BRAMS]   <= rw_i;
            addra[addr_i % N_BRAMS] <= (addr_i - BASE_ADDR) / N_BRAMS;
            dina[addr_i % N_BRAMS]  <= wdata_i;
        end

        // pull BRAM reads from the back of the pipeline
        if( (valid_pipe[2]) && (addr_pipe[2] >= BASE_ADDR) && (addr_pipe[2] <= MAX_ADDR)) begin
            rdata_o <= douta[addr_pipe[2] % N_BRAMS];
        end
    end

    // generate the BRAMs
    genvar i;
    generate
        for(i=0; i<N_BRAMS; i=i+1) begin
            dual_port_bram #(
                .RAM_WIDTH(16),
                .RAM_DEPTH(BRAM_DEPTH)
                ) bram_full_width_i (

                // port A is controlled by the bus
                .clka(clk),
                .addra(addra[i]),
                .dina(dina[i]),
                .douta(douta[i]),
                .wea(wea[i]),

                // port B is exposed to the user
                .clkb(user_clk),
                .addrb(user_addr),
                .dinb(dinb[i]),
                .doutb(doutb[i]),
                .web(user_we));
        end
    endgenerate
endmodule