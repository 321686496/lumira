#!/usr/bin/env python3
"""将 libsqlite3.so 注入到 unsigned HAP 中，并重新打包为 signed HAP。"""
import zipfile
import os
import shutil
import stat

HAP_DIR = r"d:\app\projects\photo_post\lumira_app_flutter\ohos\entry\build\default\outputs\default"
UNSIGNED_HAP = os.path.join(HAP_DIR, "entry-default-unsigned.hap")
SIGNED_HAP = os.path.join(HAP_DIR, "entry-default-signed.hap")
MODIFIED_HAP = os.path.join(HAP_DIR, "entry-default-modified.hap")
SO_SOURCE = r"d:\app\projects\photo_post\lumira_app_flutter\libsqlite3.so"

def ensure_executable(path):
    """确保文件在 zip 存储时有可执行权限位。"""
    st = os.stat(path)
    os.chmod(path, st.st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

def inject_so(source_hap, output_hap, so_path, target_in_hap):
    """将 .so 注入到 HAP 中。"""
    print(f"Source HAP: {source_hap}")
    print(f"SO source: {so_path}")
    print(f"Target in HAP: {target_in_hap}")
    print(f"Output HAP: {output_hap}")
    
    # 确保 .so 有可执行权限
    ensure_executable(so_path)
    
    # 读取 .so 内容
    with open(so_path, "rb") as f:
        so_data = f.read()
    print(f"SO size: {len(so_data)} bytes")
    
    # 复制原 HAP 并添加 .so
    if os.path.exists(output_hap):
        os.remove(output_hap)
    
    with zipfile.ZipFile(source_hap, "r") as zin:
        with zipfile.ZipFile(output_hap, "w", zipfile.ZIP_DEFLATED) as zout:
            # 复制所有原文件
            for item in zin.infolist():
                data = zin.read(item.filename)
                zout.writestr(item, data)
            # 添加 libsqlite3.so
            info = zipfile.ZipInfo(target_in_hap)
            info.external_attr = (stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH) << 16
            zout.writestr(info, so_data)
            print(f"Added {target_in_hap} to HAP")
    
    print(f"Modified HAP: {output_hap}")
    print(f"Size: {os.path.getsize(output_hap)} bytes")
    return output_hap

if __name__ == "__main__":
    # 先修改 unsigned HAP
    modified = inject_so(UNSIGNED_HAP, MODIFIED_HAP, SO_SOURCE, "libs/x86_64/libsqlite3.so")
    print(f"\nDone! Modified HAP: {modified}")
    print(f"Size: {os.path.getsize(modified)} bytes")
