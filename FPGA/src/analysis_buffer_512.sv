`timescale 1ns/1ps

module analysis_buffer_512 (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_valid,
    input  wire [7:0]  sample_data,
    input  wire        clear_overflow,
    output reg         overflow_sticky,

    output reg         selected_valid,
    output reg         selected_bank,
    output reg  [15:0] selected_id,
    input  wire        read_bank,
    input  wire [8:0]  read_addr,
    output reg  [7:0]  read_data,
    input  wire        consume_valid,
    input  wire        consume_bank,

    output wire [1:0]  ready_debug
);
    reg [7:0] mem0 [0:511];
    reg [7:0] mem1 [0:511];
    reg ready0, ready1;
    reg [15:0] id0, id1;
    reg [15:0] next_id;
    reg wr_bank;
    reg [8:0] wr_addr;
    reg capturing;
    wire [15:0] id_diff = id1 - id0;

    assign ready_debug = {ready1, ready0};

    always @* begin
        if (read_bank)
            read_data = mem1[read_addr];
        else
            read_data = mem0[read_addr];

        selected_valid = ready0 | ready1;
        if (ready0 && ready1) begin
            // At most adjacent queued blocks exist. Modular subtraction keeps
            // the ordering correct across the 16-bit ID wrap.
            selected_bank = !((id_diff != 16'h0000) && (id_diff < 16'h8000));
        end else begin
            selected_bank = ready1;
        end
        selected_id = selected_bank ? id1 : id0;
    end

    always @(posedge clk) begin
        if (rst) begin
            ready0 <= 1'b0;
            ready1 <= 1'b0;
            id0 <= 16'h0000;
            id1 <= 16'h0000;
            next_id <= 16'h0000;
            wr_bank <= 1'b0;
            wr_addr <= 9'd0;
            capturing <= 1'b1;
            overflow_sticky <= 1'b0;
        end else begin
            if (clear_overflow)
                overflow_sticky <= 1'b0;

            if (consume_valid) begin
                if (consume_bank)
                    ready1 <= 1'b0;
                else
                    ready0 <= 1'b0;
            end

            if (sample_valid) begin
                if (capturing) begin
                    if (wr_bank)
                        mem1[wr_addr] <= sample_data;
                    else
                        mem0[wr_addr] <= sample_data;

                    if (wr_addr == 9'd511) begin
                        if (wr_bank) begin
                            ready1 <= 1'b1;
                            id1 <= next_id;
                        end else begin
                            ready0 <= 1'b1;
                            id0 <= next_id;
                        end
                        next_id <= next_id + 1'b1;
                        wr_addr <= 9'd0;

                        if (wr_bank) begin
                            if (!ready0 || (consume_valid && !consume_bank)) begin
                                wr_bank <= 1'b0;
                            end else begin
                                capturing <= 1'b0;
                                overflow_sticky <= 1'b1;
                            end
                        end else begin
                            if (!ready1 || (consume_valid && consume_bank)) begin
                                wr_bank <= 1'b1;
                            end else begin
                                capturing <= 1'b0;
                                overflow_sticky <= 1'b1;
                            end
                        end
                    end else begin
                        wr_addr <= wr_addr + 1'b1;
                    end
                end else if (!ready0 || (consume_valid && !consume_bank)) begin
                    mem0[0] <= sample_data;
                    wr_bank <= 1'b0;
                    wr_addr <= 9'd1;
                    capturing <= 1'b1;
                end else if (!ready1 || (consume_valid && consume_bank)) begin
                    mem1[0] <= sample_data;
                    wr_bank <= 1'b1;
                    wr_addr <= 9'd1;
                    capturing <= 1'b1;
                end else begin
                    overflow_sticky <= 1'b1;
                end
            end
        end
    end
endmodule
