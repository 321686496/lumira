#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""下载抖音笔记图片到本地(一次性工具, 供 template-builder 收集素材用)。"""
import sys
import os
from pathlib import Path

import requests

URLS = [
    "https://p3-pc-sign.douyinpic.com/tos-cn-i-0813c000-ce/oQARbsgfe0iYCeEQEZBXW0i4AlISwA1EonGAIA~tplv-dy-aweme-images:q75.webp?biz_tag=aweme_images&from=327834062&lk3s=138a59ce&s=PackSourceEnum_AWEME_DETAIL&sc=image&se=false&x-expires=1794124800&x-signature=hUyYJrzgy%2BdVoJPZlkuS10R%2FMEI%3D",
    "https://p3-pc-sign.douyinpic.com/tos-cn-i-0813c000-ce/okeWShleREoZAGbEi04wo0B1isfAAElACI2XAZ~tplv-dy-aweme-images:q75.webp?biz_tag=aweme_images&from=327834062&lk3s=138a59ce&s=PackSourceEnum_AWEME_DETAIL&sc=image&se=false&x-expires=1794124800&x-signature=kbavh3YJ5QZLN0opMq1g68Q9NVk%3D",
    "https://p3-pc-sign.douyinpic.com/tos-cn-i-0813c000-ce/o4hs01AiEiRZloAE4G0AXBlESIjbeWAfwAoiCe~tplv-dy-aweme-images:q75.webp?biz_tag=aweme_images&from=327834062&lk3s=138a59ce&s=PackSourceEnum_AWEME_DETAIL&sc=image&se=false&x-expires=1794124800&x-signature=OdX0%2FAC5KrWXBBV92dhLljM0v%2Fg%3D",
    "https://p3-pc-sign.douyinpic.com/tos-cn-i-0813c000-ce/oka0EejosBAlGbAmA4i1Ee0ACAWwRElSIZfNXi~tplv-dy-aweme-images:q75.webp?biz_tag=aweme_images&from=327834062&lk3s=138a59ce&s=PackSourceEnum_AWEME_DETAIL&sc=image&se=false&x-expires=1794124800&x-signature=GAyoNUIxJSWoEzurASDe%2F%2F4rXxM%3D",
    "https://p3-pc-sign.douyinpic.com/tos-cn-i-0813c000-ce/oIRXe4kn0EeAAAE1GESikC0iIZBAonAWswfclb~tplv-dy-aweme-images:q75.webp?biz_tag=aweme_images&from=327834062&lk3s=138a59ce&s=PackSourceEnum_AWEME_DETAIL&sc=image&se=false&x-expires=1794124800&x-signature=tDN5uhf6kWR0mvTU10OBDYGvvzs%3D",
    "https://p3-pc-sign.douyinpic.com/tos-cn-i-0813c000-ce/o84EAWsfCXM0iEA1E0lleGRBwixAelAboZS6IA~tplv-dy-aweme-images:q75.webp?biz_tag=aweme_images&from=327834062&lk3s=138a59ce&s=PackSourceEnum_AWEME_DETAIL&sc=image&se=false&x-expires=1794124800&x-signature=hwZAbWiKfsKXv%2Fa7G21Fkv459hE%3D",
    "https://p3-pc-sign.douyinpic.com/tos-cn-i-0813c000-ce/ogEAX0WABE4A7web1ZIACiiE0GBERSAkofmsle~tplv-dy-aweme-images:q75.webp?biz_tag=aweme_images&from=327834062&lk3s=138a59ce&s=PackSourceEnum_AWEME_DETAIL&sc=image&se=false&x-expires=1794124800&x-signature=UxX%2B%2FlInnP1gi1chgy9%2FK%2Bx389g%3D",
]

def main() -> int:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("create_templates") / "autumn_maple" / "refs"
    out_dir.mkdir(parents=True, exist_ok=True)
    for i, url in enumerate(URLS, 1):
        try:
            r = requests.get(url, timeout=120, headers={"Referer": "https://www.douyin.com/"})
            r.raise_for_status()
            p = out_dir / f"ref{i}.webp"
            p.write_bytes(r.content)
            print(f"{i}: {len(r.content)//1024}KB -> {p}")
        except Exception as e:
            print(f"{i}: FAIL {e}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
