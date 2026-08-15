@echo off
setlocal
rem =====================================================================
rem  build.bat -- build firmware ISR tren CMD, khong can 'make'
rem
rem     build.bat            -> firmware_enc.hex    (key DUNG)
rem     build.bat wrong      -> firmware_wrong.hex  (key SAI, de demo)
rem     build.bat all        -> ca hai file tren
rem     build.bat check      -> kiem tra RVC / entry / section / size
rem     build.bat dump       -> disassembly ra man hinh
rem     build.bat clean      -> xoa file trung gian
rem
rem  Chay o dau cung duoc, script tu nhay ve thu muc chua no.
rem =====================================================================

rem ---- Luon lam viec trong thu muc chua build.bat ----------------------
pushd "%~dp0"

rem ---- Doi 1 dong nay neu chuyen toolchain sang cho khac ---------------
set "TC=D:\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64\xpack-riscv-none-elf-gcc-15.2.0-1\bin"

rem ---- PHAI trung voi src\isr_top.v ------------------------------------
set "MODE=3"
set "KEY=0x5A5A5A5A"
set "WRONGKEY=0xDEADBEEF"
set "RAM_WORDS=2048"

set "CC=%TC%\riscv-none-elf-gcc.exe"
set "OBJCOPY=%TC%\riscv-none-elf-objcopy.exe"
set "OBJDUMP=%TC%\riscv-none-elf-objdump.exe"
set "READELF=%TC%\riscv-none-elf-readelf.exe"
set "SIZE=%TC%\riscv-none-elf-size.exe"

rem  -O0 : giu nguyen nop / frame pointer, ma may de doc doi chieu voi
rem        disassembly (giong project test_firm). Doi thanh -Os neu can
rem        nho gon; luc do gcc xoa het nop va bo frame pointer.
set "OPT=-O0"
set "CFLAGS=-march=rv32i -mabi=ilp32 -mno-relax %OPT% -g -ffreestanding -nostdlib -nostartfiles -fno-builtin -fno-pic -ffunction-sections -fdata-sections -Wall -Wextra"
set "LDFLAGS=-T link.ld -Wl,--gc-sections -Wl,-Map,firmware.map"
set "SRCS=start.S main.c"

rem ---- Kiem tra toolchain ---------------------------------------------
if not exist "%CC%" (
  echo [FAIL] Khong thay "%CC%"
  echo        Sua bien TC o dau file build.bat cho dung duong dan toolchain.
  goto :err
)

rem ---- Tim python ------------------------------------------------------
set "PY="
python --version >nul 2>&1 && set "PY=python"
if not defined PY py -3 --version >nul 2>&1 && set "PY=py -3"
if not defined PY (
  echo [FAIL] Khong tim thay python trong PATH.
  echo        Cai Python 3 hoac them no vao PATH roi chay lai.
  goto :err
)

if /i "%~1"=="clean" goto :clean
if /i "%~1"=="dump"  goto :dump
if /i "%~1"=="check" goto :check

rem ---- Kiem tra file nguon --------------------------------------------
for %%F in (start.S main.c link.ld bin2hex.py isr_encoder.py) do (
  if not exist "%%F" (
    echo [FAIL] Thieu file "%%F" trong "%CD%"
    goto :err
  )
)

rem ---- 1. Bien dich ----------------------------------------------------
echo [1/4] Bien dich %SRCS% ...
"%CC%" %CFLAGS% %LDFLAGS% -o firmware.elf %SRCS%
if errorlevel 1 goto :err
"%SIZE%" firmware.elf

rem ---- 2. Trich ma may (khong gom .bss vi da NOLOAD) --------------------
echo [2/4] Trich ma may -^> firmware.bin ...
"%OBJCOPY%" -O binary firmware.elf firmware.bin
if errorlevel 1 goto :err

rem ---- 3. bin -> hex (dang '@' + 4 word/dong) --------------------------
echo [3/4] Doi sang firmware.hex ^(danh dau '@' o dau moi section^) ...
%PY% bin2hex.py firmware.bin firmware.hex %RAM_WORDS% --elf firmware.elf
if errorlevel 1 goto :err

rem ---- 4. Ma hoa ISR ---------------------------------------------------
if /i "%~1"=="wrong" goto :enc_wrong
if /i "%~1"=="all"   goto :enc_all

:enc_right
echo [4/4] Ma hoa bang key DUNG %KEY% ...
%PY% isr_encoder.py firmware.hex firmware_enc.hex --mode %MODE% --key %KEY% --from-elf firmware.elf
if errorlevel 1 goto :err
echo.
echo ^>^>^> Xong: firmware_enc.hex
echo ^>^>^> RAM_INIT trong ..\src\isr_top.v phai tro vao file nay,
echo ^>^>^> va ISR_MODE=%MODE%, ISR_KEY=%KEY%.
goto :done

:enc_wrong
echo [4/4] Ma hoa bang key SAI %WRONGKEY% ...
%PY% isr_encoder.py firmware.hex firmware_wrong.hex --mode %MODE% --key %WRONGKEY% --from-elf firmware.elf
if errorlevel 1 goto :err
echo.
echo ^>^>^> Xong: firmware_wrong.hex
echo ^>^>^> Doi RAM_INIT trong ..\src\isr_top.v sang file nay roi build lai FPGA.
echo ^>^>^> Ket qua mong doi: terminal im lang, LED tat.
goto :done

:enc_all
echo [4/4] Ma hoa ca hai key ...
%PY% isr_encoder.py firmware.hex firmware_enc.hex   --mode %MODE% --key %KEY%      --from-elf firmware.elf
if errorlevel 1 goto :err
%PY% isr_encoder.py firmware.hex firmware_wrong.hex --mode %MODE% --key %WRONGKEY% --from-elf firmware.elf
if errorlevel 1 goto :err
echo.
echo ^>^>^> Xong: firmware_enc.hex ^(key dung^) va firmware_wrong.hex ^(key sai^)
goto :done

rem ---------------------------------------------------------------------
:check
if not exist firmware.elf (
  echo [FAIL] Chua co firmware.elf -- chay "build.bat" truoc da.
  goto :err
)
echo === 1. Co lenh nen 16-bit ^(RVC^) khong? ===
"%READELF%" -h firmware.elf | findstr /i "Flags"
echo   ^(KHONG duoc thay chu RVC^)
echo.
echo === 2. Entry point phai la 0x0 ===
"%READELF%" -h firmware.elf | findstr /i "Entry"
echo.
echo === 3. Section: chi cai co co 'X' moi bi ma hoa ===
"%READELF%" -S firmware.elf | findstr /i "text rodata data bss"
echo   .text  phai co  X        -^> se ma hoa
echo   .rodata KHONG duoc co X  -^> giu nguyen
echo.
echo === 4. Kich thuoc ===
"%SIZE%" firmware.elf
goto :done

rem ---------------------------------------------------------------------
:dump
if not exist firmware.elf (
  echo [FAIL] Chua co firmware.elf -- chay "build.bat" truoc da.
  goto :err
)
"%OBJDUMP%" -d -S firmware.elf
goto :done

rem ---------------------------------------------------------------------
:clean
del /q firmware.elf firmware.bin firmware.hex firmware.map 2>nul
echo [OK] Da xoa file trung gian ^(giu lai *_enc.hex / *_wrong.hex^).
goto :done

rem ---------------------------------------------------------------------
:done
popd
endlocal
exit /b 0

:err
echo.
echo [FAIL] Build dung lai vi loi o tren.
popd
endlocal
exit /b 1
