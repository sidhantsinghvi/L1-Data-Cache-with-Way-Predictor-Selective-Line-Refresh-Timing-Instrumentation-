module data_array #(
    parameter NUM_SETS = 64,
    parameter NUM_WAYS = 4,
    parameter LINE_BYTES = 16,
    parameter INDEX_BITS = $clog2(NUM_SETS),
    parameter WAY_BITS = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1,
    parameter WORD_SEL_BITS = (LINE_BYTES > 4) ? $clog2(LINE_BYTES/4) : 1
)(
    input wire                      clk,
    input wire                      we,
    input wire [INDEX_BITS-1:0]     index,
    input wire [WAY_BITS-1:0]       way,
    input wire [WORD_SEL_BITS-1:0]  word_sel,
    input wire [31:0]               wdata,
    output wire [31:0]              rdata
);

    localparam WORDS_PER_LINE = LINE_BYTES / 4;

    reg [31:0] mem [0:NUM_SETS-1][0:WORDS_PER_LINE-1];
    reg [31:0] rdata_r;

    wire unused_way;
    assign unused_way = |way;

    assign rdata = rdata_r;

    always @(*) begin
        rdata_r = mem[index][word_sel];
    end

    always @(posedge clk) begin
        if (we) begin
            mem[index][word_sel] <= wdata;
        end
    end

endmodule
