# -*- coding: utf-8 -*-
from docx import Document
import re

doc = Document(r'd:\app\projects\photo_post\软件著作权\docx\04-源代码说明文档-精简版.docx')
print(f'段落数: {len(doc.paragraphs)}')

# 检查页码标记
pages = []
for i, p in enumerate(doc.paragraphs):
    t = p.text.strip()
    if re.match(r'^第\s*\d+\s*页$', t):
        pages.append(t)
print(f'页码标记数: {len(pages)}')
if pages:
    print(f'页码范围: {pages[0]} ~ {pages[-1]}')

# 检查每页行数
page_starts = [i for i, p in enumerate(doc.paragraphs) if re.match(r'^第\s*\d+\s*页$', p.text.strip())]
for idx in range(min(5, len(page_starts))):
    start = page_starts[idx]
    end = page_starts[idx+1] if idx+1 < len(page_starts) else len(doc.paragraphs)
    lines = sum(1 for p in doc.paragraphs[start:end] if p.text.strip())
    print(f'第{idx+1}页: {lines}行（含页眉页码）')

# 检查第一部分
for i, p in enumerate(doc.paragraphs):
    if p.text.strip().startswith('第二部分'):
        print(f'第一部分段落数: {i}')
        break

# 检查最后几页
print(f'\n最后3页:')
for i, p in enumerate(doc.paragraphs[-10:]):
    print(f'  [{len(doc.paragraphs)-10+i}] {p.text[:80]}')
