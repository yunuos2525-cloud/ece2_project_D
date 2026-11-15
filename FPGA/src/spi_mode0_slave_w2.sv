`timescale 1ns/1ps

// W2 extension of the W1 oversampled Mode-0 slave. SET_COEFF is accepted
// only after CS rises with exactly 13 bytes and a valid CRC. READ_STATE
// reports coefficients after the audio path has applied them at a sample edge.
module spi_mode0_slave_w2 (
    input  wire        clk,
    input  wire        rst,
    input  wire        spi_sck,
    input  wire        spi_mosi,
    input  wire        spi_cs_n,
    output wire        spi_miso,

    output reg  [7:0]  dsp_mode,
    output reg         coeff_update_valid,
    output reg  [7:0]  coeff_update_seq,
    output reg signed [15:0] coeff_b0,
    output reg signed [15:0] coeff_b1,
    output reg signed [15:0] coeff_b2,
    output reg signed [15:0] coeff_a1,
    output reg signed [15:0] coeff_a2,
    input  wire        auto_coeff_valid,
    input  wire [7:0]  applied_coeff_seq,

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
    reg [7:0] rx_shift, tx_shift, tx_pending;
    reg tx_pending_valid;
    reg [2:0] bit_count;
    reg command_seen;
    reg read_active, read_complete, read_has_block;
    reg state_active;
    reg [15:0] read_id;
    reg [9:0] response_pos;
    reg [7:0] crc_reg;

    reg set_active;
    reg [3:0] set_count;
    reg [7:0] set_crc, set_received_crc, set_seq;
    reg signed [15:0] set_b0, set_b1, set_b2, set_a1, set_a2;
    reg [7:0] state_seq, state_flags;

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
            for (k=0; k<8; k=k+1)
                c = c[7] ? ((c << 1) ^ 8'h07) : (c << 1);
            crc8_atm = c;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            sck_sync <= 0; mosi_sync <= 0; cs_sync <= 3'b111;
            sck_prev <= 0; cs_prev <= 1;
            rx_shift <= 0; tx_shift <= 0; tx_pending <= 0;
            tx_pending_valid <= 0; bit_count <= 0; command_seen <= 0;
            read_active <= 0; read_complete <= 0; read_has_block <= 0;
            state_active <= 0; read_id <= 0; response_pos <= 0; crc_reg <= 0;
            set_active <= 0; set_count <= 0; set_crc <= 0;
            set_received_crc <= 0; set_seq <= 0;
            set_b0 <= 0; set_b1 <= 0; set_b2 <= 0; set_a1 <= 0; set_a2 <= 0;
            state_seq <= 8'hff; state_flags <= 0;
            dsp_mode <= 8'h01;
            coeff_update_valid <= 0; coeff_update_seq <= 0;
            coeff_b0 <= 0; coeff_b1 <= 0; coeff_b2 <= 0; coeff_a1 <= 0; coeff_a2 <= 0;
            block_read_bank <= 0; block_read_addr <= 0;
            block_consume_valid <= 0; block_consume_bank <= 0;
            clear_overflow <= 0;
        end else begin
            sck_sync <= {sck_sync[1:0], spi_sck};
            mosi_sync <= {mosi_sync[1:0], spi_mosi};
            cs_sync <= {cs_sync[1:0], spi_cs_n};
            sck_prev <= sck_sync[2];
            cs_prev <= cs_sync[2];
            block_consume_valid <= 0;
            clear_overflow <= 0;
            coeff_update_valid <= 0;

            if (cs_rise) begin
                if (read_active && read_complete && read_has_block) begin
                    block_consume_valid <= 1;
                    block_consume_bank <= block_read_bank;
                end
                if (set_active && (set_count == 12) && (set_received_crc == set_crc)) begin
                    coeff_update_valid <= 1;
                    coeff_update_seq <= set_seq;
                    coeff_b0 <= set_b0; coeff_b1 <= set_b1; coeff_b2 <= set_b2;
                    coeff_a1 <= set_a1; coeff_a2 <= set_a2;
                end
                bit_count <= 0; rx_shift <= 0; tx_shift <= 0;
                tx_pending_valid <= 0; command_seen <= 0;
                read_active <= 0; read_complete <= 0; read_has_block <= 0;
                state_active <= 0; set_active <= 0; set_count <= 0;
            end else if (cs_selected) begin
                if (sck_fall) begin
                    if (bit_count != 0)
                        tx_shift <= {tx_shift[6:0],1'b0};
                    else if (tx_pending_valid) begin
                        tx_shift <= tx_pending;
                        tx_pending_valid <= 0;
                    end
                end

                if (sck_rise) begin
                    rx_shift <= received_byte;
                    if (bit_count == 7) begin
                        bit_count <= 0;
                        if (!command_seen) begin
                            command_seen <= 1;
                            case (received_byte)
                                8'h01: dsp_mode <= 8'h01;
                                8'h02: dsp_mode <= 8'h02;
                                8'h06: dsp_mode <= 8'h06;
                                8'h05: clear_overflow <= 1;
                                8'h10: begin
                                    read_active <= 1; read_has_block <= block_valid;
                                    block_read_bank <= block_bank; block_read_addr <= 0;
                                    read_id <= block_id; response_pos <= 0; crc_reg <= 0;
                                    tx_pending <= {6'b0,block_overflow,block_valid};
                                    tx_pending_valid <= 1;
                                end
                                8'h20: begin
                                    set_active <= 1; set_count <= 0; set_crc <= 0;
                                end
                                8'h21: begin
                                    state_active <= 1; response_pos <= 0;
                                    state_seq <= auto_coeff_valid ? applied_coeff_seq : 8'hff;
                                    state_flags <= {6'b0,block_overflow,auto_coeff_valid};
                                    tx_pending <= dsp_mode; tx_pending_valid <= 1;
                                end
                                default: ;
                            endcase
                        end else if (set_active) begin
                            case (set_count)
                                0: begin set_seq <= received_byte; set_crc <= crc8_atm(0,received_byte); end
                                1: begin set_b0[7:0] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                2: begin set_b0[15:8] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                3: begin set_b1[7:0] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                4: begin set_b1[15:8] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                5: begin set_b2[7:0] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                6: begin set_b2[15:8] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                7: begin set_a1[7:0] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                8: begin set_a1[15:8] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                9: begin set_a2[7:0] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                10: begin set_a2[15:8] <= received_byte; set_crc <= crc8_atm(set_crc,received_byte); end
                                11: set_received_crc <= received_byte;
                                default: ;
                            endcase
                            if (set_count < 13) set_count <= set_count + 1'b1;
                        end else if (state_active) begin
                            case (response_pos)
                                0: begin tx_pending <= state_seq; tx_pending_valid <= 1; response_pos <= 1; end
                                1: begin tx_pending <= state_flags; tx_pending_valid <= 1; response_pos <= 2; end
                                default: begin tx_pending <= 0; tx_pending_valid <= 1; end
                            endcase
                        end else if (read_active && read_has_block && !read_complete) begin
                            case (response_pos)
                                0: begin
                                    tx_pending <= read_id[7:0]; tx_pending_valid <= 1;
                                    crc_reg <= crc8_atm(0,read_id[7:0]); response_pos <= 1;
                                end
                                1: begin
                                    tx_pending <= read_id[15:8]; tx_pending_valid <= 1;
                                    crc_reg <= crc8_atm(crc_reg,read_id[15:8]); response_pos <= 2;
                                end
                                2: begin
                                    tx_pending <= block_read_data; tx_pending_valid <= 1;
                                    crc_reg <= crc8_atm(crc_reg,block_read_data);
                                    block_read_addr <= 1; response_pos <= 3;
                                end
                                514: begin tx_pending <= crc_reg; tx_pending_valid <= 1; response_pos <= 515; end
                                515: begin tx_pending <= 0; tx_pending_valid <= 1; read_complete <= 1; end
                                default: begin
                                    tx_pending <= block_read_data; tx_pending_valid <= 1;
                                    crc_reg <= crc8_atm(crc_reg,block_read_data);
                                    block_read_addr <= block_read_addr + 1'b1;
                                    response_pos <= response_pos + 1'b1;
                                end
                            endcase
                        end
                    end else bit_count <= bit_count + 1'b1;
                end
            end
        end
    end
endmodule
