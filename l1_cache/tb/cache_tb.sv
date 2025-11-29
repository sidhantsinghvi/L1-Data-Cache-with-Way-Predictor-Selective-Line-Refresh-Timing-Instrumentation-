`timescale 1ns/1ps

module cache_tb;
    logic clk;
    logic rst_n;

    // CPU/cache interface
    logic        req_valid;
    logic        req_we;
    logic [31:0] req_addr;
    logic [31:0] req_wdata;
    logic [3:0]  req_wstrb;
    logic        resp_valid;
    logic [31:0] resp_rdata;
    logic        resp_stall;

    // Memory side
    logic        mem_req_valid;
    logic        mem_req_we;
    logic [31:0] mem_req_addr;
    logic [31:0] mem_req_wdata;
    logic [31:0] mem_resp_rdata;
    logic        mem_resp_valid;

    // Counters
    wire [31:0] hits;
    wire [31:0] misses;
    wire [31:0] evictions;
    wire [31:0] dirty_evictions;
    wire [31:0] predictor_hits;
    wire [31:0] predictor_misses;
    wire [31:0] stale_events;

    l1_cache_top dut (
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
        .hits(hits),
        .misses(misses),
        .evictions(evictions),
        .dirty_evictions(dirty_evictions),
        .predictor_hits(predictor_hits),
        .predictor_misses(predictor_misses),
        .stale_events(stale_events)
    );

    memory_model #(
        .MEM_WORDS(4096)
    ) mem (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(mem_req_valid),
        .req_we(mem_req_we),
        .req_addr(mem_req_addr),
        .req_wdata(mem_req_wdata),
        .resp_rdata(mem_resp_rdata),
        .resp_valid(mem_resp_valid)
    );

    traffic_gen gen (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_we(req_we),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wstrb(req_wstrb),
        .resp_stall(resp_stall),
        .resp_valid(resp_valid),
        .resp_rdata(resp_rdata)
    );

    // Clock/reset
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
    end

    integer cycle;
    initial begin
        wait (rst_n);
        for (cycle = 0; cycle < 2000; cycle = cycle + 1) begin
            @(posedge clk);
        end
        $display("\n=== Cache Performance Summary ===");
        $display("hits=%0d misses=%0d evictions=%0d dirty_evictions=%0d", hits, misses, evictions, dirty_evictions);
        $display("predictor hits=%0d predictor misses=%0d stale events=%0d", predictor_hits, predictor_misses, stale_events);
        if ((hits + misses) == 0) begin
            $fatal(1, "Cache never served any request");
        end
        if ((predictor_hits + predictor_misses) == 0) begin
            $fatal(1, "Way predictor never updated");
        end
        if (stale_events == 0) begin
            $fatal(1, "No stale events detected");
        end
        $display("Simulation completed successfully");
        $finish;
    end

endmodule
