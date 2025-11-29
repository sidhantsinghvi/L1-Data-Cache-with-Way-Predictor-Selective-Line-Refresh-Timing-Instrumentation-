module tag_array #(
    parameter NUM_SETS = 64,
    parameter NUM_WAYS = 4,
    parameter TAG_BITS = 22,
    parameter INDEX_BITS = $clog2(NUM_SETS),
    parameter WAY_BITS = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1
)(
    input wire                      clk,
    input wire                      we,
    input wire [INDEX_BITS-1:0]     index,
    input wire [WAY_BITS-1:0]       way,
    input wire [TAG_BITS-1:0]       tag_in,
    output wire [TAG_BITS-1:0]      tag_out
);

    reg [TAG_BITS-1:0] mem [0:NUM_SETS-1];
    reg [TAG_BITS-1:0] tag_out_r;

    wire unused_way;
    assign unused_way = |way;

    assign tag_out = tag_out_r;

    always @(*) begin
        tag_out_r = mem[index];
    end

    always @(posedge clk) begin
        if (we) begin
            mem[index] <= tag_in;
        end
    end

endmodule
