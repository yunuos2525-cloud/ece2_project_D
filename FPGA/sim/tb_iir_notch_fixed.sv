`timescale 1ns/1ps

module tb_iir_notch_fixed;
    localparam integer N=4096;
    localparam integer WARMUP=512;
    real PI=3.14159265358979323846;
    reg clk=0, rst=1, sample_valid=0;
    reg [7:0] sample_in=128;
    wire sample_out_valid;
    wire [7:0] sample_out;
    integer test_kind, drive_n, out_n, measured;
    real in500c,in500s,in1000c,in1000s;
    real out500c,out500s,out1000c,out1000s;
    real inamp500,inamp1000,outamp500,outamp1000,db500,db1000;
    integer metrics;
    always #10 clk=~clk;

    iir_notch_fixed dut(.clk(clk),.rst(rst),.sample_valid(sample_valid),
        .sample_in(sample_in),.sample_out_valid(sample_out_valid),.sample_out(sample_out));

    function automatic integer stimulus;
        input integer kind;
        input integer n;
        real v;
        begin
            v=128.0;
            if(kind==0) v=v+40.0*$sin(2.0*PI*500.0*n/16000.0);
            if(kind==1) v=v+40.0*$sin(2.0*PI*1000.0*n/16000.0);
            if(kind==2) v=v+35.0*$sin(2.0*PI*500.0*n/16000.0)+35.0*$sin(2.0*PI*1000.0*n/16000.0);
            if(kind==3) v=v+35.0*$sin(2.0*PI*500.0*n/16000.0);
            stimulus=$rtoi(v+0.5);
        end
    endfunction

    task automatic run_case;
        input integer kind;
        input integer check500;
        input integer check1000;
        real x, y, phase500, phase1000;
        begin
            rst=1; sample_valid=0; repeat(4) @(posedge clk); rst=0;
            test_kind=kind; out_n=0; measured=0;
            in500c=0;in500s=0;in1000c=0;in1000s=0;
            out500c=0;out500s=0;out1000c=0;out1000s=0;
            fork
                begin
                    for(drive_n=0;drive_n<N;drive_n=drive_n+1) begin
                        @(negedge clk); sample_in=stimulus(kind,drive_n); sample_valid=1;
                    end
                    @(negedge clk); sample_valid=0;
                end
                begin
                    while(out_n<N) begin
                        @(posedge clk); #1;
                        if(sample_out_valid) begin
                            if(out_n>=WARMUP) begin
                                y=$itor(sample_out)-128.0;
                                x=$itor(stimulus(kind,out_n))-128.0;
                                phase500=2.0*PI*500.0*out_n/16000.0;
                                phase1000=2.0*PI*1000.0*out_n/16000.0;
                                in500c=in500c+x*$cos(phase500); in500s=in500s+x*$sin(phase500);
                                in1000c=in1000c+x*$cos(phase1000); in1000s=in1000s+x*$sin(phase1000);
                                out500c=out500c+y*$cos(phase500); out500s=out500s+y*$sin(phase500);
                                out1000c=out1000c+y*$cos(phase1000); out1000s=out1000s+y*$sin(phase1000);
                                measured=measured+1;
                            end
                            out_n=out_n+1;
                        end
                    end
                end
            join
            inamp500=2.0*$sqrt(in500c*in500c+in500s*in500s)/measured;
            inamp1000=2.0*$sqrt(in1000c*in1000c+in1000s*in1000s)/measured;
            outamp500=2.0*$sqrt(out500c*out500c+out500s*out500s)/measured;
            outamp1000=2.0*$sqrt(out1000c*out1000c+out1000s*out1000s)/measured;
            db500=(check500!=0)?20.0*$ln(outamp500/inamp500)/$ln(10.0):0.0;
            db1000=(check1000!=0)?20.0*$ln(outamp1000/inamp1000)/$ln(10.0):0.0;
            $display("METRIC kind=%0d in500=%0.6f out500=%0.6f db500=%0.3f in1000=%0.6f out1000=%0.6f db1000=%0.3f",kind,inamp500,outamp500,db500,inamp1000,outamp1000,db1000);
            $fdisplay(metrics,"%0d,%0.6f,%0.6f,%0.3f,%0.6f,%0.6f,%0.3f",kind,inamp500,outamp500,db500,inamp1000,outamp1000,db1000);
            if(check500!=0 && (db500 < -1.0 || db500 > 1.0)) $fatal(1,"FAIL IIR wanted 500 Hz change=%0.3f dB",db500);
            if(check1000!=0 && db1000 > -10.0) $fatal(1,"FAIL IIR 1 kHz attenuation=%0.3f dB",db1000);
        end
    endtask

    initial begin
        $dumpfile("project_evidence/fpga/W1/sim/tb_iir_notch_fixed.vcd");
        $dumpvars(0,tb_iir_notch_fixed);
        metrics=$fopen("project_evidence/fpga/W1/sim/notch_metrics.csv","w");
        $fdisplay(metrics,"kind,input_amp500,output_amp500,gain500_db,input_amp1000,output_amp1000,gain1000_db");
        run_case(0,1,0); // 500 Hz A40
        run_case(3,1,0); // 500 Hz A35
        run_case(1,0,1); // 1 kHz A40
        run_case(2,1,1); // 500 Hz A35 + 1 kHz A35
        $fclose(metrics);
        $display("PASS IIR_NOTCH_FIXED: quantized-input spectrum; A40/A35/mixed 500Hz <=1dB; 1kHz >=10dB");
        $finish;
    end
endmodule
