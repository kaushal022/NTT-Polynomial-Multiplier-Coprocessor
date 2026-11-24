@echo off
setlocal
echo =====================================================================
echo  Launching ML-KEM NTT Coprocessor FSM Encoding Benchmarks
echo =====================================================================
python "%~dp0run_fsm_exploration.py" %*
pause
