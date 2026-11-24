@echo off

pushd "%~dp0.."
set VIVADO_BIN=C:\Xilinx\Vivado\2024.2\bin

echo === Compiling Arithmetic Modules ===
call "%VIVADO_BIN%\xvlog.bat" -nolog -sv ^
    rtl\arithmetic\mod_add.v ^
    rtl\arithmetic\mod_sub.v ^
    rtl\arithmetic\mod_mul.v ^
    tb\unit\tb_arithmetic.v
if errorlevel 1 (
    echo FAIL: Compilation failed
    popd
    exit /b 1
)

echo === Elaborating ===
call "%VIVADO_BIN%\xelab.bat" -nolog -debug off tb_arithmetic -s tb_arith_sim
if errorlevel 1 (
    echo FAIL: Elaboration failed
    popd
    exit /b 1
)

echo === Running Simulation ===
call "%VIVADO_BIN%\xsim.bat" -nolog tb_arith_sim -runall
if errorlevel 1 (
    echo FAIL: Simulation failed
    popd
    exit /b 1
)

echo === Done ===
popd
