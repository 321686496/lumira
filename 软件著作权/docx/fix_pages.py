# -*- coding: utf-8 -*-
from docx import Document
from docx.shared import Pt, Inches, Cm, Emu
from docx.enum.text import WD_LINE_SPACING
from docx.oxml.ns import qn
import copy

# 读取原文档
doc = Document(r'd:\app\projects\photo_post\软件著作权\docx\04-源代码说明文档.docx')

# 创建新文档
new_doc = Document()

# 设置页面格式 - A4 with narrow margins
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

print("页面设置完成")
print(f"页面宽度: {section.page_width}")
print(f"页面高度: {section.page_height}")
print(f"字体: 宋体 10pt")
print(f"行距: 1.15")

# 计算每页可通行数
usable_height = section.page_height - section.top_margin - section.bottom_margin
line_height = Pt(10) * 1.15
lines_per_page = usable_height / line_height
print(f"可用高度: {usable_height}")
print(f"行高: {line_height}")
print(f"估算每页行数: {lines_per_page:.1f}")
