#!/usr/bin/env bash
# Build the local Wear OS XL Round kernel module. This branch is for AVD use only.
set -euo pipefail
unset CROSS_COMPILE
export ARCH=x86_64 LLVM=1 LLVM_IAS=1
KSRC=/work/common
KDIR=/work/kdir
OUT=/work/out
RELEASE=6.12.58-android16-6-gccafb60de224-ab14828483
mkdir -p "$KSRC" "$KDIR" "$OUT"
tar xzf /work/common.tar.gz -C "$KSRC"
cd "$KSRC"
clang --version

# Resolve module exports at boot through ksuinit, as in the existing DDK workflow.
sed -i -E 's/^([[:space:]]*)check_exports\(mod\);/\1\/\/ check_exports(mod);/' scripts/mod/modpost.c
sed -i -E 's/^([[:space:]]*)s->module = exp->module;/\1\/\/ s->module = exp->module;/' scripts/mod/modpost.c
sed -i 's/^static void check_exports(/static void __attribute__((unused)) check_exports(/' scripts/mod/modpost.c

sed -i 's/__version_ext_names\\") =\\n/__version_ext_names\\") = \\"\\"\\n/' scripts/mod/modpost.c

# Preserve the device's Rust-related CFI code generation when compiling only C modules.
sed -i -E '/^config RUST_IS_AVAILABLE/,/^$/ s/^(\s*def_bool).*/\1 y/' init/Kconfig
sed -i '/^prepare: prepare0/,/^endif/ s/^ifdef CONFIG_RUST$/ifdef CONFIG_RUST_BUILD_SKIPPED_FOR_LKM/' Makefile
sed -i 's/^always-\$(CONFIG_RUST)\(\s*+= target.json\)/always-$(CONFIG_RUST_BUILD_SKIPPED_FOR_LKM)\1/' scripts/Makefile
cp /src/.github/scripts/wear-avd-6.12.58.config "$KDIR/.config"
make O="$KDIR" KERNELRELEASE="$RELEASE" olddefconfig
for option in CONFIG_X86_64=y CONFIG_RUST=y CONFIG_CFI_CLANG=y CONFIG_CFI_ICALL_NORMALIZE_INTEGERS=y CONFIG_LTO_NONE=y; do
    grep -qx "$option" "$KDIR/.config"
done
make O="$KDIR" KERNELRELEASE="$RELEASE" -j4 modules_prepare 2>&1 | tee "$OUT/prepare.log"
make O="$KDIR" KERNELRELEASE="$RELEASE" -j4 security/selinux/built-in.a 2>&1 | tee "$OUT/selinux.log"
git config --global --add safe.directory /src
cd /src/kernel
# The extra public certificate matches the already built local Manager APK.
make -C "$KDIR" M="$PWD" src="$PWD" KERNELRELEASE="$RELEASE" -j4 modules \
    CONFIG_KSU=m CONFIG_KSU_TRACEPOINT_HOOK=y CONFIG_KSU_MULTI_MANAGER_SUPPORT=y \
    CONFIG_KSU_X86_PATCH_SYSCALL_DISPATCHER=y \
    KSU_EXPECTED_SIZE=744 \
    KSU_EXPECTED_HASH=eedbb0dae83ebe813887705c69d9d073b537f761317230f903a4dea1ca876ba5 \
    2>&1 | tee "$OUT/module.log"
llvm-strip -d kernelsu.ko
cp kernelsu.ko "$OUT/kernelsu.ko"
file "$OUT/kernelsu.ko"
modinfo -F vermagic "$OUT/kernelsu.ko"
