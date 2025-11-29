module way_predictor #(
    parameter NUM_SETS = 64,
    parameter NUM_WAYS = 4,
    parameter INDEX_BITS = $clog2(NUM_SETS),
    parameter WAY_BITS = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   update_en,
    input  wire [INDEX_BITS-1:0]  index,
    input  wire [WAY_BITS-1:0]    actual_way,
    output wire [WAY_BITS-1:0]    predicted_way
);

    reg [WAY_BITS-1:0] table [0:NUM_SETS-1];
    reg [WAY_BITS-1:0] predicted_way_r;

    assign predicted_way = predicted_way_r;

    always @(*) begin
        predicted_way_r = table[index];
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                table[i] <= {WAY_BITS{1'b0}};
            end
        end else if (update_en) begin
            table[index] <= actual_way;
        end
    end

endmodule
