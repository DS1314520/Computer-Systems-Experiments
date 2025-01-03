`include "lib/defines.vh"
module ID(//指令译码
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    input wire ex_is_load,//执行阶段是否为加载操作的标志信号
    
    
    output wire stallreq,//停顿请求信号，用于请求流水线暂停

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    input wire [31:0] inst_sram_rdata,//从指令存储器（SRAM）读取到的指令数据

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,//从写回阶段（WB）到寄存器文件（RF）的总线


    input wire [37:0] ex_to_id_bus,//1
    input wire [37:0] mem_to_id_bus,//2
    input wire [37:0] wb_to_id_bus,//3

//来自执行阶段（EX）到指令译码阶段（ID）的高低位寄存器相关信号
    input wire [65:0] hilo_ex_to_id,
    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`BR_WD-1:0] br_bus,
    output wire stallreq_from_id//指令译码阶段（ID）的停顿请求信号
);

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    wire [31:0] inst;//线网 当前指令数据
    wire [31:0] id_pc;//指令对应的程序计数器（PC）值
    wire ce;//使能信号
    
    wire wb_rf_we;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;

    wire wb_id_we;//来自写回阶段的写使能信号
    wire [4:0] wb_id_waddr;
    wire [31:0] wb_id_wdata;

    wire mem_id_we;
    wire [4:0] mem_id_waddr;
    wire [31:0] mem_id_wdata;
    reg q;
    wire ex_id_we;
    wire [4:0] ex_id_waddr;
    wire [31:0] ex_id_wdata;

    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end

    always @(posedge clk) begin
        if (stall[1]==`Stop) begin
            q <= 1'b1;
        end
        else begin
            q <= 1'b0;
        end
    end
    assign inst = (q) ?inst: inst_sram_rdata;

    //assign inst = inst_sram_rdata;

    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;

    assign {
        wb_id_we,
        wb_id_waddr,
        wb_id_wdata
    } = wb_to_id_bus;

    assign {
        mem_id_we,
        mem_id_waddr,
        mem_id_wdata
    } = mem_to_id_bus;

    assign {
        ex_id_we,
        ex_id_waddr,
        ex_id_wdata
    } = ex_to_id_bus;

    wire [5:0] opcode;//指令的操作码
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;//指令的功能码
    wire [15:0] imm;//立即数字段
    wire [25:0] instr_index;//指令中的索引字段
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;//选择信号

    wire [63:0] op_d, func_d;//操作码和功能码的详细解码信息
    wire [31:0] rs_d, rt_d, rd_d, sa_d;//对应寄存器 rs, rt, rd, sa 的数据

    wire [2:0] sel_alu_src1;//ALU第一个操作数的选择信号
    wire [3:0] sel_alu_src2;//ALU第二个操作数的选择信号
    wire [11:0] alu_op;//ALU操作类型信号

    wire data_ram_en;//数据存储器的使能信号
    wire [3:0] data_ram_wen;
    wire [3:0] data_ram_readen;
    
    wire rf_we;//寄存器文件的写使能信号
    wire [4:0] rf_waddr;//寄存器文件的写地址
    wire sel_rf_res;//选择寄存器文件写入结果的信号
    wire [2:0] sel_rf_dst;//选择寄存器文件写入目标的信号

    wire [31:0] rdata1, rdata2;//从寄存器文件读取的两个源操作数
    wire [31:0] rdata11, rdata22;//经过转发逻辑处理后的操作数



    wire hi_r,hi_wen,lo_r,lo_wen;//高位寄存器和低位寄存器的读写使能信号
    wire [31:0] hi_data;//高位寄存器和低位寄存器的数据，以及高低位合并的数据，32位宽。
    wire [31:0] lo_data;
    wire [31:0] hilo_data;
    assign {
        hi_wen,         // 65
        lo_wen,         // 64
        hi_data,           // 63:32
        lo_data           // 31:0
    } = hilo_ex_to_id;

    assign hi_r = inst_mfhi;
    assign lo_r = inst_mflo;

//寄存器文件的实例化
    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  ),
        .ex_to_id_bus (ex_to_id_bus),//1
        .mem_to_id_bus (mem_to_id_bus),//2
        .wb_to_id_bus (wb_to_id_bus),//3

        .hi_r      ( hi_r   ),
        .hi_we     (  hi_wen   ),
        .hi_data   (  hi_data  ),
        .lo_r      (  lo_r   ),
        .lo_we     (   lo_wen   ),
        .lo_data   (   lo_data  ),
        .hilo_data (   hilo_data )
    );
    //多路选择器赋值（Move From HI/LO 指令的数据选择）
    wire [31:0] mf_data;
    assign mf_data = (inst_mfhi & hi_wen) ? hi_data
                    :(inst_mfhi) ? hilo_data
                    :(inst_mflo & lo_wen) ? lo_data
                    :(inst_mflo) ? hilo_data
                    :(32'b0);
    
  //数据转发逻辑
    assign rdata11 = (inst_mfhi | inst_mflo) ? mf_data
                   :(ex_id_we &(ex_id_waddr==rs))?ex_id_wdata
                   : (mem_id_we &(mem_id_waddr==rs)) ? mem_id_wdata
                   : (wb_id_we &(wb_id_waddr==rs)) ? wb_id_wdata 
                   : rdata1;
    assign rdata22 =  (inst_mfhi | inst_mflo) ? mf_data
                   :(ex_id_we &(ex_id_waddr==rt))?ex_id_wdata
                   : (mem_id_we &(mem_id_waddr==rt)) ? mem_id_wdata
                   : (wb_id_we &(wb_id_waddr==rt)) ? wb_id_wdata 
                   : rdata2;

    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];

    wire inst_ori, inst_lui, inst_addiu, inst_beq,
    //inst_ori 瀵勫瓨鍣? rs 涓殑鍊间笌 0 鎵╁睍鑷? 32 浣嶇殑绔嬪嵆鏁? imm 鎸変綅閫昏緫鎴栵紝缁撴灉鍐欏叆瀵勫瓨鍣? rt 涓??
    //inst_lui 灏? 16 浣嶇珛鍗虫暟 imm 鍐欏叆瀵勫瓨鍣? rt 鐨勯珮 16 浣嶏紝瀵勫瓨鍣? rt 鐨勪綆 16 浣嶇疆 0
    //inst_addiu 灏嗗瘎瀛樺櫒 rs 鐨勫?间笌鏈夌鍙锋墿灞? 锛庯紟锛庯紟锛庤嚦 32 浣嶇殑绔嬪嵆鏁? imm 鐩稿姞锛岀粨鏋滃啓鍏? rt 瀵勫瓨鍣ㄤ腑銆?
    //inst_beq 濡傛灉瀵勫瓨鍣? rs 鐨勫?肩瓑浜庡瘎瀛樺櫒 rt 鐨勫?煎垯杞Щ锛屽惁鍒欓『搴忔墽琛屻?傝浆绉荤洰鏍囩敱绔嬪嵆鏁? offset 宸︾Щ 2 浣?
               //骞惰繘琛屾湁绗﹀彿鎵╁睍鐨勫?煎姞涓婅鍒嗘敮鎸囦护瀵瑰簲鐨勫欢杩熸Ы鎸囦护鐨? PC 璁＄畻寰楀埌銆?
    inst_subu,//灏嗗瘎瀛樺櫒 rs 鐨勫?间笌瀵勫瓨鍣? rt 鐨勫?肩浉鍑忥紝缁撴灉鍐欏叆 rd 瀵勫瓨鍣ㄤ腑
    inst_jr,// 鏃犳潯浠惰烦杞?傝烦杞洰鏍囦负瀵勫瓨鍣? rs 涓殑鍊?
    inst_jal,//鏃犳潯浠惰烦杞?傝烦杞洰鏍囩敱璇ュ垎鏀寚浠ゅ搴旂殑寤惰繜妲芥寚浠ょ殑 PC 鐨勬渶楂? 4 浣嶄笌绔嬪嵆鏁? instr_index 宸︾Щ
            //2 浣嶅悗鐨勫?兼嫾鎺ュ緱鍒般?傚悓鏃跺皢璇ュ垎鏀搴斿欢杩熸Ы鎸囦护涔嬪悗鐨勬寚浠ょ殑 PC 鍊间繚瀛樿嚦绗? 31 鍙烽?氱敤瀵勫瓨
            //鍣ㄤ腑銆?
    inst_lw,//灏? base 瀵勫瓨鍣ㄧ殑鍊煎姞涓婄鍙锋墿灞曞悗鐨勭珛鍗虫暟 offset 寰楀埌璁垮瓨鐨勮櫄鍦板潃锛屽鏋滃湴鍧?涓嶆槸 4 鐨勬暣鏁板??
            //鍒欒Е鍙戝湴鍧?閿欎緥澶栵紝鍚﹀垯鎹铏氬湴鍧?浠庡瓨鍌ㄥ櫒涓鍙栬繛缁? 4 涓瓧鑺傜殑鍊硷紝鍐欏叆鍒? rt 瀵勫瓨鍣ㄤ腑銆?
    inst_or,    //瀵勫瓨鍣? rs 涓殑鍊间笌瀵勫瓨鍣? rt 涓殑鍊兼寜浣嶉?昏緫鎴栵紝缁撴灉鍐欏叆瀵勫瓨鍣? rd 涓?
    inst_sll,   //鐢辩珛鍗虫暟 sa 鎸囧畾绉讳綅閲忥紝瀵瑰瘎瀛樺櫒 rt 鐨勫?艰繘琛岄?昏緫宸︾Щ锛岀粨鏋滃啓鍏ュ瘎瀛樺櫒 rd 涓??
    inst_addu,//灏嗗瘎瀛樺櫒 rs 鐨勫?间笌瀵勫瓨鍣? rt 鐨勫?肩浉鍔狅紝缁撴灉鍐欏叆 rd 瀵勫瓨鍣ㄤ腑 
    inst_bne,//濡傛灉瀵勫瓨鍣? rs 鐨勫?间笉绛変簬瀵勫瓨鍣? rt 鐨勫?煎垯杞Щ锛屽惁鍒欓『搴忔墽琛屻?傝浆绉荤洰鏍囩敱绔嬪嵆鏁? offset 宸︾Щ 2
              //浣嶅苟杩涜鏈夌鍙锋墿灞曠殑鍊煎姞涓婅鍒嗘敮鎸囦护瀵瑰簲鐨勫欢杩熸Ы鎸囦护鐨? PC 璁＄畻寰楀埌
    inst_xor,//瀵勫瓨鍣? rs 涓殑鍊间笌瀵勫瓨鍣? rt 涓殑鍊兼寜浣嶉?昏緫寮傛垨锛岀粨鏋滃啓鍏ュ瘎瀛樺櫒 rd 涓??
    inst_xori,//瀵勫瓨鍣? rs 涓殑鍊间笌 0 鎵╁睍鑷? 32 浣嶇殑绔嬪嵆鏁? imm 鎸変綅閫昏緫寮傛垨锛岀粨鏋滃啓鍏ュ瘎瀛樺櫒 rt 涓??
    inst_nor,//瀵勫瓨鍣? rs 涓殑鍊间笌瀵勫瓨鍣? rt 涓殑鍊兼寜浣嶉?昏緫鎴栭潪锛岀粨鏋滃啓鍏ュ瘎瀛樺櫒 rd 涓??
    inst_sw,//灏? base 瀵勫瓨鍣ㄧ殑鍊煎姞涓婄鍙锋墿灞曞悗鐨勭珛鍗虫暟 offset 寰楀埌璁垮瓨鐨勮櫄鍦板潃锛屽鏋滃湴鍧?涓嶆槸 4 鐨勬暣鏁板??
            //鍒欒Е鍙戝湴鍧?閿欎緥澶栵紝鍚﹀垯鎹铏氬湴鍧?灏? rt 瀵勫瓨鍣ㄥ瓨鍏ュ瓨鍌ㄥ櫒涓??
    inst_sltu,//灏嗗瘎瀛樺櫒 rs 鐨勫?间笌瀵勫瓨鍣? rt 涓殑鍊艰繘琛屾棤绗﹀彿鏁版瘮杈冿紝濡傛灉瀵勫瓨鍣? rs 涓殑鍊煎皬锛屽垯瀵勫瓨鍣? rd 缃? 1锛?
              //鍚﹀垯瀵勫瓨鍣? rd 缃? 0銆?
    inst_slt,//灏嗗瘎瀛樺櫒 rs 鐨勫?间笌瀵勫瓨鍣? rt 涓殑鍊艰繘琛屾湁绗﹀彿鏁版瘮杈冿紝濡傛灉瀵勫瓨鍣? rs 涓殑鍊煎皬锛屽垯瀵勫瓨鍣? rd 缃? 1锛?
             //鍚﹀垯瀵勫瓨鍣? rd 缃? 0銆?
    inst_slti,//灏嗗瘎瀛樺櫒 rs 鐨勫?间笌鏈夌鍙锋墿灞曡嚦 32 浣嶇殑绔嬪嵆鏁? imm 杩涜鏈夌鍙锋暟姣旇緝锛屽鏋滃瘎瀛樺櫒 rs 涓殑鍊煎皬锛?
              //鍒欏瘎瀛樺櫒 rt 缃? 1锛涘惁鍒欏瘎瀛樺櫒 rt 缃? 0銆?
    inst_sltiu,//灏嗗瘎瀛樺櫒 rs 鐨勫?间笌鏈夌鍙锋墿灞? 锛庯紟锛庯紟锛庤嚦 32 浣嶇殑绔嬪嵆鏁? imm 杩涜鏃犵鍙锋暟姣旇緝锛屽鏋滃瘎瀛樺櫒 rs 涓殑鍊煎皬锛?
               //鍒欏瘎瀛樺櫒 rt 缃? 1锛涘惁鍒欏瘎瀛樺櫒 rt 缃? 0銆?
    inst_j,//鏃犳潯浠惰烦杞?傝烦杞洰鏍囩敱璇ュ垎鏀寚浠ゅ搴旂殑寤惰繜妲芥寚浠ょ殑 PC 鐨勬渶楂? 4 浣嶄笌绔嬪嵆鏁? instr_index 宸︾Щ
           //2 浣嶅悗鐨勫?兼嫾鎺ュ緱鍒般??
    inst_add,//灏嗗瘎瀛樺櫒 rs 鐨勫?间笌瀵勫瓨鍣? rt 鐨勫?肩浉鍔狅紝缁撴灉鍐欏叆瀵勫瓨鍣? rd 涓?傚鏋滀骇鐢熸孩鍑猴紝鍒欒Е鍙戞暣鍨嬫孩鍑轰緥
            //澶栵紙IntegerOverflow锛夈??
    inst_addi,//灏嗗瘎瀛樺櫒 rs 鐨勫?间笌鏈夌鍙锋墿灞曡嚦 32 浣嶇殑绔嬪嵆鏁? imm 鐩稿姞锛岀粨鏋滃啓鍏? rt 瀵勫瓨鍣ㄤ腑銆傚鏋滀骇鐢熸孩鍑猴紝
              // 鍒欒Е鍙戞暣鍨嬫孩鍑轰緥澶栵紙IntegerOverflow锛夈??
    inst_sub,//灏嗗瘎瀛樺櫒 rs 鐨勫?间笌瀵勫瓨鍣? rt 鐨勫?肩浉鍑忥紝缁撴灉鍐欏叆 rd 瀵勫瓨鍣ㄤ腑銆傚鏋滀骇鐢熸孩鍑猴紝鍒欒Е鍙戞暣鍨嬫孩鍑轰緥
             //澶栵紙IntegerOverflow锛夈??
    inst_and,//瀵勫瓨鍣? rs 涓殑鍊间笌瀵勫瓨鍣? rt 涓殑鍊兼寜浣嶉?昏緫涓庯紝缁撴灉鍐欏叆瀵勫瓨鍣? rd 涓??
    inst_andi,//瀵勫瓨鍣? rs 涓殑鍊间笌 0 鎵╁睍鑷? 32 浣嶇殑绔嬪嵆鏁? imm 鎸変綅閫昏緫涓庯紝缁撴灉鍐欏叆瀵勫瓨鍣? rt 涓??
    inst_sllv,//鐢卞瘎瀛樺櫒 rs 涓殑鍊兼寚瀹氱Щ浣嶉噺锛屽瀵勫瓨鍣? rt 鐨勫?艰繘琛岄?昏緫宸︾Щ锛岀粨鏋滃啓鍏ュ瘎瀛樺櫒 rd 涓??
    inst_sra,//鐢辩珛鍗虫暟 sa 鎸囧畾绉讳綅閲忥紝瀵瑰瘎瀛樺櫒 rt 鐨勫?艰繘琛岀畻鏈彸绉伙紝缁撴灉鍐欏叆瀵勫瓨鍣? rd 涓??
    inst_srav,//鐢卞瘎瀛樺櫒 rs 涓殑鍊兼寚瀹氱Щ浣嶉噺锛屽瀵勫瓨鍣? rt 鐨勫?艰繘琛岀畻鏈彸绉伙紝缁撴灉鍐欏叆瀵勫瓨鍣? rd 涓??
    inst_srl,//鐢辩珛鍗虫暟 sa 鎸囧畾绉讳綅閲忥紝瀵瑰瘎瀛樺櫒 rt 鐨勫?艰繘琛岄?昏緫鍙崇Щ锛岀粨鏋滃啓鍏ュ瘎瀛樺櫒 rd 涓??
    inst_srlv,//鐢卞瘎瀛樺櫒 rs 涓殑鍊兼寚瀹氱Щ浣嶉噺锛屽瀵勫瓨鍣? rt 鐨勫?艰繘琛岄?昏緫鍙崇Щ锛岀粨鏋滃啓鍏ュ瘎瀛樺櫒 rd 涓??
    inst_bgez,//濡傛灉瀵勫瓨鍣? rs 鐨勫?煎ぇ浜庣瓑浜? 0 鍒欒浆绉伙紝鍚﹀垯椤哄簭鎵ц銆傝浆绉荤洰鏍囩敱绔嬪嵆鏁? offset 宸︾Щ 2 浣嶅苟杩涜鏈?
              //绗﹀彿鎵╁睍鐨勫?煎姞涓婅鍒嗘敮鎸囦护瀵瑰簲鐨勫欢杩熸Ы鎸囦护鐨? PC 璁＄畻寰楀埌銆?
    inst_bgtz,//濡傛灉瀵勫瓨鍣? rs 鐨勫?煎ぇ浜? 0 鍒欒浆绉伙紝鍚﹀垯椤哄簭鎵ц銆傝浆绉荤洰鏍囩敱绔嬪嵆鏁? offset 宸︾Щ 2 浣嶅苟杩涜鏈夌鍙?
              //鎵╁睍鐨勫?煎姞涓婅鍒嗘敮鎸囦护瀵瑰簲鐨勫欢杩熸Ы鎸囦护鐨? PC 璁＄畻寰楀埌銆?
    inst_blez,//濡傛灉瀵勫瓨鍣? rs 鐨勫?煎皬浜庣瓑浜? 0 鍒欒浆绉伙紝鍚﹀垯椤哄簭鎵ц銆傝浆绉荤洰鏍囩敱绔嬪嵆鏁? offset 宸︾Щ 2 浣嶅苟杩涜鏈?
              //绗﹀彿鎵╁睍鐨勫?煎姞涓婅鍒嗘敮鎸囦护瀵瑰簲鐨勫欢杩熸Ы鎸囦护鐨? PC 璁＄畻寰楀埌銆?
    inst_bltz,//濡傛灉瀵勫瓨鍣? rs 鐨勫?煎皬浜? 0 鍒欒浆绉伙紝鍚﹀垯椤哄簭鎵ц銆傝浆绉荤洰鏍囩敱绔嬪嵆鏁? offset 宸︾Щ 2 浣嶅苟杩涜鏈夌鍙?
              //鎵╁睍鐨勫?煎姞涓婅鍒嗘敮鎸囦护瀵瑰簲鐨勫欢杩熸Ы鎸囦护鐨? PC 璁＄畻寰楀埌銆?
    inst_bltzal,//濡傛灉瀵勫瓨鍣? rs 鐨勫?煎皬浜? 0 鍒欒浆绉伙紝鍚﹀垯椤哄簭鎵ц銆傝浆绉荤洰鏍囩敱绔嬪嵆鏁? offset 宸︾Щ 2 浣嶅苟杩涜鏈夌鍙?
                //鎵╁睍鐨勫?煎姞涓婅鍒嗘敮鎸囦护瀵瑰簲鐨勫欢杩熸Ы鎸囦护鐨? PC 璁＄畻寰楀埌銆傛棤璁鸿浆绉讳笌鍚︼紝灏嗚鍒嗘敮瀵瑰簲寤惰繜妲?
                //鎸囦护涔嬪悗鐨勬寚浠ょ殑 PC 鍊间繚瀛樿嚦绗? 31 鍙烽?氱敤瀵勫瓨鍣ㄤ腑銆?
    inst_bgezal,inst_jalr,inst_div,inst_divu,
    inst_mflo,//灏? LO 瀵勫瓨鍣ㄧ殑鍊煎啓鍏ュ埌瀵勫瓨鍣? rd 涓?
    inst_mfhi,//灏? HI 瀵勫瓨鍣ㄧ殑鍊煎啓鍏ュ埌瀵勫瓨鍣? rd 涓?
    inst_mult,inst_multu,inst_mthi,inst_mtlo,inst_lb,
    inst_lbu,//灏? base 瀵勫瓨鍣ㄧ殑鍊煎姞涓婄鍙锋墿灞曞悗鐨勭珛鍗虫暟 offset 寰楀埌璁垮瓨鐨勮櫄鍦板潃锛屾嵁姝よ櫄鍦板潃浠庡瓨鍌ㄥ櫒涓
             //鍙? 1 涓瓧鑺傜殑鍊煎苟杩涜 0 鎵╁睍锛屽啓鍏ュ埌 rt 瀵勫瓨鍣ㄤ腑
    inst_lh,//灏? base 瀵勫瓨鍣ㄧ殑鍊煎姞涓婄鍙锋墿灞曞悗鐨勭珛鍗虫暟 offset 寰楀埌璁垮瓨鐨勮櫄鍦板潃锛屽鏋滃湴鍧?涓嶆槸 2 鐨勬暣鏁板??
            //鍒欒Е鍙戝湴鍧?閿欎緥澶栵紝鍚﹀垯鎹铏氬湴鍧?浠庡瓨鍌ㄥ櫒涓鍙栬繛缁? 2 涓瓧鑺傜殑鍊煎苟杩涜绗﹀彿鎵╁睍锛屽啓鍏ュ埌
            //rt 瀵勫瓨鍣ㄤ腑銆?
    inst_lhu,//灏? base 瀵勫瓨鍣ㄧ殑鍊煎姞涓婄鍙锋墿灞曞悗鐨勭珛鍗虫暟 offset 寰楀埌璁垮瓨鐨勮櫄鍦板潃锛屽鏋滃湴鍧?涓嶆槸 2 鐨勬暣鏁板??
             //鍒欒Е鍙戝湴鍧?閿欎緥澶栵紝鍚﹀垯鎹铏氬湴鍧?浠庡瓨鍌ㄥ櫒涓鍙栬繛缁? 2 涓瓧鑺傜殑鍊煎苟杩涜 0 鎵╁睍锛屽啓鍏ュ埌 rt
             //瀵勫瓨鍣ㄤ腑銆?
    inst_sb, //灏? base 瀵勫瓨鍣ㄧ殑鍊煎姞涓婄鍙锋墿灞曞悗鐨勭珛鍗虫暟 offset 寰楀埌璁垮瓨鐨勮櫄鍦板潃锛屾嵁姝よ櫄鍦板潃灏? rt 瀵勫瓨鍣ㄧ殑
             //鏈?浣庡瓧鑺傚瓨鍏ュ瓨鍌ㄥ櫒涓??
    inst_lsa,
    inst_sh; //灏? base 瀵勫瓨鍣ㄧ殑鍊煎姞涓婄鍙锋墿灞曞悗鐨勭珛鍗虫暟 offset 寰楀埌璁垮瓨鐨勮櫄鍦板潃锛屽鏋滃湴鍧?涓嶆槸 2 鐨勬暣鏁板??
             //鍒欒Е鍙戝湴鍧?閿欎緥澶栵紝鍚﹀垯鎹铏氬湴鍧?灏? rt 瀵勫瓨鍣ㄧ殑浣庡崐瀛楀瓨鍏ュ瓨鍌ㄥ櫒涓??
    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );

    
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_beq     = op_d[6'b00_0100];
    assign inst_subu    = op_d[6'b00_0000] && func_d[6'b10_0011];
    assign inst_jr      = op_d[6'b00_0000] && func_d[6'b00_1000];
    assign inst_jal     = op_d[6'b00_0011];
    assign inst_lw      = op_d[6'b10_0011];
    assign inst_addu    = op_d[6'b00_0000] && func_d[6'b10_0001];
    assign inst_or      = op_d[6'b00_0000] && func_d[6'b10_0101];
    assign inst_sll     = op_d[6'b00_0000] && func_d[6'b00_0000];
    assign inst_bne     = op_d[6'b00_0101];
    assign inst_xor     = op_d[6'b00_0000] && func_d[6'b10_0110];
    assign inst_xori    = op_d[6'b00_1110];
    assign inst_nor     = op_d[6'b00_0000] && func_d[6'b10_0111];
    assign inst_sw      = op_d[6'b10_1011]; 
    assign inst_sltu    = op_d[6'b00_0000] && func_d[6'b10_1011];
    assign inst_slt     = op_d[6'b00_0000] && func_d[6'b10_1010];
    assign inst_slti    = op_d[6'b00_1010];
    assign inst_sltiu   = op_d[6'b00_1011];
    assign inst_j       = op_d[6'b00_0010]; 
    assign inst_add     = op_d[6'b00_0000] && func_d[6'b10_0000];
    assign inst_addi    = op_d[6'b00_1000];
    assign inst_sub     = op_d[6'b00_0000] && func_d[6'b10_0010];
    assign inst_and     = op_d[6'b00_0000] && func_d[6'b10_0100];
    assign inst_andi    = op_d[6'b00_1100];
    assign inst_sllv    = op_d[6'b00_0000] && func_d[6'b00_0100];
    assign inst_sra     = op_d[6'b00_0000] && func_d[6'b00_0011];
    assign inst_srav    = op_d[6'b00_0000] && func_d[6'b00_0111];
    assign inst_srl     = op_d[6'b00_0000] && func_d[6'b00_0010];
    assign inst_srlv    = op_d[6'b00_0000] && func_d[6'b00_0110];
    assign inst_bgez    = op_d[6'b00_0001] && rt_d[5'b00001];
    assign inst_bgtz    = op_d[6'b00_0111] && rt_d[5'b00000];
    assign inst_blez    = op_d[6'b00_0110] && rt_d[5'b00000];
    assign inst_bltz    = op_d[6'b00_0001] && rt_d[5'b00000];
    assign inst_bltzal  = op_d[6'b00_0001] && rt_d[5'b10000];
    assign inst_bgezal  = op_d[6'b00_0001] && rt_d[5'b10001];
    assign inst_jalr    = op_d[6'b00_0000] && func_d[6'b00_1001];
    assign inst_div     = op_d[6'b00_0000] && func_d[6'b01_1010];
    assign inst_divu    = op_d[6'b00_0000] && func_d[6'b01_1011];
    assign inst_mflo    = op_d[6'b00_0000] && func_d[6'b01_0010];
    assign inst_mfhi    = op_d[6'b00_0000] && func_d[6'b01_0000];
    assign inst_mult    = op_d[6'b00_0000] && func_d[6'b01_1000];
    assign inst_multu   = op_d[6'b00_0000] && func_d[6'b01_1001];
    assign inst_mthi    = op_d[6'b00_0000] && func_d[6'b01_0001];
    assign inst_mtlo    = op_d[6'b00_0000] && func_d[6'b01_0011];
    assign inst_lb      = op_d[6'b10_0000];
    assign inst_lbu     = op_d[6'b10_0100];
    assign inst_lh      = op_d[6'b10_0001];
    assign inst_lhu     = op_d[6'b10_0101];
    assign inst_sb      = op_d[6'b10_1000];
    assign inst_sh      = op_d[6'b10_1001];
    assign inst_lsa     = op_d[6'b01_1100] && func_d[6'b11_0111];

    // rs to reg1
    assign sel_alu_src1[0] =inst_sh | inst_sb | inst_lhu | inst_lh | inst_lbu | inst_bgez | inst_srlv | inst_srav | inst_sllv | inst_andi | inst_and | inst_sub | inst_addi | inst_add | inst_sltiu | inst_slti | inst_slt | inst_sltu | inst_sw | inst_nor | inst_xori | inst_xor | inst_ori | inst_addiu | inst_subu | inst_jr | inst_lw | inst_addu | 
                            inst_or   | inst_mflo  |inst_mfhi | inst_lb |inst_lsa;

    // pc to reg1
    assign sel_alu_src1[1] =  inst_jal | inst_bltzal | inst_bgezal |inst_jalr;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] =inst_srl |inst_sra | inst_sll;

    
    // rt to reg2
    assign sel_alu_src2[0] =inst_lsa|inst_mfhi|inst_mflo | inst_srl | inst_srlv | inst_srav | inst_sra | inst_sllv | inst_and | inst_sub | inst_add | inst_slt | inst_sltu | inst_nor | inst_xor  | inst_subu | inst_addu | inst_or | inst_sll |inst_div | inst_divu;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] =inst_sh | inst_sb | inst_lhu | inst_lh | inst_lbu | inst_addi | inst_sltiu | inst_slti | inst_sw | inst_lui | inst_addiu | inst_lw |inst_lb;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = inst_jal | inst_bltzal | inst_bgezal |inst_jalr;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_andi | inst_xori | inst_ori;



    assign op_add =inst_lsa|inst_sh | inst_sb | inst_lhu | inst_lh | inst_lbu |  inst_lb | inst_addi | inst_add | inst_addiu | inst_lw | inst_addu | inst_jal | inst_sw | inst_bltzal |inst_bgezal|inst_jalr;
    assign op_sub =inst_sub | inst_subu;
    assign op_slt = inst_slt | inst_slti; //鏈夌鍙锋瘮杈?
    assign op_sltu = inst_sltu|inst_sltiu;  //鏃犵鍙锋瘮杈?
    assign op_and = inst_andi | inst_and | inst_mflo |inst_mfhi;
    assign op_nor = inst_nor;
    assign op_or = inst_ori | inst_or;
    assign op_xor = inst_xori |inst_xor;
    assign op_sll = inst_sllv | inst_sll;//閫昏緫宸︾Щ
    assign op_srl = inst_srl | inst_srlv;//閫昏緫鍙崇Щ
    assign op_sra = inst_srav | inst_sra;//绠楁湳鍙崇Щ
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};


    // mem load and store enable
    assign data_ram_en =inst_sh | inst_sb | inst_lhu | inst_lh | inst_lbu | inst_lw | inst_sw | inst_lb;

    // mem write enable
    assign data_ram_wen = inst_sw ? 4'b1111 : 4'b0000;

    //mem read enable
    assign data_ram_readen =  inst_lw  ? 4'b1111 
                             :inst_lb  ? 4'b0001 
                             :inst_lbu ? 4'b0010
                             :inst_lh  ? 4'b0011
                             :inst_lhu ? 4'b0100
                             :inst_sb  ? 4'b0101
                             :inst_sh  ? 4'b0111
                             :4'b0000;


    // regfile sotre enable
    assign rf_we =inst_lsa|inst_lhu | inst_lh | inst_lbu | inst_lb| inst_mfhi | inst_mflo | inst_jalr |inst_bgezal | inst_bltzal|inst_srl | inst_srlv | inst_srav | inst_sra | inst_sllv | inst_andi | inst_and | inst_sub | inst_addi | inst_add | inst_sltiu | inst_slti | inst_slt | inst_sltu | inst_nor |inst_xori | inst_xor | inst_sll | inst_ori | inst_lui | inst_addiu | inst_subu | inst_jal | inst_lw | inst_addu | inst_or;



    // store in [rd]
    assign sel_rf_dst[0] = inst_lsa|inst_mfhi | inst_mflo | inst_jalr |inst_srl | inst_srlv | inst_srav | inst_sra | inst_sllv | inst_and | inst_sub | inst_add | inst_slt | inst_sltu | inst_nor | inst_xor | inst_subu | inst_addu | inst_or | inst_sll;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_lhu | inst_lh | inst_lbu | inst_lb |inst_andi | inst_addi | inst_sltiu | inst_slti | inst_xori | inst_ori | inst_lui | inst_addiu | inst_lw;
    // store in [31]
    assign sel_rf_dst[2] = inst_jal | inst_bltzal | inst_bgezal;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;
    
    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = 1'b0; 

    //LSA鎸囦护 鏈?鍚庝竴娆″姞鎸囦护娴嬭瘯鐨勫唴瀹?
    wire [31:0] rdata111;
    assign rdata111 = (inst_lsa &inst[7:6]==2'b11) ? {rdata11[27:0] ,4'b0}
                    :(inst_lsa & inst[7:6]==2'b10) ? {rdata11[28:0] ,3'b0}
                    :(inst_lsa & inst[7:6]==2'b01) ? {rdata11[29:0] ,2'b0}
                    :(inst_lsa & inst[7:6]==2'b00) ? {rdata11[30:0] ,1'b0}
                    :rdata11;

    assign id_to_ex_bus = {
        data_ram_readen,//168:165
        inst_mthi,      //164
        inst_mtlo,      //163
        inst_multu,     //162
        inst_mult,      //161
        inst_divu,      //160
        inst_div,       //159
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rdata111,         // 63:32
        rdata22          // 31:0
    };


    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;
    assign rs_ge_z  = (rdata11[31] == 1'b0); //澶т簬绛変簬0
    assign rs_gt_z  = (rdata11[31] == 1'b0 & rdata11 != 32'b0  );  //澶т簬0
    assign rs_le_z  = (rdata11[31] == 1'b1 | rdata11 == 32'b0  );  //灏忎簬绛変簬0
    assign rs_lt_z  = (rdata11[31] == 1'b1);  //灏忎簬0
    assign rs_eq_rt = (rdata11 == rdata22);
    
    assign br_e =  inst_jalr | (inst_bgezal & rs_ge_z ) | ( inst_bltzal & rs_lt_z) | (inst_bgtz & rs_gt_z  ) | (inst_bltz & rs_lt_z) | (inst_blez & rs_le_z) | (inst_bgez & rs_ge_z ) | (inst_beq & rs_eq_rt) | inst_jr | inst_jal | (inst_bne & !rs_eq_rt) | inst_j ;
    assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) 
                    :(inst_jr |inst_jalr)  ? (rdata11)  
                    : inst_jal ? ({pc_plus_4[31:28],inst[25:0],2'b0}) 
                    : inst_j ? ({pc_plus_4[31:28],inst[25:0],2'b0}) 
                    :(inst_bgezal|inst_bltzal |inst_blez | inst_bltz |inst_bgez |inst_bgtz ) ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b00})
                    :inst_bne ? (pc_plus_4 + {{14{inst[15]}},{inst[15:0],2'b00}}) : 32'b0;

    assign br_bus = {
        br_e,
        br_addr
    };
     


    assign stallreq_from_id = (ex_is_load  & ex_id_waddr == rs) | (ex_is_load & ex_id_waddr == rt) ;
    

endmodule