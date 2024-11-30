`timescale 1ns / 1ps
/* Shift Register based on Simple Dual-Port RAM基于简单双端口RAM */

module LINE_BUFFER #(
    parameter BITS  = 8;
    parameter WIDTH = 960;
    parameter HEIGHT = 540;
    parameter LINES = 4;
)(
    input           clock,
    input           rst_n,
    input           in_vsync,//垂直同步信号 （列信号）
    input           in_hsync,//水平同步信号 （行信号）
    input    [BITS-1:0] shiftin,//输入数据
    
    output  reg [10 - 1:0] row_cnt, //行计数器
    output  reg [10 - 1:0] col_cnt,//列计数器
    output                 vldout, //数据有效输出信号
    output  [BITS*LINES-1:0] tapsx //存储多行数据的输出
);

 //hubing localparam RAM_SZ = WIDTH -1;
 localparam RAM_SZ = WIDTH ;
 localparam RAM_AW = clogb2(RAM_SZ);//以2为底的对数

 reg   [9:0]         wr_rd_adr; //读写地址
 reg   [9:0]         wr_rd_adr_ff1;
 reg   [9:0]         wr_rd_adr_ff2;
 reg                 wr_rd_adr_ff3;

 reg                 vir_hsync_ff1;//虚拟水平同步信号
 reg                 vir_hsync_ff2;
 reg                 vir_hsync_ff3;
 reg                 vir_hsync_ff4;

 reg                 vir_vsync_ff1;//虚拟垂直同步信号
 reg                 vir_vsync_ff2;
 reg                 vir_vsync_ff3;
 reg                 vir_vsync_ff4;

 reg   [BITS-1:0]    line_out_0_ff1;//存储一行数据的输出
 reg   [BITS-1:0]    line_out_0_ff2;
 reg   [BITS-1:0]    line_out_0_ff3;
 reg   [BITS-1:0]    line_out_1_ff1;
 reg   [BITS-1:0]    line_out_1_ff2;
 reg   [BITS-1:0]    line_out_2_ff1;
 reg   [     5:0]    dly_last_hsync;//延迟的最后一行水平同步信号
 reg   [    15:0]    last_hsync_cnt;//最后一行水平同步信号计数器
 reg                 hsync_gen;//水平同步信号发生器
 reg                 hsync_filter;//水平同步信号滤波器

 wire  [BITS-1:0]    line_out_0;
 wire  [BITS-1:0]    line_out_1;
 wire  [BITS-1:0]    line_out_2;
 wire  [BITS-1:0]    line_out_3;
 wire                vir_hsync;

 always @(posedge clock or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        wr_rd_adr <= #1 0;
    end
    else if(vir_hsync == 1'b1) begin
        if(wr_rd_adr < RAM_SZ -1)
            wr_rd_adr <= wr_rd_adr + 1'b1; //取值范围为0~RAM_SZ-1
        else
            wr_rd_adr <= 0;
    end
    else
        wr_rd_adr <= 0;
 end

 assign vir_hsync = in_hsync | hsync_gen;
//5x5 line buffer 用四行来做
 simple_dp_ram #(BITS,RAM_AW,RAW_SZ) u_ram_0(clock, vir_hsync, wr_rd_adr, shiftin, vir_hsync, wr_rd_adr, line_out_0);
 simple_dp_ram #(BITS,RAM_AW, RAW_SZ) u_ram_1(clock,vir_hsync_ff1, wr_rd_adr_ff1, line_out_0,vir_hsync_ff1,wr_rd_adr_ff1,line_out_1);
 simple_dp_ram #(BITS,RAW_AW,RAW_SZ) u_ram_2(clock, vir_hsync_ff2, wr_rd_adr_ff2, line_out_1, vir_hsync_ff2, wr_rd_adr_ff2, line_out_2);
 simple_dp_ram #(BITS,RAW_AW,RAW_SZ) u_ram_3(clock, vir_hsync_ff3, wr_rd_adr_ff3, line_out_2, vir_hsync_ff3, wr_rd_adr_ff3, line_out_3);

 assign vldout = hsync_filter & vir_hsync_ff4;

assign tapsx[(BITS*0)+:BITS] = line_out_0_ff3;//需要做数据对齐
assign tapsx[(BITS*1)+:BITS] = line_out_1_ff2;
assign tapsx[(BITS*2)+:BITS] = line_out_1_ff2;
assign tapsx[(BITS*3)+:BITS] = line_out_3;

wire hsync_neg = (~vir_hsync_ff4) & vir_hsync_ff5; //end hsync  检测下降沿
wire vsync_neg = (   ~in_vsync  ) & in_vsync_ff1; //start vsync 检测下降沿

//列计数器
always @(posedge clock or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        col_cnt <= #1 0;
    end
    else if(vir_hsync_ff4 == 1'b1) begin)
        if(col_cnt <RAM_SZ -1)
            col_cnt <= col_cnt + 1'b1;
        else
            col_cnt <= 0;
    end
    else
        col_cnt <= 0;
end

//行计数器
always @(posedge clock or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        row_cnt <= #1 0;
    end
    else if(vsync_neg)begin
        row_cnt <= #1 0;
    end
    else if(hsync_neg == 1'b1) begin
        row_cnt <= row_cnt + 1'b1;
    end
    else;
end


always @(posedge clock or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        hsync_filter <= #1 1'b0;
    end
    else if(vsync_neg == 1'b1)begin
        hsync_filter <= #1 1'b0;
    end
    else if(row_cnt >= 'd2)begin   //2行后开始
        hsync_filter <= #1 1'b1;
    end
    else;
end

//********************************************************
// 3. generate virtual hsync to push out the last
//    line at the middle row
//*******************************************************

//generate another hsync to push out the last line

always @(posedge clock or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        last_hsync_cnt <= #1 16'b0;
        dly_last_hsync <= #1 6'd0;  
    end
    else if(hsync_neg == 1'b1)begin
        last_hsync_cnt <= #1 16'd0;
        dly_last_hsync <= #1 6'd0;
    end
    else if((row_cnt ==HEIGHT) || (row_cnt == HEIGHT+1))begin
        if(dly_last_hsync < 6'd32)
            dly_last_hsync <= #1 dly_last_hsync + 1'b1;
        else if(last_hsync_cnt < WIDTH)
            last_hsync_cnt <= #1 last_hsync_cnt + 1'b1;
        else;
    end
    else;
end

//generate hsync signal
always @(posedge clock or negedge rst_n) begin
    if(rst_n == 1'b0) 
        hsync_gen <= #1 1'd0;
    else if((row_cnt == HEIGH) || (row_cnt == HEIGHT +1))begin
        if((last_hsync_cnt >= 'd0) && (last_hsync_cnt< WIDTH) && (dly_last_hsync >=6'd32))
            hsync_gen <= #1 1'b1;
        else
            hsync_gen <= #1 1'd0;
    end
    else
        hsync_gen <= #1 1'd0;
end


always @(posedge clock or negedge rst_n) begin
    if(rst_n == 1'b0)begin
        vir_hsync_ff1 <= #1 1'b0;
        vir_hsync_ff2 <= #1 1'b0;
        vir_hsync_ff3 <= #1 1'b0;
        vir_hsync_ff4 <= #1 1'b0;
        vir_hsync_ff5 <= #1 1'b0;
        in_vsync_ff1 <= #1 1'b1;
        wr_rd_adr_ff1 <= #1 1'b0;
        wr_rd_adr_ff2 <= #1 1'b0;
        wr_rd_adr_ff3 <= #1 1'b0;

        line_out_0_ff1 <= #1 {BITS{1'b0}};
        line_out_0_ff2 <= #1 {BITS{1'b0}};
        line_out_0_ff3 <= #1 {BITS{1'b0}};

        line_out_1_ff1 <= #1 {BITS{1'b0}};
        line_out_1_ff2 <= #1 {BITS{1'b0}};

        line_out_2_ff1 <= #1 {BITS{1'b0}};
    end
    else begin
        vir_hsync_ff1 <= #1 vir_hsync ;
        vir_hsync_ff2 <= #1 vir_hsync_ff1;
        vir_hsync_ff3 <= #1 vir_hsync_ff2;
        vir_hsync_ff4 <= #1 vir_hsync_ff3;
        vir_hsync_ff5 <= #1 vir_hsync_ff4;

        in_vsync_ff1 <= #1 in_vsync;
        wr_rd_adr_ff1 <= #1 wr_rd_adr;
        wr_rd_adr_ff2 <= #1 wr_rd_adr_ff1;
        wr_rd_adr_ff3 <= #1 wr_rd_adr_ff2;

        line_out_0_ff1 <= #1 line_out_0;
        line_out_0_ff2 <= #1 line_out_0_ff1;
        line_out_0_ff3 <= #1 line_out_0_ff2;

        line_out_1_ff1 <= #1 line_out_1;
        line_out_1_ff2 <= #1 line_out_1_ff1;

        line_out_2_ff1 <= #1 line_out_2;
    end
end


//取对数函数  以2为底的对数
function integer clogb2;
    input integer depth;
    begin
       for(clogb2 = 0; depth >0; clogb2 = clogb2 +1)
           depth = depth >> 1;
    end
endfunction
endmodule



module simple_dp_ram #(
    parameter DW = 8;
    parameter AW = 44;
    parameter SZ = 2 **AW;
)(
    input           clk,
    input           wren,
    input   [AW-1:0] wraddr,
    input   [DW-1:0] data,
    input           rden,
    input   [AW-1:0] rdaddr,
    output  reg  [DW-1:0] q
    //output  [DW-1:0] q
)

//读优先
reg [DW-1:0] mem [SZ-1:0];
always @(posedge clk) begin
    if(wren) begin
        men[wraddr] <= data;
    end
end
always @(posedge clk) begin
    if(rden) begin
        q <= mem[rdaddr];
    end
end
//assign q = mem[rdaddr];

endmodule


