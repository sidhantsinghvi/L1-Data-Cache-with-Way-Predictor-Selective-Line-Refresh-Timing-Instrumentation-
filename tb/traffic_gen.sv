module traffic_gen(
    input  logic        clk,
    input  logic        rst_n,
    output logic        req_valid,
    output logic        req_we,
    output logic [31:0] req_addr,
    output logic [31:0] req_wdata,
    output logic [3:0]  req_wstrb,
    input  logic        resp_stall,
    input  logic        resp_valid,
    input  logic [31:0] resp_rdata
);

    typedef enum logic [1:0] {
        PH_DIRECTED,
        PH_RANDOM,
        PH_STALE,
        PH_DONE
    } phase_e;

    phase_e phase;
    logic [3:0] directed_cnt;
    logic [7:0] random_cnt;
    logic [5:0] stale_prep_cnt;
    logic [7:0] stale_idle_cnt;
    logic [31:0] lfsr;
    logic pending;

    localparam BASE_ADDR = 32'h0000_1000;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= PH_DIRECTED;
            directed_cnt <= 4'd0;
            random_cnt <= 8'd0;
            stale_prep_cnt <= 6'd0;
            stale_idle_cnt <= 8'd0;
            lfsr <= 32'h1ACE_D00D;
            pending <= 1'b0;
        end else begin
            if (req_valid && !resp_stall) begin
                pending <= 1'b1;
            end else if (resp_valid) begin
                pending <= 1'b0;
            end

            if (phase == PH_DIRECTED && !pending && !resp_stall && req_valid && (directed_cnt == 4'd7)) begin
                phase <= PH_RANDOM;
            end else if (phase == PH_RANDOM && random_cnt == 8'd63 && !pending && !resp_stall && req_valid) begin
                phase <= PH_STALE;
            end else if (phase == PH_STALE && stale_idle_cnt == 8'd80) begin
                phase <= PH_DONE;
            end

            if (phase == PH_DIRECTED && req_valid && !resp_stall) begin
                directed_cnt <= directed_cnt + 1'b1;
            end

            if (phase == PH_RANDOM && req_valid && !resp_stall) begin
                random_cnt <= random_cnt + 1'b1;
                lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            end

            if (phase == PH_STALE) begin
                if (stale_prep_cnt < 6'd4 && req_valid && !resp_stall) begin
                    stale_prep_cnt <= stale_prep_cnt + 1'b1;
                end else if (stale_prep_cnt == 6'd4 && stale_idle_cnt != 8'd80) begin
                    stale_idle_cnt <= stale_idle_cnt + 1'b1;
                end
            end
        end
    end

    always_comb begin
        req_valid = 1'b0;
        req_we = 1'b0;
        req_addr = 32'd0;
        req_wdata = 32'd0;
        req_wstrb = 4'd0;

        unique case (phase)
            PH_DIRECTED: begin
                req_we = (directed_cnt < 4);
                req_addr = BASE_ADDR | (directed_cnt[1:0] << 4);
                req_wdata = 32'hA5A50000 | directed_cnt;
                req_wstrb = 4'hF;
                req_valid = ~pending;
            end
            PH_RANDOM: begin
                req_we = lfsr[0];
                req_addr = {BASE_ADDR[31:12], lfsr[11:0], 4'd0};
                req_wdata = {lfsr[15:0], lfsr[31:16]};
                req_wstrb = req_we ? 4'hF : 4'h0;
                req_valid = ~pending;
            end
            PH_STALE: begin
                if (stale_prep_cnt < 4) begin
                    req_we = 1'b0;
                    req_addr = BASE_ADDR + (stale_prep_cnt << 6);
                    req_wstrb = 4'h0;
                    req_valid = ~pending;
                end else begin
                    req_valid = 1'b0; // stay idle to trigger stale tracker
                end
            end
            default: begin
                req_valid = 1'b0;
            end
        endcase
    end

    // Simple monitors for debugging
    always_ff @(posedge clk) begin
        if (resp_valid) begin
            $display("[traffic_gen] resp data: %h", resp_rdata);
        end
    end

endmodule
