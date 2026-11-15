`timescale 1ns/1ps
module tb_iir_notch_variable;
    reg clk=0,rst=1,sample_valid=0,update=0;
    reg [7:0] sample_in=128,seq=0;
    reg signed [15:0] b0,b1,b2,a1,a2;
    wire coeff_valid,applied,sample_out_valid;
    wire [7:0] applied_seq,sample_out;
    integer n,iv,minv,maxv;
    real pi,w,r,k,c,s,sumc,sums,amp,db;
    always #5 clk=~clk;
    iir_notch_variable dut(.clk(clk),.rst(rst),.sample_valid(sample_valid),.sample_in(sample_in),
        .coeff_update_valid(update),.coeff_update_seq(seq),.coeff_b0(b0),.coeff_b1(b1),
        .coeff_b2(b2),.coeff_a1(a1),.coeff_a2(a2),.coeff_valid(coeff_valid),
        .applied_seq(applied_seq),.coeff_applied(applied),.sample_out_valid(sample_out_valid),.sample_out(sample_out));

    task automatic set_coeff;
        input integer f;
        input integer seq_value;
        begin
            pi=3.141592653589793; r=0.95; w=2.0*pi*f/16000.0;
            k=(1.0-2.0*r*$cos(w)+r*r)/(2.0-2.0*$cos(w));
            b0=$rtoi(k*16384.0 + 0.5);
            b1=$rtoi(-2.0*k*$cos(w)*16384.0 - 0.5);
            b2=b0;
            a1=$rtoi(-2.0*r*$cos(w)*16384.0 - 0.5);
            a2=$rtoi(r*r*16384.0 + 0.5);
            seq=seq_value[7:0];
            @(negedge clk); update=1;
            @(negedge clk); update=0;
            if(coeff_valid) $fatal(1,"FAIL VARIABLE coefficient applied before sample edge");
            @(negedge clk); sample_in=128; sample_valid=1;
            @(posedge clk); #1;
            if(!applied || !coeff_valid || applied_seq!==seq_value[7:0])
                $fatal(1,"FAIL VARIABLE atomic apply seq=%02x valid=%b",applied_seq,coeff_valid);
            @(negedge clk); sample_valid=0;
        end
    endtask
    task automatic measure_tone;
        input integer f;
        input integer count;
        begin
            sumc=0.0; sums=0.0; minv=255; maxv=0;
            for(n=0;n<512+count;n=n+1) begin
                @(negedge clk);
                iv=$rtoi(128.0+40.0*$sin(2.0*pi*f*n/16000.0));
                sample_in=iv[7:0]; sample_valid=1;
                @(posedge clk); #1;
                if(!sample_out_valid) $fatal(1,"FAIL VARIABLE missing output n=%0d",n);
                if(n>=512) begin
                    if(sample_out<minv)minv=sample_out;
                    if(sample_out>maxv)maxv=sample_out;
                    sumc=sumc+($itor(sample_out)-128.0)*$cos(2.0*pi*f*n/16000.0);
                    sums=sums+($itor(sample_out)-128.0)*$sin(2.0*pi*f*n/16000.0);
                end
            end
            @(negedge clk); sample_valid=0;
            amp=2.0*$sqrt(sumc*sumc+sums*sums)/count;
            if(amp<0.0001) db=-120.0; else db=20.0*$ln(amp/40.0)/$ln(10.0);
            $display("METRIC VARIABLE tone=%0d min=%0d max=%0d amp=%0.3f",f,minv,maxv,amp);
        end
    endtask
    task automatic test_frequency;
        input integer f;
        input integer seq_value;
        begin
            @(negedge clk); rst=1; repeat(3) @(negedge clk); rst=0;
            set_coeff(f,seq_value);
            measure_tone(f,4096);
            $display("METRIC VARIABLE target=%0dHz attenuation_db=%0.3f",f,db);
            if(db>-10.0) $fatal(1,"FAIL VARIABLE target attenuation f=%0d db=%0.3f",f,db);
            @(negedge clk); rst=1; repeat(3) @(negedge clk); rst=0;
            set_coeff(f,seq_value);
            measure_tone(500,4096);
            $display("METRIC VARIABLE target=%0dHz pass500_db=%0.3f",f,db);
            if(db>1.0 || db< -1.0) $fatal(1,"FAIL VARIABLE 500Hz preservation f=%0d db=%0.3f",f,db);
        end
    endtask
    initial begin
        $dumpfile("project_evidence/fpga/W2/pre/dsp/tb_iir_notch_variable.vcd");
        $dumpvars(0,tb_iir_notch_variable);
        repeat(4) @(negedge clk); rst=0;
        test_frequency(930,8'h10); test_frequency(1370,8'h11);
        test_frequency(1830,8'h12); test_frequency(2460,8'h13);
        @(negedge clk);rst=1;repeat(3)@(negedge clk);rst=0;
        b0=16'sh7fff;b1=0;b2=0;a1=0;a2=0;seq=8'h20;
        @(negedge clk);update=1;@(negedge clk);update=0;
        @(negedge clk);sample_in=8'hff;sample_valid=1;
        @(posedge clk);#1;
        if(sample_out!==8'hff)$fatal(1,"FAIL VARIABLE positive saturation=%02x",sample_out);
        @(negedge clk);sample_in=8'h00;
        @(posedge clk);#1;
        if(sample_out!==8'h00)$fatal(1,"FAIL VARIABLE negative saturation=%02x",sample_out);
        $display("PASS IIR_NOTCH_VARIABLE: four targets >=10dB, 500Hz within 1dB, atomic apply, saturation");
        $finish;
    end
endmodule
