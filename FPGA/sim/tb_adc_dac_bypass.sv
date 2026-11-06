`timescale 1ns/1ps

module tb_adc_dac_bypass;
    reg clk_50mhz=0,rst_p=1;
    reg [2:0] adc_channel=0;
    reg adc_dout=0,spi_sck=0,spi_mosi=0,spi_cs_n=1;
    wire adc_sclk,adc_ncs,adc_din,dac_a_b,dac_csn,dac_ldacn,dac_wen,spi_miso;
    wire [7:0] dac_d,led_out;
    integer response_index=0,response_bit=15,write_count=0;
    reg [15:0] response_word;
    reg [7:0] expected[0:2];
    always #10 clk_50mhz=~clk_50mhz;

    w1_board_top dut(.*);

    function automatic [7:0] response_sample;
        input integer index;
        begin
            case(index)
                0: response_sample=8'h00;
                1: response_sample=8'h12;
                2: response_sample=8'hA5;
                default: response_sample=8'h7E;
            endcase
        end
    endfunction
    always @(negedge adc_ncs) begin
        response_word={1'b0,adc_channel,response_sample(response_index),4'b0000};
        response_bit=15; adc_dout=response_word[15]; response_index=response_index+1;
    end
    always @(posedge adc_sclk) begin
        if(!adc_ncs && response_bit>0) begin
            response_bit=response_bit-1; adc_dout=response_word[response_bit];
        end
    end
    always @(negedge dac_wen) begin
        if(write_count<3) begin
            if(dac_d!==expected[write_count])
                $fatal(1,"FAIL ADC_DAC_BYPASS sample %0d got=%02x expected=%02x",write_count,dac_d,expected[write_count]);
            if(dac_csn!==0 || dac_ldacn!==0 || dac_a_b!==0)
                $fatal(1,"FAIL ADC_DAC_BYPASS DAC controls");
            write_count=write_count+1;
        end
    end
    initial begin
        expected[0]=8'h12; expected[1]=8'hA5; expected[2]=8'h7E;
        $dumpfile("project_evidence/fpga/W1/sim/tb_adc_dac_bypass.vcd");
        $dumpvars(0,tb_adc_dac_bypass);
        repeat(5) @(posedge clk_50mhz); rst_p=0;
        wait(write_count==3);
        if(dut.adc_drop_sticky) $fatal(1,"FAIL ADC_DAC_BYPASS sample drop");
        $display("PASS ADC_DAC_BYPASS: modeled AD7908 replies preserved through DAC writes");
        $finish;
    end
    initial begin
        #400000; $fatal(1,"FAIL ADC_DAC_BYPASS timeout writes=%0d",write_count);
    end
endmodule
