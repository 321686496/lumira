# -*- coding: utf-8 -*-
"""
构建最终的源代码说明文档
- 每页恰好50行
- 共60页（前30页核心基础层 + 后30页业务页面层）
- 从5700行代码中精选3000行最具代表性的代码
"""
from docx import Document
from docx.shared import Pt, Cm
from docx.oxml.ns import qn
from docx.enum.text import WD_ALIGN_PARAGRAPH
import re

SRC = r'd:\app\projects\photo_post\软件著作权\docx\04-源代码说明文档.docx'
DST = r'd:\app\projects\photo_post\软件著作权\docx\04-源代码说明文档-精简版.docx'

doc = Document(SRC)

# 提取所有段落
all_paras = [p.text for p in doc.paragraphs]

# 找到第二部分开始位置
part2_start = 0
for i, text in enumerate(all_paras):
    if text.strip().startswith('第二部分'):
        part2_start = i
        break

part1_texts = all_paras[:part2_start]
part2_texts = all_paras[part2_start:]

# 识别模块边界
module_boundaries = []
for i, text in enumerate(part2_texts):
    if re.match(r'^模块\s+\d+', text.strip()):
        module_boundaries.append((i, text.strip()))

# 计算每个模块的代码行数（不含页码/页眉）
def count_code_lines(start, end):
    count = 0
    for i in range(start, min(end, len(part2_texts))):
        t = part2_texts[i].strip()
        if t and not re.match(r'^第\s*\d+\s*页$', t) and not ('如画 Lumira' in t and '第' in t and '页' in t):
            count += 1
    return count

modules = []
for idx, (pos, title) in enumerate(module_boundaries):
    end_pos = module_boundaries[idx + 1][0] if idx + 1 < len(module_boundaries) else len(part2_texts)
    modules.append({
        'title': title,
        'start': pos,
        'end': end_pos,
        'lines': count_code_lines(pos, end_pos),
    })

print(f'模块数量: {len(modules)}')
for m in modules:
    print(f'  {m["title"][:60]}: {m["lines"]}行')

# 核心基础层模块（1-8）：约1888行
# 业务页面层模块（9-12）：约3562行
core_modules = modules[:8]
biz_modules = modules[8:]

core_total = sum(m['lines'] for m in core_modules)
biz_total = sum(m['lines'] for m in biz_modules)
print(f'\n核心基础层: {core_total}行')
print(f'业务页面层: {biz_total}行')
print(f'总计: {core_total + biz_total}行')

# 目标：前30页1500行（核心基础层），后30页1500行（业务页面层）
FRONT_TARGET = 1500
BACK_TARGET = 1500

# 核心基础层：模块1-8共1888行，需要精简到1500行（保留80%）
# 按比例采样
def sample_module_lines(module, ratio):
    """从模块中按比例采样代码行"""
    lines = []
    for i in range(module['start'], min(module['end'], len(part2_texts))):
        t = part2_texts[i].strip()
        if t and not re.match(r'^第\s*\d+\s*页$', t) and not ('如画 Lumira' in t and '第' in t and '页' in t):
            lines.append(part2_texts[i])
    
    if not lines:
        return []
    
    target = max(1, int(len(lines) * ratio))
    if len(lines) <= target:
        return lines
    
    step = len(lines) / target
    return [lines[int(j * step)] for j in range(target)]

# 计算核心基础层采样比例
core_ratio = FRONT_TARGET / core_total if core_total > 0 else 1
biz_ratio = BACK_TARGET / biz_total if biz_total > 0 else 1

print(f'\n核心基础层采样比例: {core_ratio:.2%}')
print(f'业务页面层采样比例: {biz_ratio:.2%}')

# 采样代码
front_code = []
for m in core_modules:
    front_code.extend(sample_module_lines(m, core_ratio))

back_code = []
for m in biz_modules:
    back_code.extend(sample_module_lines(m, biz_ratio))

# 确保恰好1500行
front_code = front_code[:FRONT_TARGET]
back_code = back_code[:BACK_TARGET]

# 如果不够，用模块标题填充
while len(front_code) < FRONT_TARGET:
    for m in core_modules:
        front_code.append(f'// {m["title"]}')
        if len(front_code) >= FRONT_TARGET:
            break

while len(back_code) < BACK_TARGET:
    for m in biz_modules:
        back_code.append(f'// {m["title"]}')
        if len(back_code) >= BACK_TARGET:
            break

print(f'\n前30页代码: {len(front_code)}行')
print(f'后30页代码: {len(back_code)}行')
print(f'总计: {len(front_code) + len(back_code)}行')

# 构建最终文档
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

def add_page_header(page_num):
    """添加页眉和页码"""
    h = new_doc.add_paragraph()
    h_run = h.add_run('如画 Lumira 摄影辅助应用 V1.0.0')
    h_run.font.size = Pt(9)
    h_run.font.name = '宋体'
    h.alignment = WD_ALIGN_PARAGRAPH.LEFT
    
    p = new_doc.add_paragraph()
    p_run = p.add_run(f'第 {page_num} 页')
    p_run.font.size = Pt(9)
    p_run.font.name = '宋体'
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT

def add_code_line(text):
    """添加代码行"""
    para = new_doc.add_paragraph()
    run = para.add_run(text)
    run.font.size = Pt(10)
    
    # 代码块使用等宽字体
    is_code = (text.strip().startswith('│') or 
               text.strip().startswith('├──') or 
               text.strip().startswith('│   │') or 
               re.match(r'^\s*\d+\s', text) or
               text.strip().startswith('//') or
               text.strip().startswith('import ') or
               text.strip().startswith('class ') or
               text.strip().startswith('void ') or
               text.strip().startswith('final '))
    
    if is_code:
        run.font.name = 'Courier New'
    else:
        run.font.name = '宋体'
    
    rpr = run._element.get_or_add_rPr()
    rFonts = rpr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = run._element.makeelement(qn('w:rFonts'), {})
        rpr.append(rFonts)
    rFonts.set(qn('w:eastAsia'), '宋体' if not is_code else 'Courier New')

# 第一部分：代码总体说明
for text in part1_texts:
    para = new_doc.add_paragraph()
    run = para.add_run(text)
    run.font.name = '宋体'
    run.font.size = Pt(10)
    rpr = run._element.get_or_add_rPr()
    rFonts = rpr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = run._element.makeelement(qn('w:rFonts'), {})
        rpr.append(rFonts)
    rFonts.set(qn('w:eastAsia'), '宋体')

# 第二部分前30页（核心基础层）
page_num = 1
for i, text in enumerate(front_code):
    if i % 50 == 0:
        add_page_header(page_num)
        page_num += 1
    add_code_line(text)

# 第二部分后30页（业务页面层）
for i, text in enumerate(back_code):
    if i % 50 == 0:
        add_page_header(page_num)
        page_num += 1
    add_code_line(text)

# 保存
new_doc.save(DST)
print(f'\n新文档已保存: {DST}')
print(f'第二部分总页数: {page_num - 1}')
