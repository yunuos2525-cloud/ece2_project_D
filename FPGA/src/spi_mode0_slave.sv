`timescale 1ns/1ps

module spi_mode0_slave (
    input  wire        clk,
    input  wire        rst,
    input  wire        spi_sck,
    input  wire        spi_mosi,
    input  wire        spi_cs_n,
    output wire        spi_miso,

    output reg  [7:0]  dsp_mode,
    input  wire        block_valid,
    input  wire        block_bank,
    input  wire [15:0] block_id,
    input  wire        block_overflow,
    output reg         block_read_bank,
    output reg  [8:0]  block_read_addr,
    input  wire [7:0]  block_read_data,
    output reg         block_consume_valid,
    output reg         block_consume_bank,
    output reg         clear_overflow
);
    (* ASYNC_REG = "TRUE" *) reg [2:0] sck_sync;
    (* ASYNC_REG = "TRUE" *) reg [2:0] mosi_sync;
    (* ASYNC_REG = "TRUE" *) reg [2:0] cs_sync;
    reg sck_prev, cs_prev;
    reg [7:0] rx_shift;
    reg [7:0] tx_shift;
    reg [7:0] tx_pending;
    reg tx_pending_valid;
    reg [2:0] bit_count;
    reg command_seen;
    reg read_active;
    reg read_complete;
    reg read_has_block;
    reg [15:0] read_id;
    reg [9:0] response_pos;
    reg [7:0] crc_reg;

    wire sck_rise = sck_sync[2] && !sck_prev;
    wire sck_fall = !sck_sync[2] && sck_prev;
    wire cs_rise = cs_sync[2] && !cs_prev;
    wire cs_selected = !cs_sync[2];
    wire [7:0] received_byte = {rx_shift[6:0], mosi_sync[2]};

    assign spi_miso = cs_selected ? tx_shift[7] : 1'b0;

    function automatic [7:0] crc8_atm;
        input [7:0] crc_in;
        input [7:0] data;
        integer k;
        reg [7:0] c;
        begin
            c = crc_in ^ data;
            for (k = 0; k < 8; k = k + 1)
                c = c[7] ? ((c << 1) ^ 8'h07) : (c << 1);
            crc8_atm = c;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            sck_sync <= 3'b000;
            mosi_sync <= 3'b000;
            cs_sync <= 3'b111;
            sck_prev <= 1'b0;
            cs_prev <= 1'b1;
            rx_shift <= 8'h00;
            tx_shift <= 8'h00;
            tx_pending <= 8'h00;
            tx_pending_valid <= 1'b0;
            bit_count <= 3'd0;
            command_seen <= 1'b0;
            read_active <= 1'b0;
            read_complete <= 1'b0;
            read_has_block <= 1'b0;
            read_id <= 16'h0000;
            response_pos <= 10'd0;
            crc_reg <= 8'h00;
            dsp_mode <= 8'h01;
            block_read_bank <= 1'b0;
            block_read_addr <= 9'd0;
            block_consume_valid <= 1'b0;
            block_consume_bank <= 1'b0;
            clear_overflow <= 1'b0;
        end else begin
            sck_sync <= {sck_sync[1:0], spi_sck};
            mosi_sync <= {mosi_sync[1:0], spi_mosi};
            cs_sync <= {cs_sync[1:0], spi_cs_n};
            sck_prev <= sck_sync[2];
            cs_prev <= cs_sync[2];
            block_consume_valid <= 1'b0;
            clear_overflow <= 1'b0;

            if (cs_rise) begin
                if (read_active && read_complete && read_has_block) begin
                    block_consume_valid <= 1'b1;
                    block_consume_bank <= block_read_bank;
                end
                bit_count <= 3'd0;
                rx_shift <= 8'h00;
                tx_shift <= 8'h00;
                tx_pending_valid <= 1'b0;
                command_seen <= 1'b0;
                read_active <= 1'b0;
                read_complete <= 1'b0;
                read_has_block <= 1'b0;
            end else if (cs_selected) begin
                if (sck_fall) begin
                    if (bit_count != 3'd0)
                        tx_shift <= {tx_shift[6:0], 1'b0};
                    else if (tx_pending_valid) begin
                        tx_shift <= tx_pending;
                        tx_pending_valid <= 1'b0;
                    end
                end

                if (sck_rise) begin
                    rx_shift <= received_byte;
                    if (bit_count == 3'd7) begin
                        bit_count <= 3'd0;
                        if (!command_seen) begin
                            command_seen <= 1'b1;
                            case (received_byte)
                                8'h01: dsp_mode <= 8'h01;
                                8'h02: dsp_mode <= 8'h02;
                                8'h06: dsp_mode <= 8'h06;
                                8'h05: clear_overflow <= 1'b1;
                                8'h10: begin
                                    read_active <= 1'b1;
                                    read_has_block <= block_valid;
                                    block_read_bank <= block_bank;
                                    block_read_addr <= 9'd0;
                                    read_id <= block_id;
                                    response_pos <= 10'd0;
                                    crc_reg <= 8'h00;
                                    tx_pending <= {6'b000000, block_overflow, block_valid};
                                    tx_pending_valid <= 1'b1;
                                end
                                default: ;
                            endcase
                        end else if (read_active && read_has_block && !read_complete) begin
                            case (response_pos)
                                10'd0: begin
                                    tx_pending <= read_id[7:0];
                                    tx_pending_valid <= 1'b1;
                                    crc_reg <= crc8_atm(8'h00, read_id[7:0]);
                                    response_pos <= 10'd1;
                                end
                                10'd1: begin
                                    tx_pending <= read_id[15:8];
                                    tx_pending_valid <= 1'b1;
                                    crc_reg <= crc8_atm(crc_reg, read_id[15:8]);
                                    response_pos <= 10'd2;
                                end
                                10'd2: begin
                                    tx_pending <= block_read_data;
                                    tx_pending_valid <= 1'b1;
                                    crc_reg <= crc8_atm(crc_reg, block_read_data);
                                    block_read_addr <= 9'd1;
                                    response_pos <= 10'd3;
                                end
                                10'd514: begin
                                    tx_pending <= crc_reg;
                                    tx_pending_valid <= 1'b1;
                                    response_pos <= 10'd515;
                                end
                                10'd515: begin
                                    tx_pending <= 8'h00;
                                    tx_pending_valid <= 1'b1;
                                    read_complete <= 1'b1;
                                end
                                default: begin
                                    // Positions 3..513 load samples 1..511.
                                    tx_pending <= block_read_data;
                                    tx_pending_valid <= 1'b1;
                                    crc_reg <= crc8_atm(crc_reg, block_read_data);
                                    block_read_addr <= block_read_addr + 1'b1;
                                    response_pos <= response_pos + 1'b1;
                                end
                            endcase
                        end
                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end
            end
        end
    end
endmodule
