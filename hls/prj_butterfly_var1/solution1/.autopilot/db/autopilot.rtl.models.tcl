set SynModuleInfo {
  {SRCNAME mod_mul MODELNAME mod_mul RTLNAME butterfly_hls_mod_mul
    SUBMODULES {
      {MODELNAME butterfly_hls_mul_12ns_12ns_24_1_0 RTLNAME butterfly_hls_mul_12ns_12ns_24_1_0 BINDTYPE op TYPE mul IMPL auto LATENCY 0 ALLOW_PRAGMA 1}
      {MODELNAME butterfly_hls_mul_24ns_14ns_37_1_0 RTLNAME butterfly_hls_mul_24ns_14ns_37_1_0 BINDTYPE op TYPE mul IMPL auto LATENCY 0 ALLOW_PRAGMA 1}
      {MODELNAME butterfly_hls_mac_muladd_13s_13s_13ns_13_4_0 RTLNAME butterfly_hls_mac_muladd_13s_13s_13ns_13_4_0 BINDTYPE op TYPE all IMPL dsp_slice LATENCY 3}
    }
  }
  {SRCNAME butterfly_hls MODELNAME butterfly_hls RTLNAME butterfly_hls IS_TOP 1}
}
