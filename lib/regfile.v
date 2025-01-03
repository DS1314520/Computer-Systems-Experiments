`include "defines.vh"
module regfile(
    input wire clk,
    input wire [4:0] raddr1,
    output wire [31:0] rdata1,
    input wire [4:0] raddr2,
    output wire [31:0] rdata2,
    
    input wire we,
    input wire [4:0] waddr,
    input wire [31:0] wdata,

    input wire hi_r,
    input wire hi_we,
    input wire [31:0] hi_data,
    input wire lo_r,
    input wire lo_we,
    input wire [31:0] lo_data,
    output wire [31:0] hilo_data,
    input wire [37:0] ex_to_id_bus,//1
    input wire [37:0] mem_to_id_bus,//2
    input wire [37:0] wb_to_id_bus//3
);
    //鑷繁瀹剁殑hilo瀵勫瓨鍣�
    reg  [31:0] hi_o;
    reg  [31:0] lo_o;
    // write
    always @ (posedge clk) begin
        if (hi_we) begin
            hi_o <=  hi_data;
        end
    end
    always @ (posedge clk) begin
        if (lo_we) begin
            lo_o <= lo_data;
        end
    end
    //read
    assign hilo_data = (hi_r) ? hi_o 
                      :(lo_r) ? lo_o
                      : (32'b0);


    reg [31:0] reg_array [31:0];
    // write
    always @ (posedge clk) begin
        if (we && waddr!=5'b0) begin
            reg_array[waddr] <= wdata;
        end
    end
    
    
    
    wire ex_rf_we ;
    wire [4:0] ex_rf_waddr;
    wire [31:0] ex_result;//1
    
    wire mem_rf_we ;
    wire [4:0] mem_rf_waddr;
    wire [31:0] mem_result;//2
    
    wire wb_rf_we ;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_result;//3
    
    assign{
        ex_rf_we,
        ex_rf_waddr,
        ex_result
       }=ex_to_id_bus;//1
       
     assign{
        mem_rf_we,
        mem_rf_waddr,
        mem_result
       }=mem_to_id_bus;//2
       
     assign{
        wb_rf_we,
        wb_rf_waddr,
        wb_result
       }=wb_to_id_bus;//3

    // read out 1
    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : 
                     ((raddr1 ==ex_rf_waddr) && ex_rf_we)?ex_result://1
                     ((raddr1 ==mem_rf_waddr) && mem_rf_we)?mem_result://2
                     ((raddr1 ==wb_rf_waddr) && wb_rf_we)?wb_result://3
           reg_array[raddr1];
    
    

    // read out2
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : 
                             ((raddr1 ==ex_rf_waddr) && ex_rf_we)?ex_result://1
                             ((raddr1 ==mem_rf_waddr) && mem_rf_we)?mem_result://2
                             ((raddr1 ==wb_rf_waddr) && wb_rf_we)?wb_result://3
           reg_array[raddr2];

endmodule