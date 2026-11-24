<AutoPilot:project xmlns:AutoPilot="com.autoesl.autopilot.project" top="butterfly_hls" name="prj_butterfly_var1" ideType="classic">
    <files>
        <file name="butterfly.cpp" sc="0" tb="false" cflags="-DVARIANT=1" csimflags="" blackbox="false"/>
        <file name="../../butterfly_tb.cpp" sc="0" tb="1" cflags="-DVARIANT=1 -Wno-unknown-pragmas" csimflags="" blackbox="false"/>
    </files>
    <solutions>
        <solution name="solution1" status=""/>
    </solutions>
    <Simulation argv="">
        <SimFlow name="csim" setup="false" optimizeCompile="false" clean="false" ldflags="" mflags=""/>
    </Simulation>
</AutoPilot:project>

