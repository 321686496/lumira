#!/bin/sh
# 注入 Apple 隐私清单（PrivacyInfo.xcprivacy）到缺失清单的 framework 构建产物。
#
# 背景：Apple 要求"常用第三方 SDK"（ITMS-91061）必须自带隐私清单，否则
# 上传 TestFlight / App Store 会被拒。本项目锁定 Flutter 3.7.12 / Dart 2.19.6
# （鸿蒙兼容），无法升级到自带清单的插件版本，故在构建期注入。
#
# 时机：本脚本作为 Runner target 的 Run Script 阶段，在所有 Pods 依赖构建
# 完成后、[CP] Embed Pods Frameworks 之前执行。Podfile 使用 use_frameworks!
# （动态框架），CocoaPods embed 阶段会把 BUILT_PRODUCTS_DIR 下的每个
# framework 拷入 app 并重新 codesign，因此注入后的 framework 签名有效。
set -e

MANIFEST_SRC="${SRCROOT}/Scripts/PrivacyInfo.xcprivacy"

if [ ! -f "${MANIFEST_SRC}" ]; then
    echo "error: PrivacyInfo.xcprivacy 模板不存在: ${MANIFEST_SRC}"
    exit 1
fi

echo "PrivacyManifest: scanning ${BUILT_PRODUCTS_DIR}"

INJECTED=0
for FRAMEWORK in "${BUILT_PRODUCTS_DIR}"/*.framework; do
    [ -d "${FRAMEWORK}" ] || continue
    if [ -f "${FRAMEWORK}/PrivacyInfo.xcprivacy" ]; then
        echo "PrivacyManifest: $(basename "${FRAMEWORK}") 已有清单，跳过"
        continue
    fi
    cp "${MANIFEST_SRC}" "${FRAMEWORK}/PrivacyInfo.xcprivacy"
    echo "PrivacyManifest: 已注入 $(basename "${FRAMEWORK}")"
    INJECTED=$((INJECTED + 1))
done

echo "PrivacyManifest: 本次共注入 ${INJECTED} 个 framework"
