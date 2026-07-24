# -*- coding: utf-8 -*-
"""
重新格式化源代码说明文档
- 每页恰好50行
- 共60页（30页核心基础层 + 30页业务页面）
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
all_paras = []
for p in doc.paragraphs:
    all_paras.append(p.text)

# 找到第二部分开始位置
part2_start = 0
for i, text in enumerate(all_paras):
    if text.strip().startswith('第二部分'):
        part2_start = i
        break

part1_texts = all_paras[:part2_start]
part2_texts = all_paras[part2_start:]

print(f'第一部分段落数: {len(part1_texts)}')
print(f'第二部分段落数: {len(part2_texts)}')

# 识别第二部分中的模块边界
# 模块标记格式：模块 X：标题（file_path）
module_boundaries = []
for i, text in enumerate(part2_texts):
    if re.match(r'^模块\s+\d+', text.strip()):
        module_boundaries.append((i, text.strip()))

print(f'\n模块数量: {len(module_boundaries)}')
for idx, (pos, title) in enumerate(module_boundaries):
    print(f'  模块{idx+1}: 位置{pos} - {title[:60]}')

# 识别页码标记位置
page_markers = []
for i, text in enumerate(part2_texts):
    if re.match(r'^第\s*\d+\s*页$', text.strip()):
        page_markers.append(i)

print(f'\n页码标记数: {len(page_markers)}')

# 移除页码标记和页眉标记，获取纯内容
clean_texts = []
for text in part2_texts:
    stripped = text.strip()
    if re.match(r'^第\s*\d+\s*页$', stripped):
        continue
    if '如画 Lumira' in stripped and '第' in stripped and '页' in stripped:
        continue
    clean_texts.append(text)

print(f'纯内容行数: {len(clean_texts)}')

# 目标：3000行 = 60页 × 50行
TARGET_LINES = 3000
LINES_PER_PAGE = 50
TOTAL_PAGES = 60

# 需要从5700行中选3000行，保留比例约53%
# 策略：均匀采样，但保留每个模块的代表性代码

# 分析每个模块的行数范围
modules = []
for idx, (pos, title) in enumerate(module_boundaries):
    if idx + 1 < len(module_boundaries):
        end_pos = module_boundaries[idx + 1][0]
    else:
        end_pos = len(clean_texts)
    # 计算该模块在clean_texts中的行数
    # 需要映射原始位置到clean_texts位置
    modules.append({
        'title': title,
        'start_orig': pos,
        'end_orig': end_pos,
    })

# 计算每个模块在clean_texts中的实际行数
for mod in modules:
    count = 0
    for i in range(mod['start_orig'], mod['end_orig']):
        if i < len(part2_texts):
            text = part2_texts[i].strip()
            if text and not re.match(r'^第\s*\d+\s*页$', text) and not ('如画 Lumira' in text and '第' in text and '页' in text):
                count += 1
    mod['line_count'] = count

print('\n各模块行数:')
total_code_lines = 0
for idx, mod in enumerate(modules):
    print(f'  {mod["title"][:50]}: {mod["line_count"]}行')
    total_code_lines += mod['line_count']

print(f'\n总代码行数: {total_code_lines}')

# 按比例从每个模块选取代码行
# 前30页（核心基础层）：选前几个模块
# 后30页（业务页面）：选后几个模块

# 策略：前30页选核心基础模块，后30页选业务模块
# 核心基础层模块：模块1-8（应用入口、路由、数据库、DAO、主题、路由）
# 业务页面层模块：模块9-12+（拍摄、模板、首页、相册、个人中心等）

# 根据原始结构，前30页对应模块1-8左右
# 后30页对应模块9-12+

# 找到前30页和后30页的模块分布
front_modules = []
back_modules = []
front_lines = 0
back_lines = 0

# 前30页大约对应前1/3的模块
# 后30页大约对应后2/3的模块
split_point = len(modules) // 3

for idx, mod in enumerate(modules):
    if idx < split_point:
        front_modules.append(mod)
        front_lines += mod['line_count']
    else:
        back_modules.append(mod)
        back_lines += mod['line_count']

print(f'\n前30页模块数: {len(front_modules)}, 代码行数: {front_lines}')
print(f'后30页模块数: {len(back_modules)}, 代码行数: {back_lines}')

# 从前30页模块中选1500行
# 从后30页模块中选1500行
front_target = TARGET_LINES // 2  # 1500
back_target = TARGET_LINES // 2   # 1500

# 均匀采样函数
def sample_lines(texts, start_orig, end_orig, target_count):
    """从指定范围均匀采样target_count行"""
    # 获取该范围的clean文本
    lines = []
    for i in range(start_orig, min(end_orig, len(part2_texts))):
        text = part2_texts[i].strip()
        if text and not re.match(r'^第\s*\d+\s*页$', text) and not ('如画 Lumira' in text and '第' in text and '页' in text):
            lines.append(part2_texts[i])
    
    if len(lines) <= target_count:
        return lines
    
    # 均匀采样
    step = len(lines) / target_count
    sampled = []
    for j in range(target_count):
        idx = int(j * step)
        sampled.append(lines[idx])
    return sampled

# 前30页代码
front_code = []
if front_modules:
    front_start = front_modules[0]['start_orig']
    front_end = front_modules[-1]['end_orig']
    front_code = sample_lines(part2_texts, front_start, front_end, front_target)

# 后30页代码
back_code = []
if back_modules:
    back_start = back_modules[0]['start_orig']
    back_end = back_modules[-1]['end_orig']
    back_code = sample_lines(part2_texts, back_start, back_end, back_target)

print(f'\n前30页采样: {len(front_code)}行')
print(f'后30页采样: {len(back_code)}行')
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
    # 页眉（左对齐）
    h = new_doc.add_paragraph()
    h_run = h.add_run('如画 Lumira 摄影辅助应用 V1.0.0')
    h_run.font.size = Pt(9)
    h_run.font.name = '宋体'
    h.alignment = WD_ALIGN_PARAGRAPH.LEFT
    # 页码（右对齐）
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
    # 代码使用等宽字体
    if text.strip().startswith('│') or text.strip().startswith('├──') or text.strip().startswith('│   │') or re.match(r'^\s*\d+\s', text):
        run.font.name = 'Courier New'
    else:
        run.font.name = '宋体'
    # 设置中文字体
    rpr = run._element.get_or_add_rPr()
    rFonts = rpr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = run._element.makeelement(qn('w:rFonts'), {})
        rpr.append(rFonts)
    rFonts.set(qn('w:eastAsia'), '宋体')
    if text.strip().startswith('│') or text.strip().startswith('├──') or re.match(r'^\s*\d+\s', text):
        rFonts.set(qn('w:eastAsia'), 'Courier New')

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
    if i % LINES_PER_PAGE == 0:
        add_page_header(page_num)
        page_num += 1
    add_code_line(text)

# 第二部分后30页（业务页面层）
for i, text in enumerate(back_code):
    if i % LINES_PER_PAGE == 0:
        add_page_header(page_num)
        page_num += 1
    add_code_line(text)

# 保存
new_doc.save(DST)
print(f'\n新文档已保存: {DST}')
print(f'第二部分总页数: {page_num - 1}')
