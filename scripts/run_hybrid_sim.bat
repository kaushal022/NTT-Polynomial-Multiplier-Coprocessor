@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJ_DIR=%%~fI"
set "SIM_DIR=%TEMP%\mlkem_hybrid_xsim"
set "VIVADO_BIN=C:\Xilinx\Vivado\2024.2\bin"

if not exist "%SIM_DIR%" mkdir "%SIM_DIR%"
pushd "%SIM_DIR%"

copy /Y "%PROJ_DIR%\rtl\soc\firmware_hybrid.hex" "%SIM_DIR%\firmware_hybrid.hex" >nul
copy /Y "%PROJ_DIR%\tb\vectors\tv4_input.hex" "%SIM_DIR%\tv4_input.hex" >nul
copy /Y "%PROJ_DIR%\tb\vectors\tv5_input.hex" "%SIM_DIR%\tv5_input.hex" >nul
copy /Y "%PROJ_DIR%\tb\vectors\tv_polymul_result.hex" "%SIM_DIR%\tv_polymul_result.hex" >nul

call "%VIVADO_BIN%\xvlog.bat" -nolog ^
  "%PROJ_DIR%\rtl\arithmetic\mod_add.v" ^
  "%PROJ_DIR%\rtl\arithmetic\mod_sub.v" ^
  "%PROJ_DIR%\rtl\arithmetic\mod_mul.v" ^
  "%PROJ_DIR%\rtl\arithmetic\basemul.v" ^
  "%PROJ_DIR%\rtl\butterfly\butterfly.v" ^
  "%PROJ_DIR%\rtl\memory\poly_bram.v" ^
  "%PROJ_DIR%\rtl\memory\twiddle_rom.v" ^
  "%PROJ_DIR%\rtl\ntt\ntt_addr_gen.v" ^
  "%PROJ_DIR%\rtl\ntt\ntt_engine.v" ^
  "%PROJ_DIR%\rtl\ntt\poly_multiplier.v" ^
  "%PROJ_DIR%\rtl\axi\axi_lite_coprocessor.v" ^
  "%PROJ_DIR%\rtl\dma\ntt_dma.v" ^
  "%PROJ_DIR%\rtl\interrupt\interrupt_ctrl.v" ^
  "%PROJ_DIR%\rtl\mlkem_dma_coproc_top.v" ^
  "%PROJ_DIR%\rtl\soc\picorv32.v" ^
  "%PROJ_DIR%\rtl\soc\simpleuart.v" ^
  "%PROJ_DIR%\rtl\soc\axi_mailbox.v" ^
  "%PROJ_DIR%\rtl\soc\axi_arbiter_2m.v" ^
  "%PROJ_DIR%\rtl\soc\axi_demux_4s.v" ^
  "%PROJ_DIR%\rtl\soc\pl_hybrid_soc.v" ^
  "%PROJ_DIR%\tb\integration\tb_hybrid_soc_top.v"
if errorlevel 1 (
    popd
    exit /b 1
)

call "%VIVADO_BIN%\xelab.bat" -nolog -debug typical tb_hybrid_soc_top -s tb_hybrid_sim
if errorlevel 1 (
    popd
    exit /b 1
)

> run_sim.tcl echo run all
>> run_sim.tcl echo quit

call "%VIVADO_BIN%\xsim.bat" -nolog tb_hybrid_sim -tclbatch run_sim.tcl
set "EC=%ERRORLEVEL%"
popd
exit /b %EC%
