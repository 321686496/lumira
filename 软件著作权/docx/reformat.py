# -*- coding: utf-8 -*-
"""
重新格式化源代码说明文档，使每页恰好50行，共60页
解决原文档因字体/行距不当导致展开为150+页的问题
"""
from docx import Document
from docx.shared import Pt, Cm, Emu
from docx.oxml.ns import qn
from docx.enum.text import WD_ALIGN_PARAGRAPH
import re

SRC = r'd:\app\projects\photo_post\软件著作权\docx\04-源代码说明文档.docx'
DST = r'd:\app\projects\photo_post\软件著作权\docx\04-源代码说明文档-精简版.docx'

# 读取原文档
doc = Document(SRC)

# 提取所有段落文本（保留结构信息）
paragraphs = []
for p in doc.paragraphs:
    text = p.text
    style_name = p.style.name if p.style else 'Normal'
    # 检测是否是代码行（以特定前缀开头）
    is_code = bool(re.match(r'^\s*\d+\s', text)) or text.strip().startswith('│') or text.strip().startswith('├──') or text.strip().startswith('│   │')
    # 检测是否是模块标题
    is_module = '模块' in text and '：' in text and len(text) < 80
    # 检测是否是页码标记
    is_page_num = bool(re.match(r'^第\s*\d+\s*页$', text.strip()))
    # 检测是否是页眉标记
    is_header = '如画 Lumira' in text and '第' in text and '页' in text
    
    paragraphs.append({
        'text': text,
        'style': style_name,
        'is_code': is_code,
        'is_module': is_module,
        'is_page_num': is_page_num,
        'is_header': is_header,
    })

print(f'原文档段落数: {len(paragraphs)}')

# 创建新文档
new_doc = Document()

# 设置页面格式
section = new_doc.sections[0]
section.page_width = Cm(21)
section.page_height = Cm(29.7)
section.top_margin = Cm(2.2)
section.bottom_margin = Cm(2.2)
section.left_margin = Cm(2.5)
section.right_margin = Cm(2.5)

# 设置默认样式
style = new_doc.styles['Normal']
style.font.name = '宋体'
style.font.size = Pt(10)
style.paragraph_format.line_spacing = 1.15
style.paragraph_format.space_before = Pt(0)
style.paragraph_format.space_after = Pt(0)

# 设置中文字体
rpr = style.element.get_or_add_rPr()
rFonts = rpr.find(qn('w:rFonts'))
if rFonts is None:
    rFonts = style.element.makeelement(qn('w:rFonts'), {})
    rpr.append(rFonts)
rFonts.set(qn('w:eastAsia'), '宋体')
rFonts.set(qn('w:ascii'), 'Times New Roman')
rFonts.set(qn('w:hAnsi'), 'Times New Roman')

# 第一部分：代码总体说明（约80段）
# 第二部分：源代码清单（60页，每页50行）
# 策略：先放第一部分内容，然后第二部分按每页50行严格分页

# 找到第二部分开始位置
part2_start = 0
for i, p in enumerate(paragraphs):
    if p['text'].strip().startswith('第二部分'):
        part2_start = i
        break

print(f'第二部分开始位置: 段落{part2_start}')

# 第一部分段落
part1 = paragraphs[:part2_start]
# 第二部分段落（源代码清单）
part2 = paragraphs[part2_start:]

print(f'第一部分段落数: {len(part1)}')
print(f'第二部分段落数: {len(part2)}')

# 第二部分按每页50行分组
# 首先，识别页码标记，将第二部分按原始页码分组
page_groups = []
current_page = []
current_page_num = 0

for p in part2:
    if p['is_page_num']:
        if current_page:
            page_groups.append(current_page)
        current_page = [p]
        current_page_num += 1
    else:
        current_page.append(p)

if current_page:
    page_groups.append(current_page)

print(f'第二部分原始分组数: {len(page_groups)}')

# 现在重新组织第二部分，使每组恰好50行（不包括页码标记本身）
# 策略：遍历所有段落，每50行插入一个页码标记

# 先移除所有页码标记和页眉标记
clean_paras = []
for p in part2:
    if not p['is_page_num'] and not p['is_header']:
        clean_paras.append(p)

print(f'第二部分纯内容段落数: {len(clean_paras)}')

# 按每页50行分组
LINES_PER_PAGE = 50
new_pages = []
for i in range(0, len(clean_paras), LINES_PER_PAGE):
    page = clean_paras[i:i+LINES_PER_PAGE]
    new_pages.append(page)

print(f'重新分组后页数: {len(new_pages)}')

# 如果超过60页，需要精简内容
if len(new_pages) > 60:
    print(f'警告：重新分组后{len(new_pages)}页，超过60页，需要精简')
    # 策略：只保留前30页（核心基础层）和后30页（业务页面）
    # 但我们需要识别哪些是核心基础层，哪些是业务页面
    # 根据原始结构，前30页是核心基础层，后30页是业务页面
    # 由于重新分组改变了页码，我们需要按比例选取
    # 简化处理：保留前30页和后30页
    front_pages = new_pages[:30]
    back_pages = new_pages[-30:] if len(new_pages) > 60 else new_pages[30:]
    new_pages = front_pages + back_pages
    print(f'精简后页数: {len(new_pages)}')

# 构建最终文档
# 第一部分：代码总体说明
for p in part1:
    para = new_doc.add_paragraph()
    run = para.add_run(p['text'])
    run.font.name = '宋体'
    run.font.size = Pt(10)
    # 设置中文字体
    rpr = run._element.get_or_add_rPr()
    rFonts = rpr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = run._element.makeelement(qn('w:rFonts'), {})
        rpr.append(rFonts)
    rFonts.set(qn('w:eastAsia'), '宋体')

# 第二部分：源代码清单（每页50行，共60页）
for page_idx, page in enumerate(new_pages):
    # 添加页眉
    header_para = new_doc.add_paragraph()
    header_run = header_para.add_run(f'如画 Lumira 摄影辅助应用 V1.0.0')
    header_run.font.size = Pt(9)
    header_run.font.name = '宋体'
    header_para.alignment = WD_ALIGN_PARAGRAPH.LEFT
    
    # 添加页码
    page_para = new_doc.add_paragraph()
    page_run = page_para.add_run(f'第 {page_idx + 1} 页')
    page_run.font.size = Pt(9)
    page_run.font.name = '宋体'
    page_para.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    
    # 添加内容
    for p in page:
        para = new_doc.add_paragraph()
        run = para.add_run(p['text'])
        run.font.name = '宋体'
        run.font.size = Pt(10)
        # 设置中文字体
        rpr = run._element.get_or_add_rPr()
        rFonts = rpr.find(qn('w:rFonts'))
        if rFonts is None:
            rFonts = run._element.makeelement(qn('w:rFonts'), {})
            rpr.append(rFonts)
        rFonts.set(qn('w:eastAsia'), '宋体')
        # 代码块使用等宽字体
        if p['is_code'] or p['text'].strip().startswith('│'):
            run.font.name = 'Courier New'
            rFonts.set(qn('w:eastAsia'), 'Courier New')

# 保存文档
new_doc.save(DST)
print(f'\n新文档已保存: {DST}')
print(f'第二部分页数: {len(new_pages)}')
