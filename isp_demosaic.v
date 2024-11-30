//*******************************************
//Function: Demosaic(RAW -> RGB)
//******************************************
`timescale 1ns/1ps

module isp_demosaic#(
    parameter BITS = 8,
    parameter WIDTH = 1280,
    parameter HEIGHT = 960,
    parameter BAYER =0   //0:RGGB,1:RGBG,2:GBRG 3:BGGR
)(
    input                   pclk  ,
    input                   rst_n ,

    input                   in_href  ,
    input                   in_vsync ,
    input   [BITS-1:0]      in_raw ,

    output                  out_href ,
    output                  out_vsync,
    output  reg [BITS-1:0]  out_r,
    output  reg [BITS-1:0]  out_g,
    output  reg [BITS-1:0]  out_b
);

//********************************************************************************************
//
//*********************************************************************************************

localparam DLY_CLK = 9;
reg [DLY_CLK-1:0]   vldout_dly ;//vldout delay
reg [DLY_CLK-1:0]   vsync_dly  ;//vsync delay
reg [  10-1:0   ]   row_cnt_ff1;
reg [  10-1:0   ]   row_cnt_ff2;
reg [  10-1:0   ]   row_cnt_ff3;
reg [  10-1:0   ]   row_cnt_ff4;
reg [  10-1:0   ]   row_cnt_ff5;
reg [  10-1:0   ]   row_cnt_ff6;
reg [  10-1:0   ]   row_cnt_ff7;
reg [  10-1:0   ]   row_cnt_ff8;
reg [  10-1:0   ]   row_cnt_ff9;
reg [  10-1:0   ]   row_cnt_ff10;
reg [  10-1:0   ]   row_cnt_ff11;

reg [ BITS-1:0  ]   in_raw_ff4  ;  
reg [ BITS-1:0  ]   in_raw_ff3  ;  
reg [ BITS-1:0  ]   in_raw_ff2  ;  
reg [ BITS-1:0  ]   in_raw_ff1  ; 

reg [ BITS-1:0  ]   P33_ff4     ;
reg [ BITS-1:0  ]   P33_ff3     ;
reg [ BITS-1:0  ]   P33_ff2     ;
reg [ BITS-1:0  ]   P33_ff1     ;


reg [ BITS-1:0  ]   p11,p12,p13,p14,p15;
reg [ BITS-1:0  ]   p21,p22,p23,p24,p25;
reg [ BITS-1:0  ]   p31,p32,p33,p34,p35;
reg [ BITS-1:0  ]   p41,p42,p43,p44,p45;
reg [ BITS-1:0  ]   p51,p52,p53,p54,p55;
reg [      1:0  ]   t3_fmt;
reg [  BITS-1:0 ]   t3_g;
reg [  BITS-2:0 ]   t3_r,t3_b;
reg [  BITS-1:0 ]   r_result,g_result,b_result;

reg                 odd_line ;
reg                 odd_pix  ;
reg                 vldout_ff1;
reg [   1-1:0   ]   t1_fmt;
reg [   1-1:0   ]   t2_fmt;
reg [   BITS-1:0]   t2_g , t2_g1 , t2_g2 , t2_g3 , t2_g4 ; 
reg [   BITS-1:0]   t2_rb, t2_rb1, t2_rb2, t2_rb3, t2_rb4;

reg [BITS*5-1:0 ]   t1_g,t1_g1,t1_g2,t1_g3,t1_g4;
reg [  BITS-1:0 ]   t1_rb,t1_rb1,t1_rb2,t1_rb3,t1_rb4;

wire                vldout  ;
wire [  10-1:0  ]   row_cnt ;
wire [  10-1:0  ]   col_cnt ;
wire [ BITS-1:0 ]   tap3x,tap2x,tap1x,tap0x;

//*********************************************************************************************
//
//*********************************************************************************************
 LINE_BUFFER #(BITS,WIDTH,HEIGHT,4) U_LINE_BUFFER(
    .clock      (pclk),
    .reset_n    (rst_n),
    .in_vsync   (in_vsync),
    .in_hsync   (in_href),
    .shiftin    (in_raw),
    .row_cnt    (row_cnt),
    .col_cnt    (col_cnt),
    .vldout     (vldout),
    .tapsx      ({tap3x,tap2x,tap1x,tap0x}),
 );


 always @(posedge pclk or negedge rst_n) begin
    if(~rst_n) begin
        p11 <= 0; p12 <= 0; p13 <= 0; p14 <= 0; p15 <= 0;
        p21 <= 0; p22 <= 0; p23 <= 0; p24 <= 0; p25 <= 0;
        p31 <= 0; p32 <= 0; p33 <= 0; p34 <= 0; p35 <= 0;
        p41 <= 0; p42 <= 0; p43 <= 0; p44 <= 0; p45 <= 0;
        p51 <= 0; p52 <= 0; p53 <= 0; p54 <= 0; p55 <= 0;
    end
    else begin
        p11 <= p12; p12 <= p13; p13 <= p14; p14 <= p15; p15 <= tap3x;
        p21 <= p22; p22 <= p23; p23 <= p24; p24 <= p25; p25 <= tap2x;
        p31 <= p32; p32 <= p33; p33 <= p34; p34 <= p35; p35 <= tap1x;
        p41 <= p42; p42 <= p43; p43 <= p44; p44 <= p45; p45 <= tap0x;
        p51 <= p52; p52 <= p53; p53 <= p54; p54 <= p55; p55 <= in_raw_ff4;
    end
 end

 always @(posedge pclk or negedge rst_n) begin
    if(!rst_n)
        odd_pix <=#1 0;
    else if(vldout_dly[2] == 1'b0)
        odd_pix <=#1 0;
    else 
        odd_pix <= #1 ~odd_pix;
 end

 wire odd_pix_sync_shift = odd_pix; //sync to shift_register

 always @(posedge pclk or negedge rst_n) begin
    if(!rst_n)
        vldout_ff1 <= 0;
    else
        vldout_ff1 <= vldout;
 end

 always @(posedge pclk or negedge rst_n)begin
    if(!rst_n) 
        odd_line <= 0;
    else if (in_vsync)
        odd_line <= 0;
    else if(vldout_ff1 & (~vldout))
        odd_line <= ~odd_line;
    else;
 end

 wire odd_line_sync_shift = odd_line; //sync to shift_register

 wire [1:0] p33_fmt = BAYER[1:0] ^ {odd_line_sync_shift, odd_pix_sync_shift}; //pixel format 0:[R]GGB,1:R[G]GB,2:RG[G]B,3RGG[B]


//*********************************************************************************************
//
//*********************************************************************************************
//calc  G stage 1
always @(posedge pclk or negedge rst_n) begin
    if(!rst_n)begin
        t1_fmt <=0;
        t1_g   <=0;
        t1_g1  <=0;
        t1_g2  <=0;
        t1_g3  <=0;
        t1_g4  <=0;
        t1_rb  <=0;
        t1_rb1 <=0;
        t1_rb2 <=0;
        t1_rb3 <=0;
        t1_rb4 <=0;
    end
    else begin
        t1_fmt <= p33_fmt;
        case(p33_fmt)
            FMT_R,FMT_B:begin  //[R]GGB,RGG[B]
                t1_rb  <= p33;  //Red   //Blue
                t1_rb1 <= p22;  //b     //r
                t1_rb2 <= p24;  //b     //r
                t1_rb3 <= p42;  //b     //r
                t1_rb4 <= p44;  //b     //r
                t1_g   <= cal_G_on_R_step1(p32,p34,p23,p43); //[BITS*5-1:0]
                t1_g1  <= cal_G_on_R_step1(p21,p23,p12,p32);
                t1_g2  <= cal_G_on_R_step1(p23,p25,p14,p34);
                t1_g3  <= cal_G_on_R_step1(p41,p43,p32,p52);
                t1_g4  <= cal_G_on_R_step1(p43,p45,p34,p54);
            end
            FMT_Gr,FMT_Gb:begin //R[G]GB  RG[G]B  （Gb上下R 左右B）  （Gr上下B 左右R）
                t1_rb  <= 0;
                t1_rb1 <= p32; //r     //b
                t1_rb2 <= p34; //r     //b
                t1_rb3 <= p23; //b     //r
                t1_rb4 <= p43; //b     //r
                t1_g   <= p33; //Green
                t1_g1  <= cal_G_on_R_step1(p31,p33,p22,p42);  //4g for r //4g for b   四个角的g
                t1_g2  <= cal_G_on_R_step1(p33,p35,p24,p44);  //4g for r //4g for b
                t1_g3  <= cal_G_on_R_step1(p22,p24,p13,p33);  //4g for b //4g for r
                t1_g4  <= cal_G_on_R_step1(p42,p44,p33,p53);  //4g for b //4g for r
            end
            default:begin
                t1_g   <=0;
                t1_g1  <=0;
                t1_g2  <=0;
                t1_g3  <=0;
                t1_g4  <=0;
                t1_rb  <=0;
                t1_rb1 <=0;
                t1_rb2 <=0;
                t1_rb3 <=0;
                t1_rb4 <=0;
            end
        endcase
    end
end

//calc  G stage 2
always@(posedge pclk or negedge rst_n) begin
    if(!rst_n)begin
        t2_fmt <=0;
        t2_g   <=0;
        t2_g1  <=0;
        t2_g2  <=0;
        t2_g3  <=0;
        t2_g4  <=0;
        t2_rb  <=0;
        t2_rb1 <=0;
        t2_rb2 <=0;
        t2_rb3 <=0;
        t2_rb4 <=0;
    end
    else begin
        t2_fmt <= t1_fmt;
        t2_rb  <= t1_rb;
        t2_rb1 <= t1_rb1;
        t2_rb2 <= t1_rb2;
        t2_rb3 <= t1_rb3;
        t2_rb4 <= t1_rb4;
        t2_g1  <= cal_G_on_R_step2(t1_g1);
        t2_g2  <= cal_G_on_R_step2(t1_g2);
        t2_g3  <= cal_G_on_R_step2(t1_g3);
        t2_g4  <= cal_G_on_R_step2(t1_g4);
        case (t1_fmt)
            FMT_R,FMT_B:t2_g <= cal_G_on_R_step2(t1_g); //中心点的G
            default:    t2_g <= t1_g[BITS-1:0];
        endcase
    end
end


//****************************************************************************************************
//
//****************************************************************************************************
//calc  R/G stage 1
always@(posedge pclk or negedge rst_n) begin
    if(!rst_n)begin
        t3_fmt <=0;
        t3_g   <=0;
        t3_r   <=0;
        t3_b   <=0;
    end
    else begin
        t3_fmt <= t2_fmt;
        t3_g   <= t2_g;
        case (t2_fmt)
            FMT_R:begin
                t3_r   <= t2_rb1;
                t3_b   <= cal_R_on_B_step1(t2_g,t2_g1,t2_g2,t2_g3,t2_g4,t2_rb1,t2_rb2,t2_rb3,t2_rb4);
            end
            FMT_Gr:begin
                t3_r   <= cal_R_on_G_step1(t2_g,t2_g1,t2_g2,t2_rb1,t2_rb2);
                t3_b   <= cal_R_on_G_step1(t2_g,t2_g1,t2_g2,t2_rb3,t2_rb4);
            end
            FMT_Gb:begin
                t3_r   <= cal_R_on_G_step1(t2_g,t2_g3,t2_g4,t2_rb3,t2_rb4);
                t3_b   <= cal_R_on_G_step1(t2_g,t2_g1,t2_g2,t2_rb1,t2_rb2);
            end
            FMT_B:begin
                t3_r   <= cal_R_on_B_step1(t2_g,t2_g1, t2_g2, t2_g3, t2_g4, t2_rb1, t2_rb2,t2_rb3,t2_rb4);
                t3_b   <= t2_rb;
            end
            default:begin
                t3_r   <= 0;
                t3_b   <= 0;
            end
        endcase
    end
end

//calc  R/B stage 2
always@(posedge pclk or negedge rst_n) begin
    if(!rst_n)begin
        r_result <=0;
        g_result <=0;
        b_result <=0;
    end
    else begin
        r_result <= t3_g;
        case(t3_fmt)
            FMT_R:begin
                r_result <= t3_r[BITS-1:0];
                b_result <= cal_R_on_B_step2(t3_b);
            end
            FMT_Gr:begin
                b_result <= cal_R_on_G_step2(t3_b);
                r_result <= cal_R_on_G_step2(t3_r);
            end
            FMT_Gb:begin
                b_result <= cal_R_on_G_step2(t3_b);
                r_result <= cal_R_on_G_step2(t3_r);
            end
            FMT_B:begin
                b_result <= t3_b[BITS-1:0];
                r_result <= cal_R_on_B_step2(t3_r);
            end
            default:begin
                r_result <=0;
                b_result <=0;
            end
        endcase
    end
end

always @(posedge pclk or negedge rst_n) begin
    if(!rst_n) begin
        vldout_dly <= 0;
        vsync_dly <= 0;
        in_raw_ff1 <= {BITS{1'b0}};
        in_raw_ff2 <= {BITS{1'b0}};
        in_raw_ff3 <= {BITS{1'b0}};
        in_raw_ff4 <= {BITS{1'b0}};
        p33_ff1    <= #1 0;
        p33_ff2    <= #1 0;
        p33_ff3    <= #1 0;
        p33_ff4    <= #1 0;
        row_cnt_ff1 <= #1 0;
        row_cnt_ff2 <= #1 0;
        row_cnt_ff3 <= #1 0;
        row_cnt_ff4 <= #1 0;
        row_cnt_ff5 <= #1 0;
        row_cnt_ff6 <= #1 0;
        row_cnt_ff7 <= #1 0;
        col_cnt_ff1 <= #1 0;
        col_cnt_ff2 <= #1 0;
        col_cnt_ff3 <= #1 0;
        col_cnt_ff4 <= #1 0;
        col_cnt_ff5 <= #1 0;
        col_cnt_ff6 <= #1 0;
        col_cnt_ff7 <= #1 0;
        col_cnt_ff8 <= #1 0;
        col_cnt_ff9 <= #1 0;
        col_cnt_ff10 <= #1 0;
        col_cnt_ff11 <= #1 0;
    end
    else begin
        vldout_dly <= #1 {vldout_dly[DLY_CLK-2:0],vldout};
        vsync_dly    <= #1 {vsync_dly[DLY_CLK-2:0],in_vsync};
        in_raw_ff4   <= #1 in_raw_ff3;
        in_raw_ff3   <= #1 in_raw_ff2;
        in_raw_ff2   <= #1 in_raw_ff1;
        in_raw_ff1   <= #1 in_raw;
        p33_ff1      <= #1 p33;
        p33_ff2      <= #1 p33_ff1;
        p33_ff3      <= #1 p33_ff2;
        p33_ff4      <= #1 p33_ff3;
        row_cnt_ff1  <= #1 row_cnt;
        row_cnt_ff2  <= #1 row_cnt_ff1;
        row_cnt_ff3  <= #1 row_cnt_ff2;
        row_cnt_ff4  <= #1 row_cnt_ff3;
        row_cnt_ff5  <= #1 row_cnt_ff4;
        row_cnt_ff6  <= #1 row_cnt_ff5;
        row_cnt_ff7  <= #1 row_cnt_ff6;
        col_cnt_ff1  <= #1 col_cnt;
        col_cnt_ff2  <= #1 col_cnt_ff1;
        col_cnt_ff3  <= #1 col_cnt_ff2;
        col_cnt_ff4  <= #1 col_cnt_ff3;
        col_cnt_ff5  <= #1 col_cnt_ff4;
        col_cnt_ff6  <= #1 col_cnt_ff5;
        col_cnt_ff7  <= #1 col_cnt_ff6;
        col_cnt_ff8  <= #1 col_cnt_ff7;
        col_cnt_ff9  <= #1 col_cnt_ff8;
        col_cnt_ff10 <= #1 col_cnt_ff9;
        col_cnt_ff11 <= #1 col_cnt_ff10;
    end
end

assign out_href = vldout_dly[6];
assign out_vsync = vsync_dly[8];


//****************************
//select boundary
//****************************
always(*)begin
    if(out_href == 1'b1)begin
        if((row_cnt_ff7 <= 11'd3) || (row_cnt_ff7 >= HEIGHT))begin
            out_r = p33_ff4;
            out_g = p33_ff4;
            out_b = p33_ff4;
        end
        else if((col_cnt_ff7 <= 11'd1) || (col_cnt_ff7 >= (WIDTH-2)))begin
            out_r = p33_ff4;
            out_g = p33_ff4;
            out_b = p33_ff4;
        end
        else begin
            out_r = r_result;
            out_g = g_result;
            out_b = b_result;
        end
    end
    else begin
        out_r = {BITS{1'b0}};
        out_g = {BITS{1'b0}};
        out_b = {BITS{1'b0}};
    end
end


//**********************************************************
//function
//**********************************************************
    function [BITS*5-1:0] cal_G_on_R_step1;
        input [BITS-1:0] G_left,G_right,G_up,G_down;
        reg   [BITS-1:0] diff_A,diff_B;
        reg   [BITS-1:0] G_out0,G_out1,G_out2;
        begin
            diff_A = G_left > G_right ? G_left - G_right : G_right - G_left; //G_out1
            diff_B = G_up   > G_down ? G_up   - G_down  : G_down - G_up;  //G_out2

            G_out0 ={2'b0,G_left} + {2'b0,G_right} + {2'b0,G_up} + {2'b0,G_down};//四个数求和，补两位0防止溢出
            G_out1 ={1'b0,G_left,1'b0} + {1'b0,G_right,1'b0};
            G_out2 ={1'b0,G_up,1'b0} + {1'b0,G_down,1'b0};
            cal_G_on_R_step1 = {diff_B, diff_A, G_out2[(BITS+1)-:BITS],G_out1[(BITS+1)-:BITS],G_out0[(BITS+1-:BITS)]};
        end
    endfunction

    function [BITS-1:0] cal_G_on_R_step2;
        input [BITS*5-1:0] stage1_in;
        reg   [BITS-1:0] diff_A,diff_B;
        reg   [BITS+1:0] G_out0,G_out1,G_out2;
        begin
            G_out0 = stage1_in[(0*BITS)+:BITS]; 
            G_out1 = stage1_in[(1*BITS)+:BITS]; 
            G_out2 = stage1_in[(2*BITS)+:BITS]; 
            diff_A = stage1_in[(3*BITS)+:BITS];
            diff_B = stage1_in[(4*BITS)+:BITS];
            cal_G_on_R_step2 = (diff_A == diff_B) ? G_out0 :((diff_A < diff_B)?G_out1:G_out2);
        end
    endfunction

    //------------------------------------------------------------------------------
    //色差恒定
    function [BITS*2:0] cal_R_on_G_step1;
        input [BITS-1:0] G,Gr1,Gr2,R1,R2;
        reg   [BITS-1:0] R_sum,Gr_sum;
        reg   [BITS-1:0] G_add_R_avg;
        begin
            R_sum ={1'd0,R1} + {1'd0,R2};
            Gr_sum = {1'd0,Gr1} + {1'd0,Gr2};
            G_add_R_avg = G + R_sum[BTS:1];
            cal_R_on_G_step1 = {G_add_R_avg,Gr_sum[BITS:1]};
        end
    endfunction

    function [BITS-1:0] cal_R_on_G_step2;
        input [BITS*2:0]    stage1_in;
        reg   [BITS:0]      G_add_R_avg;
        reg   [BITS-1:0]    Gr_avg;
        reg   [BITS:0]      R_out;
        begin
            Gr_avg = stage1_in[0+:BITS];
            G_add_R_avg = stage1_in[BITS+:BITS+1];
            R_out = G_add_R_avg > Gr_avg ? G_add_R_avg - Gr_avg :0;
            cal_R_on_G_step2 = R_out[BITS] ? {BITS{1'b1}} : R_out[BITS-1:0];
        end
    endfunction

    //--------------------------------------------------------------------------------------
    function [BITS*2:0] cal_R_on_B_step1;
        input [BITS-1:0] G,Gr1,Gr2,Gr3,Gr4,R1,R2,R3,R4;
        reg [BITS+1:0] R_sum,Gr_sum;
        reg [BITS:0] G_add_R_avg
        begin
            R_sum = {2'b0,R1} + {2'b0,R2} + {2'b0,R3} + {2'b0,R4};
            Gr_sum = {2'b0,Gr1} + {2'b0,Gr2} + {2'b0,Gr3} + {2'b0,Gr4};
            G_add_R_avg = G + R_sum[BITS+1:2];//截位等于除4
            cal_R_on_B_step1 = {G_add_R_avg,Gr_sum[BITS+1:2]};
        end
    endfunction

    function [BITS-1:0] cal_R_on_B_step2;
        input [BITS*2:0]    stage1_in;
        reg   [BITS:0]      G_add_R_avg;
        reg   [BITS-1:0]    Gr_avg;
        reg   [BITS:0]      R_out;
        begin
            Gr_avg = stage1_in[0+:BITS];
            G_add_R_avg = stage1_in[BITS+:BITS+1];
            R_out = G_add_R_avg > Gr_avg ? G_add_R_avg - Gr_avg :0;
            cal_R_on_B_step2 = R_out[BITS] ? {BITS{1'b1}} : R_out[BITS-1:0];
        end
    endfunction

endmodule


