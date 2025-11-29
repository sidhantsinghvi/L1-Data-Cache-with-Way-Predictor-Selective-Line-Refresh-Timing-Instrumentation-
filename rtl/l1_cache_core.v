module l1_cache_core #(
    parameter NUM_SETS   = 64,
    parameter NUM_WAYS   = 4,
    parameter LINE_BYTES = 16
)(
    input  wire         clk,
    input  wire         rst_n,

    input  wire         req_valid,
    input  wire         req_we,
    input  wire [31:0]  req_addr,
    input  wire [31:0]  req_wdata,
    input  wire [3:0]   req_wstrb,
    output wire         resp_valid,
    output wire [31:0]  resp_rdata,
    output wire         resp_stall,

    output wire         mem_req_valid,
    output wire         mem_req_we,
    output wire [31:0]  mem_req_addr,
    output wire [31:0]  mem_req_wdata,
    input  wire [31:0]  mem_resp_rdata,
    input  wire         mem_resp_valid,

    output wire         hit_pulse,
    output wire         miss_pulse,
    output wire         eviction_pulse,
    output wire         dirty_eviction_pulse,
    output wire         predictor_hit_pulse,
    output wire         predictor_miss_pulse,
    output wire         stale_event_pulse
);

    localparam INDEX_BITS  = $clog2(NUM_SETS);
    localparam OFFSET_BITS = $clog2(LINE_BYTES);
    localparam TAG_BITS    = 32 - INDEX_BITS - OFFSET_BITS;
    localparam WAY_BITS    = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1;
    localparam WORDS_PER_LINE = LINE_BYTES / 4;
    localparam WORD_SEL_BITS  = (OFFSET_BITS > 2) ? (OFFSET_BITS - 2) : 1;

    localparam S_IDLE            = 3'd0;
    localparam S_LOOKUP          = 3'd1;
    localparam S_MISS_SELECT     = 3'd2;
    localparam S_WRITEBACK_REQ   = 3'd3;
    localparam S_WRITEBACK_WAIT  = 3'd4;
    localparam S_REFILL_REQ      = 3'd5;
    localparam S_REFILL_WAIT     = 3'd6;
    localparam S_RESPOND         = 3'd7;

    reg [2:0] state;

    reg [31:0] cur_req_addr;
    reg        cur_req_we;
    reg [31:0] cur_req_wdata;
    reg [3:0]  cur_req_wstrb;

    wire [INDEX_BITS-1:0] cur_index = cur_req_addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS];
    wire [TAG_BITS-1:0]   cur_tag   = cur_req_addr[31 : 32 - TAG_BITS];
    wire [WORD_SEL_BITS-1:0] cur_word_sel = cur_req_addr[OFFSET_BITS-1:2];

    reg [WAY_BITS-1:0] active_way;

    // Valid/dirty state
    reg valid_bits [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg dirty_bits [0:NUM_SETS-1][0:NUM_WAYS-1];

    // Tag/data arrays per way
    wire [TAG_BITS-1:0] tag_rd [0:NUM_WAYS-1];
    wire [31:0] data_rd [0:NUM_WAYS-1];

    reg                  tag_we_r;
    reg [INDEX_BITS-1:0] tag_index_r;
    reg [WAY_BITS-1:0] tag_way_r;
    reg [TAG_BITS-1:0]   tag_data_r;

    reg                  data_we_r;
    reg [INDEX_BITS-1:0] data_index_r;
    reg [WAY_BITS-1:0] data_way_r;
    reg [31:0]           data_wdata_r;

    reg [WORD_SEL_BITS-1:0] array_word_sel;

    genvar w;
    generate
        for (w = 0; w < NUM_WAYS; w = w + 1) begin : gen_arrays
            tag_array #(
                .NUM_SETS(NUM_SETS),
                .NUM_WAYS(NUM_WAYS),
                .TAG_BITS(TAG_BITS)
            ) tags (
                .clk(clk),
                .we(tag_we_r && (tag_way_r == w[WAY_BITS-1:0])),
                .index(tag_index_r),
                .way(w[WAY_BITS-1:0]),
                .tag_in(tag_data_r),
                .tag_out(tag_rd[w])
            );

            data_array #(
                .NUM_SETS(NUM_SETS),
                .NUM_WAYS(NUM_WAYS),
                .LINE_BYTES(LINE_BYTES)
            ) data (
                .clk(clk),
                .we(data_we_r && (data_way_r == w[WAY_BITS-1:0])),
                .index(data_index_r),
                .way(w[WAY_BITS-1:0]),
                .word_sel(array_word_sel),
                .wdata(data_wdata_r),
                .rdata(data_rd[w])
            );
        end
    endgenerate

    // Way predictor
    wire [WAY_BITS-1:0] predicted_way;
    reg predictor_update_en;
    reg [WAY_BITS-1:0] predictor_actual_way;

    way_predictor #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS)
    ) predictor (
        .clk(clk),
        .rst_n(rst_n),
        .update_en(predictor_update_en),
        .index(cur_index),
        .actual_way(predictor_actual_way),
        .predicted_way(predicted_way)
    );

    // LRU
    reg lru_update_en;
    reg [WAY_BITS-1:0] lru_access_way;
    wire [WAY_BITS-1:0] lru_victim_way;

    lru #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS)
    ) lru_inst (
        .clk(clk),
        .rst_n(rst_n),
        .access_en(lru_update_en),
        .access_index(cur_index),
        .access_way(lru_access_way),
        .victim_way(lru_victim_way)
    );

    // Stale tracker
    reg stale_access_en;
    reg [$clog2(NUM_SETS)-1:0] stale_access_index;
    reg [WAY_BITS-1:0] stale_access_way;
    wire stale_event_wire;

    stale_tracker #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS)
    ) stale (
        .clk(clk),
        .rst_n(rst_n),
        .access_en(stale_access_en),
        .access_index(stale_access_index),
        .access_way(stale_access_way),
        .tick_en(1'b1),
        .stale_threshold(4'd8),
        .stale_event(stale_event_wire)
    );

    assign stale_event_pulse = stale_event_wire;

    // Event pulses
    reg hit_pulse_r;
    reg miss_pulse_r;
    reg eviction_pulse_r;
    reg dirty_eviction_pulse_r;
    reg predictor_hit_r;
    reg predictor_miss_r;

    assign hit_pulse = hit_pulse_r;
    assign miss_pulse = miss_pulse_r;
    assign eviction_pulse = eviction_pulse_r;
    assign dirty_eviction_pulse = dirty_eviction_pulse_r;
    assign predictor_hit_pulse = predictor_hit_r;
    assign predictor_miss_pulse = predictor_miss_r;

    // Memory interface
    reg mem_req_valid_r;
    reg mem_req_we_r;
    reg [31:0] mem_req_addr_r;
    reg [31:0] mem_req_wdata_r;

    assign mem_req_valid = mem_req_valid_r;
    assign mem_req_we = mem_req_we_r;
    assign mem_req_addr = mem_req_addr_r;
    assign mem_req_wdata = mem_req_wdata_r;

    // Response
    reg resp_valid_r;
    reg [31:0] resp_rdata_r;
    assign resp_valid = resp_valid_r;
    assign resp_rdata = resp_rdata_r;
    assign resp_stall = (state != S_IDLE);

    // Miss/refill tracking
    reg [WAY_BITS-1:0] victim_way_r;
    reg [TAG_BITS-1:0] victim_tag_r;
    reg [31:0] victim_addr_r;
    reg victim_dirty_r;
    reg [$clog2(WORDS_PER_LINE):0] transfer_cnt;
    reg resp_from_fill;

    // Utility
    function [31:0] mask_from_strb;
        input [3:0] strb;
        begin
            mask_from_strb = { {8{strb[3]}}, {8{strb[2]}}, {8{strb[1]}}, {8{strb[0]}} };
        end
    endfunction

    integer si;
    integer wi;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            cur_req_addr <= 32'd0;
            cur_req_we <= 1'b0;
            cur_req_wdata <= 32'd0;
            cur_req_wstrb <= 4'd0;
            array_word_sel <= 2'd0;
            resp_valid_r <= 1'b0;
            resp_rdata_r <= 32'd0;
            tag_we_r <= 1'b0;
            data_we_r <= 1'b0;
            mem_req_valid_r <= 1'b0;
            mem_req_we_r <= 1'b0;
            mem_req_addr_r <= 32'd0;
            mem_req_wdata_r <= 32'd0;
            hit_pulse_r <= 1'b0;
            miss_pulse_r <= 1'b0;
            eviction_pulse_r <= 1'b0;
            dirty_eviction_pulse_r <= 1'b0;
            predictor_hit_r <= 1'b0;
            predictor_miss_r <= 1'b0;
            predictor_update_en <= 1'b0;
            lru_update_en <= 1'b0;
            stale_access_en <= 1'b0;
            transfer_cnt <= 0;
            victim_way_r <= 0;
            victim_tag_r <= 0;
            victim_addr_r <= 32'd0;
            victim_dirty_r <= 1'b0;
            active_way <= 0;
            resp_from_fill <= 1'b0;
            for (si = 0; si < NUM_SETS; si = si + 1) begin
                for (wi = 0; wi < NUM_WAYS; wi = wi + 1) begin
                    valid_bits[si][wi] <= 1'b0;
                    dirty_bits[si][wi] <= 1'b0;
                end
            end
        end else begin
            resp_valid_r <= 1'b0;
            tag_we_r <= 1'b0;
            data_we_r <= 1'b0;
            mem_req_valid_r <= 1'b0;
            hit_pulse_r <= 1'b0;
            miss_pulse_r <= 1'b0;
            eviction_pulse_r <= 1'b0;
            dirty_eviction_pulse_r <= 1'b0;
            predictor_hit_r <= 1'b0;
            predictor_miss_r <= 1'b0;
            predictor_update_en <= 1'b0;
            lru_update_en <= 1'b0;
            stale_access_en <= 1'b0;
            data_index_r <= cur_index;
            tag_index_r <= cur_index;

            case (state)
                S_IDLE: begin
                    if (req_valid) begin
                        cur_req_addr <= req_addr;
                        cur_req_we <= req_we;
                        cur_req_wdata <= req_wdata;
                        cur_req_wstrb <= req_wstrb;
                        array_word_sel <= req_addr[OFFSET_BITS-1:2];
                        state <= S_LOOKUP;
                    end
                end
                S_LOOKUP: begin
                    // Determine hits
                    reg hit_found;
                    reg [WAY_BITS-1:0] hit_way;
                    integer h;
                    hit_found = 1'b0;
                    hit_way = {WAY_BITS{1'b0}};
                    for (h = 0; h < NUM_WAYS; h = h + 1) begin
                        if (valid_bits[cur_index][h] && (tag_rd[h] == cur_tag)) begin
                            hit_found = 1'b1;
                            hit_way = h[WAY_BITS-1:0];
                        end
                    end

                    if (hit_found) begin
                        active_way <= hit_way;
                        predictor_update_en <= 1'b1;
                        predictor_actual_way <= hit_way;
                        if (hit_way == predicted_way) begin
                            predictor_hit_r <= 1'b1;
                        end else begin
                            predictor_miss_r <= 1'b1;
                        end
                        lru_update_en <= 1'b1;
                        lru_access_way <= hit_way;
                        stale_access_en <= 1'b1;
                        stale_access_index <= cur_index;
                        stale_access_way <= hit_way;
                        hit_pulse_r <= 1'b1;
                        if (cur_req_we) begin
                            // Update bytes
                            data_index_r <= cur_index;
                            data_way_r <= hit_way;
                            array_word_sel <= cur_word_sel;
                            data_wdata_r <= (data_rd[hit_way] & ~mask_from_strb(cur_req_wstrb)) |
                                            (cur_req_wdata & mask_from_strb(cur_req_wstrb));
                            data_we_r <= 1'b1;
                            dirty_bits[cur_index][hit_way] <= 1'b1;
                            resp_rdata_r <= 32'd0;
                        end else begin
                            resp_rdata_r <= data_rd[hit_way];
                        end
                        resp_from_fill <= 1'b0;
                        state <= S_RESPOND;
                    end else begin
                        miss_pulse_r <= 1'b1;
                        state <= S_MISS_SELECT;
                    end
                end
                S_MISS_SELECT: begin
                    reg [WAY_BITS-1:0] sel_way;
                    reg found_invalid;
                    integer inv_idx;
                    sel_way = lru_victim_way;
                    found_invalid = 1'b0;
                    for (inv_idx = 0; inv_idx < NUM_WAYS; inv_idx = inv_idx + 1) begin
                        if (!valid_bits[cur_index][inv_idx] && !found_invalid) begin
                            sel_way = inv_idx[WAY_BITS-1:0];
                            found_invalid = 1'b1;
                        end
                    end
                    victim_way_r <= sel_way;
                    victim_tag_r <= tag_rd[sel_way];
                    victim_addr_r <= {tag_rd[sel_way], cur_index, {OFFSET_BITS{1'b0}}};
                    victim_dirty_r <= valid_bits[cur_index][sel_way] && dirty_bits[cur_index][sel_way];
                    transfer_cnt <= 0;
                    if (valid_bits[cur_index][sel_way]) begin
                        eviction_pulse_r <= 1'b1;
                        if (dirty_bits[cur_index][sel_way]) begin
                            dirty_eviction_pulse_r <= 1'b1;
                        end
                    end
                    if (valid_bits[cur_index][sel_way] && dirty_bits[cur_index][sel_way]) begin
                        array_word_sel <= {WORD_SEL_BITS{1'b0}};
                        state <= S_WRITEBACK_REQ;
                    end else begin
                        array_word_sel <= {WORD_SEL_BITS{1'b0}};
                        state <= S_REFILL_REQ;
                    end
                end
                S_WRITEBACK_REQ: begin
                    array_word_sel <= transfer_cnt[WORD_SEL_BITS-1:0];
                    mem_req_valid_r <= 1'b1;
                    mem_req_we_r <= 1'b1;
                    mem_req_addr_r <= victim_addr_r + (transfer_cnt << 2);
                    mem_req_wdata_r <= data_rd[victim_way_r];
                    state <= S_WRITEBACK_WAIT;
                end
                S_WRITEBACK_WAIT: begin
                    if (mem_resp_valid) begin
                        if (transfer_cnt == WORDS_PER_LINE - 1) begin
                            transfer_cnt <= 0;
                            state <= S_REFILL_REQ;
                        end else begin
                            transfer_cnt <= transfer_cnt + 1'b1;
                            state <= S_WRITEBACK_REQ;
                        end
                    end
                end
                S_REFILL_REQ: begin
                    array_word_sel <= transfer_cnt[WORD_SEL_BITS-1:0];
                    mem_req_valid_r <= 1'b1;
                    mem_req_we_r <= 1'b0;
                    mem_req_addr_r <= {cur_req_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}} + (transfer_cnt << 2);
                    state <= S_REFILL_WAIT;
                end
                S_REFILL_WAIT: begin
                    if (mem_resp_valid) begin
                        data_index_r <= cur_index;
                        data_way_r <= victim_way_r;
                        array_word_sel <= transfer_cnt[WORD_SEL_BITS-1:0];
                        data_wdata_r <= mem_resp_rdata;
                        data_we_r <= 1'b1;
                        if (transfer_cnt == WORDS_PER_LINE - 1) begin
                            transfer_cnt <= 0;
                            tag_index_r <= cur_index;
                            tag_way_r <= victim_way_r;
                            tag_data_r <= cur_tag;
                            tag_we_r <= 1'b1;
                            valid_bits[cur_index][victim_way_r] <= 1'b1;
                            dirty_bits[cur_index][victim_way_r] <= cur_req_we;
                            active_way <= victim_way_r;
                            resp_from_fill <= 1'b1;
                            lru_update_en <= 1'b1;
                            lru_access_way <= victim_way_r;
                            stale_access_en <= 1'b1;
                            stale_access_index <= cur_index;
                            stale_access_way <= victim_way_r;
                            state <= S_RESPOND;
                            array_word_sel <= cur_word_sel;
                        end else begin
                            transfer_cnt <= transfer_cnt + 1'b1;
                            state <= S_REFILL_REQ;
                        end
                    end
                end
                S_RESPOND: begin
                    predictor_update_en <= 1'b1;
                    predictor_actual_way <= active_way;
                    if (resp_from_fill) begin
                        if (active_way == predicted_way) begin
                            predictor_hit_r <= 1'b1;
                        end else begin
                            predictor_miss_r <= 1'b1;
                        end
                    end
                    if (cur_req_we) begin
                        // Ensure latest data visible
                        array_word_sel <= cur_word_sel;
                        data_index_r <= cur_index;
                        data_way_r <= active_way;
                        data_wdata_r <= (data_rd[active_way] & ~mask_from_strb(cur_req_wstrb)) |
                                        (cur_req_wdata & mask_from_strb(cur_req_wstrb));
                        data_we_r <= 1'b1;
                        dirty_bits[cur_index][active_way] <= 1'b1;
                        resp_rdata_r <= 32'd0;
                    end else begin
                        array_word_sel <= cur_word_sel;
                        resp_rdata_r <= data_rd[active_way];
                    end
                    resp_valid_r <= 1'b1;
                    resp_from_fill <= 1'b0;
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
