//======================================================================
//  isr.sdc -- Timing Constraints  (Gowin)
//  Board  : Sipeed Tang Nano 4K -- thach anh 27 MHz
//  Top    : isr_top
//
//  27 MHz  ->  chu ky = 1/27e6 = 37.037 ns,  duty 50% => canh len 18.518
//======================================================================

create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}]


//----------------------------------------------------------------------
//  Cac chan bat dong bo -- khong rang buoc timing
//----------------------------------------------------------------------
//  sys_rst_n : nut bam co doi (bounce), trong isr_top da di qua bo dong
//              bo 2 FF (rst_sync) roi moi dung => khong can rang buoc.
set_false_path -from [get_ports {sys_rst_n}]

//  led : nguoi nhin bang mat, tre vai ns khong co y nghia gi.
set_false_path -to [get_ports {led}]

//  Neu ban Gowin IDE bao loi cu phap o 2 dong set_false_path tren
//  (mot so ban cu khong nhan -from/-to voi get_ports), cu xoa di --
//  chung chi de lam sach bao cao timing, khong anh huong chuc nang.


//======================================================================
//  GHI CHU VE DUONG TOI HAN  --  doc truoc khi debug "LED khong nhay"
//======================================================================
//
//  Duong dai nhat cua thiet ke la:
//
//      picorv32.mem_addr  ->  isr_decoder (u_key)  ->  key_eff_q
//
//  Voi ISR_MODE = 3 duong nay gom 3 vong PRF noi tiep:
//      3 x [ S-box 4-bit (1 tang LUT4) + rotl/XOR khuech tan (2 tang) ]
//      + XOR tron khoa
//  ~ 10-13 tang LUT4. O 37 ns thuong VAN DAT tren GW1NSR-4C.
//
//  Trong isr_top.v, key_eff DA duoc cho qua thanh ghi (key_eff_q) nen
//  duong tro ve chan mem_rdata cua CPU chi con 1 tang XOR:
//
//      Chu ky N   : mem_addr on dinh -> tinh key_eff (tron 1 chu ky)
//      Chu ky N+1 : ram_rdata ^ key_eff_q -> mem_rdata
//
//  --------------------------------------------------------------
//  NEU TIMING ANALYZER VAN BAO TRUOT (negative slack), theo thu tu:
//  --------------------------------------------------------------
//
//  1) Xac nhan la trap hay la timing:
//     Build lai voi ISR_MODE = 1. Neu MODE 1 chay ma MODE 3 khong chay
//     => la LOI TIMING, khong phai loi ma hoa.
//
//  2) Tinh key_eff som hon 1 chu ky bang look-ahead interface:
//     Trong isr_top.v, noi them mem_la_addr tu picorv32 va lai
//     u_key.addr bang mem_la_addr thay vi mem_addr. Nhu vay duong PRF
//     duoc 2 chu ky (74 ns) thay vi 1. Day la cach sach nhat.
//     LUU Y: chi doi dau vao cua u_key, KHONG doi cho khac.
//
//  3) Chen thanh ghi pipeline giua 3 vong PRF trong isr_prf_round
//     (them 2 chu ky tre moi lan fetch -- phai sua ca handshake
//      mem_ready trong isr_ram).
//
//  4) Cuoi cung moi ha xung nhip: chia 2 con 13.5 MHz.
//     Khi do sua lai dong create_clock ben tren thanh period 74.074
//     va chinh he so delay trong firmware cho LED van nhay ~1 Hz.
//
//======================================================================
