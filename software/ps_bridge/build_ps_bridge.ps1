$ErrorActionPreference = "Stop"
$CLANG = "C:\Xilinx\Vitis\2024.2\tps\win64\clang-8.0.0\bin\clang.exe"
$LLD   = "C:\Xilinx\Vitis\2024.2\tps\win64\clang-8.0.0\bin\ld.lld.exe"
$OBJD  = "C:\Xilinx\Vitis\2024.2\tps\win64\clang-8.0.0\bin\llvm-objdump.exe"

$DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $DIR

try {
    & $CLANG --target=armv7a-none-eabihf -mcpu=cortex-a9 -mfloat-abi=soft `
        -fno-unwind-tables -fno-asynchronous-unwind-tables `
        -ffreestanding -nostdlib -O2 -c start.S -o start.o
    if ($LASTEXITCODE -ne 0) { throw "Failed assembling start.S" }

    & $CLANG --target=armv7a-none-eabihf -mcpu=cortex-a9 -mfloat-abi=soft `
        -fno-unwind-tables -fno-asynchronous-unwind-tables `
        -ffreestanding -nostdlib -O2 -Wall -Wextra -Werror -c main.c -o main.o
    if ($LASTEXITCODE -ne 0) { throw "Failed compiling main.c" }

    & $LLD -T link.ld start.o main.o -o ps_bridge.elf
    if ($LASTEXITCODE -ne 0) { throw "Failed linking ps_bridge.elf" }

    Write-Host "Successfully built software/ps_bridge/ps_bridge.elf:"
    & $OBJD -h ps_bridge.elf
} finally {
    Pop-Location
}
