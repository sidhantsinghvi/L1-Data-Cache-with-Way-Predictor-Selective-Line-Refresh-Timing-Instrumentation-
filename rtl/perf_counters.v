module perf_counters(
    input  wire clk,
    input  wire rst_n,
    input  wire hit_pulse,
    input  wire miss_pulse,
    input  wire eviction_pulse,
    input  wire dirty_eviction_pulse,
    input  wire predictor_hit_pulse,
    input  wire predictor_miss_pulse,
    input  wire stale_event_pulse,
    output reg [31:0] hits,
    output reg [31:0] misses,
    output reg [31:0] evictions,
    output reg [31:0] dirty_evictions,
    output reg [31:0] predictor_hits,
    output reg [31:0] predictor_misses,
    output reg [31:0] stale_events
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hits <= 32'd0;
            misses <= 32'd0;
            evictions <= 32'd0;
            dirty_evictions <= 32'd0;
            predictor_hits <= 32'd0;
            predictor_misses <= 32'd0;
            stale_events <= 32'd0;
        end else begin
            if (hit_pulse) begin
                hits <= hits + 1'b1;
            end
            if (miss_pulse) begin
                misses <= misses + 1'b1;
            end
            if (eviction_pulse) begin
                evictions <= evictions + 1'b1;
            end
            if (dirty_eviction_pulse) begin
                dirty_evictions <= dirty_evictions + 1'b1;
            end
            if (predictor_hit_pulse) begin
                predictor_hits <= predictor_hits + 1'b1;
            end
            if (predictor_miss_pulse) begin
                predictor_misses <= predictor_misses + 1'b1;
            end
            if (stale_event_pulse) begin
                stale_events <= stale_events + 1'b1;
            end
        end
    end

endmodule
