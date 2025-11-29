module stale_tracker #(
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
    input  wire                   tick_en,
    input  wire [3:0]             stale_threshold,
    output reg                    stale_event
);

    reg [3:0] counters [0:NUM_SETS-1][0:NUM_WAYS-1];

    integer si;
    integer wi;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stale_event <= 1'b0;
            for (si = 0; si < NUM_SETS; si = si + 1) begin
                for (wi = 0; wi < NUM_WAYS; wi = wi + 1) begin
                    counters[si][wi] <= 4'd0;
                end
            end
        end else begin
            stale_event <= 1'b0;
            if (tick_en) begin
                for (si = 0; si < NUM_SETS; si = si + 1) begin
                    for (wi = 0; wi < NUM_WAYS; wi = wi + 1) begin
                        if (counters[si][wi] != 4'hF) begin
                            if ((stale_threshold != 4'd0) && (counters[si][wi] >= stale_threshold - 1)) begin
                                stale_event <= 1'b1;
                            end
                            counters[si][wi] <= counters[si][wi] + 1'b1;
                        end
                    end
                end
            end
            if (access_en) begin
                counters[access_index][access_way] <= 4'd0;
            end
        end
    end

endmodule
