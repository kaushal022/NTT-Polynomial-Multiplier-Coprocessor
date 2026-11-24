; ModuleID = 'N:/hls/prj_butterfly_var1/solution1/.autopilot/db/a.g.ld.5.gdce.bc'
source_filename = "llvm-link"
target datalayout = "e-m:e-i64:64-i128:128-i256:256-i512:512-i1024:1024-i2048:2048-i4096:4096-n8:16:32:64-S128-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "fpga64-xilinx-none"

%"struct.ap_uint<1>" = type { %"struct.ap_int_base<1, false>" }
%"struct.ap_int_base<1, false>" = type { %"struct.ssdm_int<1, false>" }
%"struct.ssdm_int<1, false>" = type { i1 }
%"struct.ap_uint<12>" = type { %"struct.ap_int_base<12, false>" }
%"struct.ap_int_base<12, false>" = type { %"struct.ssdm_int<12, false>" }
%"struct.ssdm_int<12, false>" = type { i12 }

; Function Attrs: inaccessiblemem_or_argmemonly noinline willreturn
define void @apatb_butterfly_hls_ir(%"struct.ap_uint<12>"* nocapture readonly %a, %"struct.ap_uint<12>"* nocapture readonly %b, %"struct.ap_uint<12>"* nocapture readonly %w, %"struct.ap_uint<1>"* nocapture readonly %mode, %"struct.ap_uint<12>"* noalias nocapture nonnull dereferenceable(2) %out_lo, %"struct.ap_uint<12>"* noalias nocapture nonnull dereferenceable(2) %out_hi) local_unnamed_addr #0 {
entry:
  %out_lo_copy = alloca i12, align 512
  %out_hi_copy = alloca i12, align 512
  call fastcc void @copy_in(%"struct.ap_uint<12>"* nonnull %out_lo, i12* nonnull align 512 %out_lo_copy, %"struct.ap_uint<12>"* nonnull %out_hi, i12* nonnull align 512 %out_hi_copy)
  call void @apatb_butterfly_hls_hw(%"struct.ap_uint<12>"* %a, %"struct.ap_uint<12>"* %b, %"struct.ap_uint<12>"* %w, %"struct.ap_uint<1>"* %mode, i12* %out_lo_copy, i12* %out_hi_copy)
  call void @copy_back(%"struct.ap_uint<12>"* %out_lo, i12* %out_lo_copy, %"struct.ap_uint<12>"* %out_hi, i12* %out_hi_copy)
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @copy_in(%"struct.ap_uint<12>"* noalias readonly "unpacked"="0", i12* noalias nocapture align 512 "unpacked"="1.0", %"struct.ap_uint<12>"* noalias readonly "unpacked"="2", i12* noalias nocapture align 512 "unpacked"="3.0") unnamed_addr #1 {
entry:
  call fastcc void @"onebyonecpy_hls.p0struct.ap_uint<12>.21"(i12* align 512 %1, %"struct.ap_uint<12>"* %0)
  call fastcc void @"onebyonecpy_hls.p0struct.ap_uint<12>.21"(i12* align 512 %3, %"struct.ap_uint<12>"* %2)
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @copy_out(%"struct.ap_uint<12>"* noalias "unpacked"="0", i12* noalias nocapture readonly align 512 "unpacked"="1.0", %"struct.ap_uint<12>"* noalias "unpacked"="2", i12* noalias nocapture readonly align 512 "unpacked"="3.0") unnamed_addr #2 {
entry:
  call fastcc void @"onebyonecpy_hls.p0struct.ap_uint<12>"(%"struct.ap_uint<12>"* %0, i12* align 512 %1)
  call fastcc void @"onebyonecpy_hls.p0struct.ap_uint<12>"(%"struct.ap_uint<12>"* %2, i12* align 512 %3)
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @"onebyonecpy_hls.p0struct.ap_uint<12>"(%"struct.ap_uint<12>"* noalias "unpacked"="0" %dst, i12* noalias nocapture readonly align 512 "unpacked"="1.0" %src) unnamed_addr #3 {
entry:
  %0 = icmp eq %"struct.ap_uint<12>"* %dst, null
  br i1 %0, label %ret, label %copy

copy:                                             ; preds = %entry
  %dst.0.0.04 = getelementptr %"struct.ap_uint<12>", %"struct.ap_uint<12>"* %dst, i64 0, i32 0, i32 0, i32 0
  %1 = bitcast i12* %src to i16*
  %2 = load i16, i16* %1
  %3 = trunc i16 %2 to i12
  store i12 %3, i12* %dst.0.0.04, align 2
  br label %ret

