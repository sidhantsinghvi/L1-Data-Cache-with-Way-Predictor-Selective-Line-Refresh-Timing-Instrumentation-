module memory_model #(
    parameter MEM_WORDS = 4096
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        req_valid,
    input  wire        req_we,
    input  wire [31:0] req_addr,
    input  wire [31:0] req_wdata,
    output reg  [31:0] resp_rdata,
    output reg         resp_valid
);

    localparam ADDR_BITS = $clog2(MEM_WORDS);

    reg [31:0] mem [0:MEM_WORDS-1];

    reg        req_valid_d;
    reg        req_we_d;
    reg [31:0] req_addr_d;
    reg [31:0] req_wdata_d;

    wire [ADDR_BITS-1:0] word_index = req_addr[ADDR_BITS+1:2];
    wire [ADDR_BITS-1:0] word_index_d = req_addr_d[ADDR_BITS+1:2];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            resp_valid <= 1'b0;
            resp_rdata <= 32'd0;
            req_valid_d <= 1'b0;
            req_we_d <= 1'b0;
            req_addr_d <= 32'd0;
            req_wdata_d <= 32'd0;
            for (i = 0; i < MEM_WORDS; i = i + 1) begin
                mem[i] <= 32'd0;
            end
        end else begin
            resp_valid <= req_valid_d;
            if (req_valid_d) begin
                if (req_we_d) begin
                    resp_rdata <= 32'd0;
                end else begin
                    resp_rdata <= mem[word_index_d];
                end
            end else begin
                resp_rdata <= 32'd0;
            end

            req_valid_d <= req_valid;
            req_we_d <= req_we;
            req_addr_d <= req_addr;
            req_wdata_d <= req_wdata;

            if (req_valid) begin
                if (req_we) begin
                    mem[word_index] <= req_wdata;
                end
            end
        end
    end

endmodule
