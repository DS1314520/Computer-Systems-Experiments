`include "lib/defines.vh"
module CTRL(
    input wire rst,
    // input wire stallreq_for_ex,
    // input wire stallreq_for_load,

    // output reg flush,
    // output reg [31:0] new_pc,
    output reg [`StallBus-1:0] stall,

    //从ID处传来的，请求暂停指令，因为需要加气泡了
    input  wire stallreq_for_id_if
);  
    always @ (*) begin
        if (rst) begin
            stall = `StallBus'b0;  // 当复位时，stall设为0
        end
        else if(stallreq_for_id_if == `Stop) begin // 请确保'‘Stop’正确定义
            stall = 6'b000111;    // 根据需求直接赋值
        end
        else begin
            stall = `StallBus'b0;  // 默认情况下也设为0
        end
    end

endmodule