ret:                                              ; preds = %copy, %entry
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @"onebyonecpy_hls.p0struct.ap_uint<12>.21"(i12* noalias nocapture align 512 "unpacked"="0.0" %dst, %"struct.ap_uint<12>"* noalias readonly "unpacked"="1" %src) unnamed_addr #3 {
entry:
  %0 = icmp eq %"struct.ap_uint<12>"* %src, null
  br i1 %0, label %ret, label %copy

copy:                                             ; preds = %entry
  %src.0.0.03 = getelementptr %"struct.ap_uint<12>", %"struct.ap_uint<12>"* %src, i64 0, i32 0, i32 0, i32 0
  %1 = bitcast i12* %src.0.0.03 to i16*
  %2 = load i16, i16* %1
  %3 = trunc i16 %2 to i12
  store i12 %3, i12* %dst, align 512
  br label %ret

ret:                                              ; preds = %copy, %entry
  ret void
}

declare i8* @malloc(i64)

declare void @free(i8*)

declare void @apatb_butterfly_hls_hw(%"struct.ap_uint<12>"*, %"struct.ap_uint<12>"*, %"struct.ap_uint<12>"*, %"struct.ap_uint<1>"*, i12*, i12*)

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @copy_back(%"struct.ap_uint<12>"* noalias "unpacked"="0", i12* noalias nocapture readonly align 512 "unpacked"="1.0", %"struct.ap_uint<12>"* noalias "unpacked"="2", i12* noalias nocapture readonly align 512 "unpacked"="3.0") unnamed_addr #2 {
entry:
  call fastcc void @"onebyonecpy_hls.p0struct.ap_uint<12>"(%"struct.ap_uint<12>"* %0, i12* align 512 %1)
  call fastcc void @"onebyonecpy_hls.p0struct.ap_uint<12>"(%"struct.ap_uint<12>"* %2, i12* align 512 %3)
  ret void
}

declare void @butterfly_hls_hw_stub(%"struct.ap_uint<12>"* nocapture readonly, %"struct.ap_uint<12>"* nocapture readonly, %"struct.ap_uint<12>"* nocapture readonly, %"struct.ap_uint<1>"* nocapture readonly, %"struct.ap_uint<12>"* noalias nocapture nonnull, %"struct.ap_uint<12>"* noalias nocapture nonnull)

define void @butterfly_hls_hw_stub_wrapper(%"struct.ap_uint<12>"*, %"struct.ap_uint<12>"*, %"struct.ap_uint<12>"*, %"struct.ap_uint<1>"*, i12*, i12*) #4 {
entry:
  %6 = call i8* @malloc(i64 2)
  %7 = bitcast i8* %6 to %"struct.ap_uint<12>"*
  %8 = call i8* @malloc(i64 2)
  %9 = bitcast i8* %8 to %"struct.ap_uint<12>"*
  call void @copy_out(%"struct.ap_uint<12>"* %7, i12* %4, %"struct.ap_uint<12>"* %9, i12* %5)
  call void @butterfly_hls_hw_stub(%"struct.ap_uint<12>"* %0, %"struct.ap_uint<12>"* %1, %"struct.ap_uint<12>"* %2, %"struct.ap_uint<1>"* %3, %"struct.ap_uint<12>"* %7, %"struct.ap_uint<12>"* %9)
  call void @copy_in(%"struct.ap_uint<12>"* %7, i12* %4, %"struct.ap_uint<12>"* %9, i12* %5)
  call void @free(i8* %6)
  call void @free(i8* %8)
  ret void
}

attributes #0 = { inaccessiblemem_or_argmemonly noinline willreturn "fpga.wrapper.func"="wrapper" }
attributes #1 = { argmemonly noinline norecurse willreturn "fpga.wrapper.func"="copyin" }
attributes #2 = { argmemonly noinline norecurse willreturn "fpga.wrapper.func"="copyout" }
attributes #3 = { argmemonly noinline norecurse willreturn "fpga.wrapper.func"="onebyonecpy_hls" }
attributes #4 = { "fpga.wrapper.func"="stub" }

!llvm.dbg.cu = !{}
!llvm.ident = !{!0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0}
!llvm.module.flags = !{!1, !2, !3}
!blackbox_cfg = !{!4}

!0 = !{!"clang version 7.0.0 "}
!1 = !{i32 2, !"Dwarf Version", i32 4}
!2 = !{i32 2, !"Debug Info Version", i32 3}
!3 = !{i32 1, !"wchar_size", i32 4}
!4 = !{}
