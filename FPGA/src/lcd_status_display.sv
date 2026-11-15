`timescale 1ns/1ps

// 16x2 HD44780-compatible, 8-bit write-only display controller. Values are
// snapshotted at the start of each refresh so a line never mixes two seconds.
module lcd_status_display #(
    parameter integer TICK_CYCLES = 500,
    parameter integer POWER_TICKS = 2_000,
    parameter integer NORMAL_WAIT_TICKS = 4,
    parameter integer CLEAR_WAIT_TICKS = 200
) (
    input wire clk, rst,
    input wire [1:0] display_mode,
    input wire [7:0] dsp_mode,
    input wire auto_coeff_valid,
    input wire [7:0] applied_coeff_seq,
    input wire block_overflow,
    input wire [13:0] year,
    input wire [3:0] month,
    input wire [5:0] day,
    input wire [2:0] weekday,
    input wire [4:0] hour,
    input wire [5:0] minute, second,
    input wire sw_running,
    input wire [6:0] sw_hours,
    input wire [5:0] sw_minutes, sw_seconds,
    input wire [6:0] sw_centiseconds,
    output reg lcd_e,
    output reg lcd_rs,
    output wire lcd_rw,
    output reg [7:0] lcd_data
);
    localparam integer TICK_W = (TICK_CYCLES < 2) ? 1 : $clog2(TICK_CYCLES);
    reg [TICK_W-1:0] tick_count;
    reg tick;
    reg [1:0] phase, shown_mode;
    reg [5:0] index;
    integer wait_count, power_count;
    reg byte_rs;
    reg [7:0] byte_data;
    reg [7:0] s_dsp_mode, s_seq;
    reg s_coeff_valid, s_overflow, s_sw_running;
    reg [13:0] s_year;
    reg [3:0] s_month;
    reg [5:0] s_day, s_minute, s_second, s_sw_minutes, s_sw_seconds;
    reg [2:0] s_weekday;
    reg [4:0] s_hour;
    reg [6:0] s_sw_hours, s_sw_centiseconds;
    assign lcd_rw = 1'b0;

    function automatic [7:0] digit;
        input integer value;
        begin digit = 8'h30 + (value % 10); end
    endfunction
    function automatic [7:0] hex_digit;
        input [3:0] value;
        begin hex_digit = (value < 10) ? (8'h30 + value) : (8'h41 + value - 10); end
    endfunction
    function automatic [7:0] line1_char;
        input [1:0] mode;
        input integer p;
        begin
            line1_char = " ";
            case (mode)
                0: begin
                    case (p)
                        0:line1_char="D"; 1:line1_char="S"; 2:line1_char="P"; 3:line1_char=":";
                        4:line1_char=" ";
                        5: if (s_dsp_mode==8'h01) line1_char="B"; else if(s_dsp_mode==8'h02) line1_char="F"; else line1_char="A";
                        6: if (s_dsp_mode==8'h01) line1_char="Y"; else if(s_dsp_mode==8'h02) line1_char="I"; else line1_char="U";
                        7: if (s_dsp_mode==8'h01) line1_char="P"; else if(s_dsp_mode==8'h02) line1_char="X"; else line1_char="T";
                        8: if (s_dsp_mode==8'h01) line1_char="A"; else if(s_dsp_mode==8'h02) line1_char="E"; else line1_char="O";
                        9: if (s_dsp_mode==8'h01) line1_char="S"; else if(s_dsp_mode==8'h02) line1_char="D"; else line1_char=" ";
                        10:if (s_dsp_mode==8'h01) line1_char="S";
                        default: line1_char=" ";
                    endcase
                end
                1: begin
                    case (p)
                        0:line1_char=digit(s_year/1000); 1:line1_char=digit(s_year/100);
                        2:line1_char=digit(s_year/10); 3:line1_char=digit(s_year);
                        4:line1_char="-"; 5:line1_char=digit(s_month/10); 6:line1_char=digit(s_month);
                        7:line1_char="-"; 8:line1_char=digit(s_day/10); 9:line1_char=digit(s_day);
                        10:line1_char=" "; 11:line1_char="D"; 12:line1_char=digit(s_weekday);
                        default:line1_char=" ";
                    endcase
                end
                default: begin
                    case (p)
                        0:line1_char="S";1:line1_char="T";2:line1_char="O";3:line1_char="P";
                        4:line1_char="W";5:line1_char="A";6:line1_char="T";7:line1_char="C";
                        8:line1_char="H";9:line1_char=" ";
                        10:line1_char=s_sw_running?"R":"S";
                        11:line1_char=s_sw_running?"U":"T";
                        12:line1_char=s_sw_running?"N":"O";
                        13:line1_char=s_sw_running?" ":"P";
                        default:line1_char=" ";
                    endcase
                end
            endcase
        end
    endfunction
    function automatic [7:0] line2_char;
        input [1:0] mode;
        input integer p;
        begin
            line2_char = " ";
            case (mode)
                0: begin
                    case (p)
                        0:line2_char="S";1:line2_char="E";2:line2_char="Q";3:line2_char=":";
                        4:line2_char=hex_digit(s_seq[7:4]);5:line2_char=hex_digit(s_seq[3:0]);
                        7:line2_char="V";8:line2_char=":";9:line2_char=s_coeff_valid?"1":"0";
                        11:line2_char="L";12:line2_char=":";13:line2_char=s_overflow?"1":"0";
                        default:line2_char=" ";
                    endcase
                end
                1: begin
                    case (p)
                        0:line2_char=digit(s_hour/10);1:line2_char=digit(s_hour);2:line2_char=":";
                        3:line2_char=digit(s_minute/10);4:line2_char=digit(s_minute);5:line2_char=":";
                        6:line2_char=digit(s_second/10);7:line2_char=digit(s_second);
                        default:line2_char=" ";
                    endcase
                end
                default: begin
                    case (p)
                        0:line2_char=digit(s_sw_hours/10);1:line2_char=digit(s_sw_hours);2:line2_char=":";
                        3:line2_char=digit(s_sw_minutes/10);4:line2_char=digit(s_sw_minutes);5:line2_char=":";
                        6:line2_char=digit(s_sw_seconds/10);7:line2_char=digit(s_sw_seconds);8:line2_char=".";
                        9:line2_char=digit(s_sw_centiseconds/10);10:line2_char=digit(s_sw_centiseconds);
                        default:line2_char=" ";
                    endcase
                end
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin tick_count<=0; tick<=0; end
        else if (tick_count == TICK_CYCLES-1) begin tick_count<=0; tick<=1; end
        else begin tick_count<=tick_count+1'b1; tick<=0; end
    end

    always @* begin
        byte_rs = 0; byte_data = 0;
        case (index)
            0,1,2: byte_data=8'h38;
            3: byte_data=8'h0c;
            4: byte_data=8'h06;
            5: byte_data=8'h01;
            6: byte_data=8'h80;
            23: byte_data=8'hc0;
            default: begin
                byte_rs=1;
                if(index>=7 && index<=22) byte_data=line1_char(shown_mode,index-7);
                else if(index>=24 && index<=39) byte_data=line2_char(shown_mode,index-24);
                else byte_data=" ";
            end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            lcd_e<=0; lcd_rs<=0; lcd_data<=0; phase<=0; index<=0;
            wait_count<=0; power_count<=0; shown_mode<=0;
            s_dsp_mode<=8'h01; s_seq<=8'hff; s_coeff_valid<=0; s_overflow<=0;
            s_year<=2026; s_month<=1; s_day<=1; s_weekday<=4;
            s_hour<=0; s_minute<=0; s_second<=0; s_sw_running<=0;
            s_sw_hours<=0; s_sw_minutes<=0; s_sw_seconds<=0; s_sw_centiseconds<=0;
        end else if (tick) begin
            if (power_count < POWER_TICKS) begin power_count<=power_count+1; lcd_e<=0; end
            else case (phase)
                0: begin
                    if(index==6) begin
                        shown_mode<=display_mode; s_dsp_mode<=dsp_mode;
                        s_seq<=applied_coeff_seq; s_coeff_valid<=auto_coeff_valid;
                        s_overflow<=block_overflow; s_year<=year; s_month<=month;
                        s_day<=day; s_weekday<=weekday; s_hour<=hour;
                        s_minute<=minute; s_second<=second; s_sw_running<=sw_running;
                        s_sw_hours<=sw_hours; s_sw_minutes<=sw_minutes;
                        s_sw_seconds<=sw_seconds; s_sw_centiseconds<=sw_centiseconds;
                    end
                    lcd_e<=0; lcd_rs<=byte_rs; lcd_data<=byte_data; phase<=1;
                end
                1: begin lcd_e<=1; phase<=2; end
                2: begin lcd_e<=0; wait_count<=(index==5)?CLEAR_WAIT_TICKS:NORMAL_WAIT_TICKS; phase<=3; end
                default: begin
                    if(wait_count>0) wait_count<=wait_count-1;
                    else begin index<=(index==39)?6:index+1'b1; phase<=0; end
                end
            endcase
        end
    end
endmodule
