
//添加了数据通路

`include "defines.vh"

module regfile(
    input wire clk,
    input wire rst,                // 复位信号
    input wire [4:0] raddr1,       // 读取寄存器地址1
    output wire [31:0] rdata1,     // 读取寄存器数据1
    input wire [4:0] raddr2,       // 读取寄存器地址2
    output wire [31:0] rdata2,     // 读取寄存器数据2
    
    input wire we,                 // 写使能信号
    input wire [4:0] waddr,        // 写寄存器地址
    input wire [31:0] wdata,       // 写数据
    
    input wire flush,              // 清除信号
    input wire stall,              // 停顿信号
    output wire [31:0] exe_data1,  // 执行阶段数据1（译码-执行）
    output wire [31:0] exe_data2,  // 执行阶段数据2（译码-执行）
    output wire [31:0] mem_data1,  // 访存阶段数据1（译码-访存）
    output wire [31:0] mem_data2   // 访存阶段数据2（译码-访存）
);

    // 寄存器堆
    reg [31:0] reg_array [31:0];   
    reg [31:0] rdata1_r, rdata2_r; // 缓存寄存器数据（数据通路）

    // 写操作
    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            reg_array[0] <= 32'b0;  // 通常寄存器0不能被写入
        end
        else if (!stall) begin
            if (we && waddr != 5'b0) begin
                reg_array[waddr] <= wdata; // 写入寄存器
            end
        end
    end

    // 读取操作 1
    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            rdata1_r <= 32'b0;
        end
        else if (!stall) begin
            if (raddr1 != 5'b0) begin
                rdata1_r <= reg_array[raddr1]; // 读取寄存器数据1
            end
            else begin
                rdata1_r <= 32'b0;
            end
        end
    end

    // 读取操作 2
    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            rdata2_r <= 32'b0;
        end
        else if (!stall) begin
            if (raddr2 != 5'b0) begin
                rdata2_r <= reg_array[raddr2]; // 读取寄存器数据2
            end
            else begin
                rdata2_r <= 32'b0;
            end
        end
    end

    // 数据通路：译码-执行、译码-访存
    assign exe_data1 = (flush) ? 32'b0 : rdata1_r; // 译码-执行数据
    assign exe_data2 = (flush) ? 32'b0 : rdata2_r; // 译码-执行数据
    assign mem_data1 = (flush) ? 32'b0 : rdata1_r; // 译码-访存数据
    assign mem_data2 = (flush) ? 32'b0 : rdata2_r; // 译码-访存数据

    // 输出数据
    assign rdata1 = (flush) ? 32'b0 : rdata1_r;
    assign rdata2 = (flush) ? 32'b0 : rdata2_r;

endmodule
