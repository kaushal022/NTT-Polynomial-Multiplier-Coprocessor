@echo off
pushd "%~dp0.."
set VIVADO_BIN=C:\Xilinx\Vivado\2024.2\bin

echo =================================================================
echo   Running ML-KEM Coprocessor 100 Random Vector Regression
echo =================================================================

call "%VIVADO_BIN%\xvlog.bat" -nolog -sv ^
  rtl/memory/poly_bram.v ^
  rtl/memory/twiddle_rom.v ^
  rtl/arithmetic/mod_add.v ^
  rtl/arithmetic/mod_sub.v ^
  rtl/arithmetic/mod_mul.v ^
  rtl/arithmetic/basemul.v ^
  rtl/butterfly/butterfly.v ^
  rtl/ntt/ntt_addr_gen.v ^
  rtl/ntt/ntt_engine.v ^
  rtl/ntt/poly_multiplier.v ^
  tb/regression/tb_regression_100.v
if %ERRORLEVEL% NEQ 0 (
    echo Compilation Failed!
    popd
    exit /b %ERRORLEVEL%
)

call "%VIVADO_BIN%\xelab.bat" -nolog -debug off tb_regression_100 -s tb_regression_100_sim
if %ERRORLEVEL% NEQ 0 (
    echo Elaboration Failed!
    popd
    exit /b %ERRORLEVEL%
)

call "%VIVADO_BIN%\xsim.bat" -nolog tb_regression_100_sim -runall
if %ERRORLEVEL% NEQ 0 (
    echo Simulation Failed!
    popd
    exit /b %ERRORLEVEL%
)

echo =================================================================
echo   Regression Completed Successfully!
echo =================================================================
popd
