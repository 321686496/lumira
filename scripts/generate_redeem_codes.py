#!/usr/bin/env python3
"""Batch-generate FitTrack redeem codes (HMAC-SHA256 signed).

Usage: python scripts/generate_redeem_codes.py [count] [secret_index]

The generated codes can be redeemed in the app via Settings → 兑换 Pro.
"""
import hmac
import hashlib
import random
import string
import sys

SECRETS = [
    'fitTrack_secret_v1_2025',
    'fitTrack_secret_v2_2026',
]


def generate_code(secret: str) -> str:
    rand_part = ''.join(
        random.choices(string.ascii_uppercase + string.digits, k=8))
    content = f'{rand_part[:4]}-{rand_part[4:]}'
    sig = hmac.new(
        secret.encode(), content.encode(), hashlib.sha256
    ).hexdigest()[:4].upper()
    return f'FITT-{content[:4]}-{content[5:]}-{sig}'


if __name__ == '__main__':
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    secret_idx = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    secret = SECRETS[secret_idx]
    codes = [generate_code(secret) for _ in range(count)]
    for c in codes:
        print(c)
    print(f'\n总计 {len(codes)} 个兑换码已生成（密钥 v{secret_idx + 1}）',
          file=sys.stderr)
