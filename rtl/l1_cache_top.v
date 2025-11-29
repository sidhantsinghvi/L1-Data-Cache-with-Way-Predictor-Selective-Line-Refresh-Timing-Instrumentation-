module l1_cache_top #(
    parameter NUM_SETS   = 64,
    parameter NUM_WAYS   = 4,
    parameter LINE_BYTES = 16
)(
    input  wire         clk,
    input  wire         rst_n,

    // CPU-side request interface
    input  wire         req_valid,
    input  wire         req_we,
    input  wire [31:0]  req_addr,
    input  wire [31:0]  req_wdata,
    input  wire [3:0]   req_wstrb,

    // CPU-side response interface
    output wire         resp_valid,
    output wire [31:0]  resp_rdata,
    output wire         resp_stall,

    // Simple memory interface (hooked up in testbench)
    output wire         mem_req_valid,
    output wire         mem_req_we,
    output wire [31:0]  mem_req_addr,
    output wire [31:0]  mem_req_wdata,
    input  wire [31:0]  mem_resp_rdata,
    input  wire         mem_resp_valid,

    // Performance counters (for visibility in testbench)
    output wire [31:0]  hits,
    output wire [31:0]  misses,
    output wire [31:0]  evictions,
    output wire [31:0]  dirty_evictions,
    output wire [31:0]  predictor_hits,
    output wire [31:0]  predictor_misses,
    output wire [31:0]  stale_events
);

    wire hit_pulse;
    wire miss_pulse;
    wire eviction_pulse;
    wire dirty_eviction_pulse;
    wire predictor_hit_pulse;
    wire predictor_miss_pulse;
    wire stale_event_pulse;

    l1_cache_core #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS),
        .LINE_BYTES(LINE_BYTES)
    ) core (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_we(req_we),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wstrb(req_wstrb),
        .resp_valid(resp_valid),
        .resp_rdata(resp_rdata),
        .resp_stall(resp_stall),
        .mem_req_valid(mem_req_valid),
        .mem_req_we(mem_req_we),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_resp_rdata(mem_resp_rdata),
        .mem_resp_valid(mem_resp_valid),
        .hit_pulse(hit_pulse),
        .miss_pulse(miss_pulse),
        .eviction_pulse(eviction_pulse),
        .dirty_eviction_pulse(dirty_eviction_pulse),
        .predictor_hit_pulse(predictor_hit_pulse),
        .predictor_miss_pulse(predictor_miss_pulse),
        .stale_event_pulse(stale_event_pulse)
    );

    perf_counters perf (
        .clk(clk),
        .rst_n(rst_n),
        .hit_pulse(hit_pulse),
        .miss_pulse(miss_pulse),
        .eviction_pulse(eviction_pulse),
        .dirty_eviction_pulse(dirty_eviction_pulse),
        .predictor_hit_pulse(predictor_hit_pulse),
        .predictor_miss_pulse(predictor_miss_pulse),
        .stale_event_pulse(stale_event_pulse),
        .hits(hits),
        .misses(misses),
        .evictions(evictions),
        .dirty_evictions(dirty_evictions),
        .predictor_hits(predictor_hits),
        .predictor_misses(predictor_misses),
        .stale_events(stale_events)
    );

endmodule
