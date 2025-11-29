module lru #(
    parameter NUM_SETS = 64,
    parameter NUM_WAYS = 4,
    parameter INDEX_BITS = $clog2(NUM_SETS),
    parameter WAY_BITS = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   access_en,
    input  wire [INDEX_BITS-1:0]  access_index,
    input  wire [WAY_BITS-1:0]    access_way,
    output wire [WAY_BITS-1:0]    victim_way
);

    reg [WAY_BITS-1:0] next_way [0:NUM_SETS-1];

    assign victim_way = next_way[access_index];

    integer s;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (s = 0; s < NUM_SETS; s = s + 1) begin
                next_way[s] <= {WAY_BITS{1'b0}};
            end
        end else if (access_en) begin
            next_way[access_index] <= access_way + 1'b1;
        end
    end

endmodule
