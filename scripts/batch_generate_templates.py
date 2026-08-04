#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量生成 17 款人像模板的效果图与剪影图。
依赖 qwen_image_gen.py（同目录）。

用法:
  python batch_generate_templates.py                  # 生成全部（效果图+剪影）
  python batch_generate_templates.py --only covers    # 仅生成效果图
  python batch_generate_templates.py --only silhouettes # 仅生成剪影
  python batch_generate_templates.py --start 0 --end 3 # 只生成第0~2个模板
  python batch_generate_templates.py --model wan2.7-image-pro  # 指定模型
"""

import argparse
import os
import sys
import time

# 导入同目录的 qwen_image_gen.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qwen_image_gen import call_api, extract_images, download_images, DEFAULT_API_KEY


# ============================================================
# 17 款模板定义：效果图 prompt + 剪影 prompt + 画幅尺寸
# ============================================================

# 画幅尺寸映射（千问 API size 格式: 宽*高）
SIZE_MAP = {
    "3:4": "1080*1440",
    "4:5": "1080*1350",
    "9:16": "1080*1920",
    "1:1": "1080*1080",
}

# 剪影统一尺寸（1:2 竖向比例）
SILHOUETTE_SIZE = "800*1600"

TEMPLATES = [
    # ---------- 模板 1: CCD 胶片复古 ----------
    {
        "id": "ccd_retro_portrait",
        "name": "CCD胶片复古",
        "aspect": "3:4",
        "cover_prompt": (
            "CCD胶片复古风格人像照片，20-25岁女性，自然妆容，穿米色针织衫，黑色长发微卷，"
            "侧身站立回眸看镜头，一手轻触发梢，微笑，复古老街墙面背景，午后暖阳，"
            "3:4竖图，人像位于三分线左侧，半身取景，右侧留白，侧顺光45度，午后暖黄色调柔和，"
            "暖黄主调，对比度略降，饱和度微提，复古褐黄，轻微颗粒CCD质感，柔光磨皮保留纹理，"
            "小红书热门CCD复古拍照教程风格，自然不失真，不要过度磨皮，不要塑料质感，不要现代数码清晰感"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身站立回眸姿态，一手自然下垂一手轻触耳侧发梢，"
            "一腿前一腿后重心后移，简约扁平轮廓风格，无面部细节，无背景装饰，无文字，"
            "1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 2: 港风夜景人像 ----------
    {
        "id": "hk_noir_portrait",
        "name": "港风夜景人像",
        "aspect": "3:4",
        "cover_prompt": (
            "港风夜景复古人像照片，25-30岁女性，红唇妆容，穿深色风衣，黑色长发，"
            "侧身倚靠墙面回眸看镜头，一手插袋，沉思表情，香港老街夜景，霓虹招牌暖光虚化背景，"
            "3:4竖图，人像位于三分线左侧，半身取景，霓虹侧光120度，暖黄主光暗部深沉，"
            "暖黄低对比，王家卫电影色调，轻微颗粒，轻度磨皮保留质感，暗角氛围，"
            "王家卫电影风格，小红书港风夜景教程，不要过亮，不要高饱和现代感，不要冷调"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身倚靠墙面姿态，头部回眸转向镜头，"
            "一手插袋一手自然垂下，双腿交叉倚墙，风衣下摆微飘，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 3: 日系小清新 ----------
    {
        "id": "japanese_fresh_portrait",
        "name": "日系小清新",
        "aspect": "3:4",
        "cover_prompt": (
            "日系小清新风格人像照片，18-22岁女性，淡妆，穿白色衬衫，黑色长直发，"
            "侧身自然行走，侧脸看向远方，微笑，樱花树下小径，晨光柔和，"
            "3:4竖图，人像位于三分线左侧，七分身，右侧大量留白，顺光晨光30度柔和漫射空气感，"
            "低对比低饱和，微冷色温，明亮通透，无颗粒，轻度磨皮，几乎不锐化，"
            "日系写真风格，小红书小清新教程，不要暖调，不要高对比，不要颗粒，不要暗角"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身行走姿态，头部侧脸转向远方，"
            "双手自然摆动，迈步动态，长发微飘裙摆轻摆，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 4: 奶油治愈风 ----------
    {
        "id": "cream_healing_portrait",
        "name": "奶油治愈风",
        "aspect": "3:4",
        "cover_prompt": (
            "奶油治愈风人像照片，20-25岁女性，淡妆，穿米色针织连衣裙，棕色中长发，"
            "正面坐姿，单手托腮，头部微倾，温柔微笑看镜头，海边沙滩夕阳暖光背景虚化，"
            "3:4竖图，人像位于三分线右侧，半身取景，夕阳侧逆光150度金色轮廓光暖调，"
            "奶油橙暖调，亮度偏高，对比略降，温柔治愈，轻度磨皮，极轻颗粒，无暗角，"
            "小红书小镰仓滤镜教程，海边夕阳拍照，不要冷调，不要高对比，不要暗角过重"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，正面坐姿，单手托腮，头部微倾，"
            "盘腿或屈膝坐，裙装下摆自然铺展，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 5: 新中式古风 ----------
    {
        "id": "chinese_classical_portrait",
        "name": "新中式古风",
        "aspect": "3:4",
        "cover_prompt": (
            "新中式古风人像照片，20-28岁女性，古风妆容，穿浅青色汉服，黑色长发盘发，"
            "侧身站立执团扇半遮面，回眸看镜头，含蓄浅笑，苏州园林白墙黛瓦竹林背景，"
            "3:4竖图，人像位于黄金分割点，全身取景，侧逆光135度轮廓光勾勒莫兰迪冷调，"
            "低饱和莫兰迪冷调，对比微提，色温偏冷，轻度颗粒，轻度磨皮，暗角氛围，"
            "小红书古风人像教程，莫兰迪冷色调风格，不要高饱和，不要暖调，不要过度磨皮"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身站立姿态，头部回眸转向镜头，"
            "一手执扇至面侧半遮，双腿并拢微立，汉服袖摆垂落，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 6: 法式慵懒高雅 ----------
    {
        "id": "french_lazy_portrait",
        "name": "法式慵懒高雅",
        "aspect": "4:5",
        "cover_prompt": (
            "法式慵懒高雅人像照片，25-30岁女性，自然妆，穿白色丝质睡衣，微卷长发，"
            "侧身倚靠白床单侧坐，头部微仰看侧方，慵懒表情，卧室白床单窗光侧照木地板，"
            "4:5竖图，人像位于三分线左侧，半身取景，窗光侧光90度明暗对比慵懒氛围，"
            "微暖复古，对比微提，颗粒质感，颗粒22，轻度磨皮，中度锐化，"
            "小红书法式慵懒风格教程，复古颗粒，不要高饱和，不要过度磨皮，不要冷调"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身倚靠侧坐姿态，头部微仰看向侧方，"
            "一手撑床面一手自然放置，侧坐屈膝，慵懒线条，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 7: 莫兰迪高级冷淡 ----------
    {
        "id": "morandi_minimal_portrait",
        "name": "莫兰迪高级冷淡",
        "aspect": "4:5",
        "cover_prompt": (
            "莫兰迪高级冷淡风人像照片，28-35岁女性，知性妆容，穿灰粉色西装，短发利落，"
            "正面端坐，双手交叠放膝上，正视镜头，知性无表情，纯灰背景墙极简无道具，"
            "4:5竖图，人像居中，半身取景，顺光柔光30度无明显阴影均匀，"
            "低饱和莫兰迪，色温微冷，高级冷淡，轻度磨皮，轻度锐化，几乎无颗粒，"
            "莫兰迪色系人像，轻熟女知性风，不要高饱和，不要暖调，不要颗粒重，不要暗角重"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，正面端坐姿态，头部正视前方，"
            "双手交叠放膝上，双腿并拢侧坐，简约线条，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 8: 室内暗调氛围 ----------
    {
        "id": "dark_indoor_portrait",
        "name": "室内暗调氛围",
        "aspect": "3:4",
        "cover_prompt": (
            "室内暗调氛围感人像照片，25-30岁女性，淡妆，穿深色高领毛衣，中长发，"
            "侧身倚靠桌面坐姿，单手托腮，微低头看侧方，沉思，暗调咖啡馆木质桌面咖啡杯道具，"
            "3:4竖图，人像位于三分线左侧，半身取景，侧光90度明暗对比暗调氛围，"
            "微暖暗调，对比偏高，锐化质感，中度锐化，轻度颗粒，轻度磨皮，暗角，"
            "小红书黑森林滤镜教程，咖啡馆暗调，不要过亮，不要高饱和，不要过度磨皮"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身倚靠桌面坐姿，头部微低头，"
            "单手托腮撑桌，坐姿，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 9: 夜景霓虹人像 ----------
    {
        "id": "neon_city_portrait",
        "name": "夜景霓虹人像",
        "aspect": "9:16",
        "cover_prompt": (
            "夜景霓虹人像照片，22-28岁女性，酷妆，穿黑色皮衣，短发利落，"
            "正面站立单手叉腰，一腿前一腿后，酷无表情看镜头，城市霓虹街景青色品红色霓虹招牌虚化背景，"
            "9:16竖图，人像位于三分线左侧，半身取景，多向霓虹光冷暖对比青紫色调，"
            "冷青品紫对比，对比偏高，爱乐之城风格，中度锐化，轻度颗粒，暗角氛围，"
            "小红书爱乐之城滤镜教程，城市夜景人像，不要暖调主光，不要过亮，不要低对比"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，正面站立单手叉腰姿态，头部正视前方微仰，"
            "一腿前一腿后开立站姿，飒爽线条，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 10: 清新淡雅绿 ----------
    {
        "id": "fresh_green_portrait",
        "name": "清新淡雅绿",
        "aspect": "3:4",
        "cover_prompt": (
            "清新淡雅绿森系人像照片，20-25岁女性，淡妆，穿米色棉麻连衣裙，长发自然，"
            "侧身坐在草地，回眸看镜头，双手后撑，屈膝，自然微笑，森林草地树荫漫射光野餐垫，"
            "3:4竖图，人像位于三分线左侧，全身取景，右侧留白，漫射光柔和无硬阴影空气感，"
            "淡雅绿调，低对比低饱和，色温微冷，明亮，无颗粒，轻度磨皮，不锐化，"
            "小红书净白滤镜教程，户外森系露营，不要暖调，不要高对比，不要颗粒，不要暗角"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身草地坐姿，头部回眸转向镜头，"
            "双手后撑，屈膝坐地，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 11: Y2K 千禧风 ----------
    {
        "id": "y2k_portrait",
        "name": "Y2K千禧风",
        "aspect": "3:4",
        "cover_prompt": (
            "Y2K千禧风人像照片，18-22岁女性，浓妆眼线，穿亮粉色短上衣低腰牛仔裤，金属链条配饰，"
            "正面站立双手叉腰，开立站姿，头部微仰，酷无表情直视镜头，涂鸦墙街头背景闪光直打，"
            "3:4竖图，人像居中，半身取景，正面闪光灯直打高对比硬光，"
            "高饱和高对比，暖微调，千禧攻击性，中度锐化，轻度颗粒，低磨皮保留质感，"
            "小红书Y2K千禧风教程，酷girl非甜美，不要低饱和，不要柔光，不要甜美表情，不要过度磨皮"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，正面双手叉腰站立姿态，头部正视微仰，"
            "双腿开立站姿，飒爽线条，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 12: 动漫温柔青 ----------
    {
        "id": "anime_dream_portrait",
        "name": "动漫温柔青",
        "aspect": "3:4",
        "cover_prompt": (
            "动漫温柔青人像照片，18-22岁女性，淡妆，穿浅蓝色连衣裙，长发飘动，"
            "正面站立张开双臂，仰头看天，开心大笑，晴天草地蓝天白云背景，"
            "3:4竖图，人像位于三分线左侧，全身取景，天空留白，顺光晴天明亮通透宫崎骏感，"
            "饱和微提，亮度偏高，阴影提亮，梦幻青调，无颗粒，轻度磨皮，不锐化，"
            "小红书梦境滤镜教程，宫崎骏动漫感，不要暗调，不要颗粒，不要高对比，不要暗角"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，正面站立张开双臂姿态，头部仰头望天，"
            "双腿微张站立，裙摆飘动，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 13: 复古暗夜蓝 ----------
    {
        "id": "blue_night_portrait",
        "name": "复古暗夜蓝",
        "aspect": "3:4",
        "cover_prompt": (
            "复古暗夜蓝人像照片，女性，穿深色长裙，长发，"
            "背影站立望海，仰头，双手自然下垂，黄昏海边天空大海占主体逆光，"
            "3:4竖图，人像位于三分线左侧，七分身，天空大海留白，逆光180度黄昏余晖剪影感，"
            "冷青深色，对比偏高，冷峻浪漫，轻度颗粒，轻度锐化，暗角氛围，"
            "小红书爱乐之城深色滤镜，逆光剪影，不要暖调，不要高亮，不要高饱和"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，背影站立姿态，头部仰头望远方，"
            "双手自然下垂，双腿并拢站立，长裙下摆，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 14: 温柔日暮紫 ----------
    {
        "id": "purple_dusk_portrait",
        "name": "温柔日暮紫",
        "aspect": "3:4",
        "cover_prompt": (
            "温柔日暮紫人像照片，20-28岁女性，淡妆，穿白色连衣裙，长发，"
            "侧身站立，侧脸仰头望夕阳，一手轻拂发丝，陶醉微笑，黄昏海边紫色晚霞天空，"
            "3:4竖图，人像位于三分线右侧，半身取景，夕阳侧逆光150度轮廓光紫色氛围，"
            "紫色日暮调，色温微暖，色调偏品红，梦幻，轻度磨皮，轻度锐化，微颗粒，"
            "小红书克莱因蓝滤镜教程，夕阳紫色梦幻，不要冷调，不要高对比，不要过度磨皮"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身站立姿态，头部侧脸仰头望远方，"
            "一手轻拂发丝，双腿并拢站立，裙摆轻动，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 15: 探店美食人像 ----------
    {
        "id": "foodie_portrait",
        "name": "探店美食人像",
        "aspect": "1:1",
        "cover_prompt": (
            "探店美食人像照片，22-28岁女性，淡妆，穿浅色针织衫，中长发，"
            "侧身坐姿，一手举咖啡杯，一手托腮，低头看桌面蛋糕，微笑，咖啡馆桌面蛋糕咖啡道具暖调室内，"
            "1:1方图，人像与美食呈对角线构图，侧光45度暖调室内灯明亮，"
            "暖调，饱和微提，食物诱人，轻度磨皮，轻度锐化，无颗粒，"
            "小红书探店下午茶拍照，Foodie滤镜，不要冷调，不要暗调，不要颗粒"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身坐姿，头部低头看前方桌面，"
            "一手举杯一手托腮，坐姿，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 16: 甜妹元气少女 ----------
    {
        "id": "sweet_girl_portrait",
        "name": "甜妹元气少女",
        "aspect": "3:4",
        "cover_prompt": (
            "甜妹元气少女风人像照片，18-22岁女性，可爱妆容，穿粉色连衣裙，双马尾或长发，"
            "正面站立微倾，单手比心至脸侧，头部微歪，俏皮大笑看镜头，纯色粉墙背景花墙或游乐场，"
            "3:4竖图，人像位于三分线右侧，半身取景，顺光30度明亮均匀粉嫩，"
            "高亮暖粉调，饱和微提，甜美元气，轻度磨皮，不锐化，无颗粒，"
            "小红书甜妹拍照教程，元气少女风，不要暗调，不要高对比，不要冷调，不要颗粒"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，正面站立微倾姿态，头部微歪，"
            "单手比心至脸侧，双腿并拢微内八，俏皮线条，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
    # ---------- 模板 17: 知性优雅轻熟女 ----------
    {
        "id": "elegant_lady_portrait",
        "name": "知性优雅轻熟女",
        "aspect": "4:5",
        "cover_prompt": (
            "知性优雅轻熟女人像照片，30-35岁女性，精致妆容，穿灰蓝色西装风衣，短发利落，"
            "侧身优雅行走，侧脸看远方，一手持手提包，自信微笑，城市街道简约背景办公商务区，"
            "4:5竖图，人像位于三分线左侧，七分身取景，侧光60度柔和莫兰迪淡雅，"
            "低饱和莫兰迪，色温微冷，知性成熟，轻度磨皮，轻度锐化，微颗粒，"
            "小红书轻熟女穿搭拍照，莫兰迪淡雅，不要高饱和，不要暖调，不要过度磨皮"
        ),
        "silhouette_prompt": (
            "纯白色背景，纯黑色人物剪影插画，侧身行走姿态，头部侧脸转向远方，"
            "一手持包一手自然摆动，优雅迈步，裙摆风衣微动，简约扁平轮廓风格，"
            "无面部细节，无背景装饰，无文字，1:2竖向构图，人物居中，清晰锐利的黑色填充轮廓"
        ),
    },
]


def generate_one(api_key, model, prompt, size, output_dir, filename_prefix, idx, total, label):
    """生成单张图片并下载。"""
    print(f"\n{'='*60}")
    print(f"[{idx}/{total}] 正在生成{label}...")
    print(f"尺寸: {size}")
    print(f"Prompt: {prompt[:80]}...")
    print(f"{'='*60}")

    start = time.time()
    try:
        response = call_api(
            api_key=api_key,
            model=model,
            prompt=prompt,
            size=size,
            n=1,
            negative_prompt="",  # wan2.7-image 不支持
            prompt_extend=True,
            watermark=False,
        )
        urls = extract_images(response)
        if not urls:
            print(f"[{idx}/{total}] 未获取到图片URL，响应: {response}")
            return False

        # 下载图片
        os.makedirs(output_dir, exist_ok=True)
        saved = download_images(urls, output_dir)
        if not saved:
            print(f"[{idx}/{total}] 图片下载失败")
            return False

        # 重命名为模板ID
        ext = os.path.splitext(saved[0])[1] or ".png"
        final_path = os.path.join(output_dir, f"{filename_prefix}{ext}")
        if os.path.exists(final_path):
            os.remove(final_path)
        os.rename(saved[0], final_path)

        elapsed = time.time() - start
        print(f"[{idx}/{total}] 完成! 耗时 {elapsed:.1f}s -> {final_path}")
        return True

    except Exception as e:
        elapsed = time.time() - start
        print(f"[{idx}/{total}] 生成失败 ({elapsed:.1f}s): {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="批量生成17款人像模板效果图与剪影")
    parser.add_argument("--only", choices=["covers", "silhouettes"], help="仅生成效果图或剪影")
    parser.add_argument("--start", type=int, default=0, help="从第几个模板开始（0-based）")
    parser.add_argument("--end", type=int, default=None, help="到第几个模板结束（exclusive）")
    parser.add_argument("--model", default="wan2.7-image", help="模型名")
    parser.add_argument("--api-key", default=None, help="API Key")
    parser.add_argument("--output-base", default=None, help="输出根目录")
    args = parser.parse_args()

    api_key = args.api_key or DEFAULT_API_KEY or os.getenv("DASHSCOPE_API_KEY")
    if not api_key:
        print("未找到 API Key")
        sys.exit(1)

    # 输出目录
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output_base = args.output_base or os.path.join(project_root, "lumira_app_flutter", "assets", "images")
    covers_dir = os.path.join(output_base, "templates")
    silhouettes_dir = os.path.join(output_base, "silhouettes")

    # 模板范围
    end = args.end or len(TEMPLATES)
    templates = TEMPLATES[args.start:end]
    total = len(templates)

    print(f"共 {total} 个模板待生成")
    print(f"模型: {args.model}")
    print(f"效果图输出: {covers_dir}")
    print(f"剪影输出: {silhouettes_dir}")

    results = {"covers": [], "silhouettes": []}

    # 生成效果图
    if args.only in (None, "covers"):
        print(f"\n{'#'*60}")
        print(f"# 开始生成效果图 ({total} 张)")
        print(f"{'#'*60}")
        for i, tpl in enumerate(templates, 1):
            idx = args.start + i
            size = SIZE_MAP.get(tpl["aspect"], "1080*1440")
            ok = generate_one(
                api_key, args.model, tpl["cover_prompt"], size,
                covers_dir, tpl["id"], idx, total, f"{tpl['name']}效果图"
            )
            results["covers"].append({"id": tpl["id"], "name": tpl["name"], "ok": ok})

    # 生成剪影
    if args.only in (None, "silhouettes"):
        print(f"\n{'#'*60}")
        print(f"# 开始生成剪影 ({total} 张)")
        print(f"{'#'*60}")
        for i, tpl in enumerate(templates, 1):
            idx = args.start + i
            ok = generate_one(
                api_key, args.model, tpl["silhouette_prompt"], SILHOUETTE_SIZE,
                silhouettes_dir, tpl["id"], idx, total, f"{tpl['name']}剪影"
            )
            results["silhouettes"].append({"id": tpl["id"], "name": tpl["name"], "ok": ok})

    # 汇总
    print(f"\n{'='*60}")
    print("生成结果汇总")
    print(f"{'='*60}")
    if results["covers"]:
        ok_count = sum(1 for r in results["covers"] if r["ok"])
        print(f"\n效果图: {ok_count}/{len(results['covers'])} 成功")
        for r in results["covers"]:
            status = "✓" if r["ok"] else "✗"
            print(f"  {status} {r['id']} ({r['name']})")
    if results["silhouettes"]:
        ok_count = sum(1 for r in results["silhouettes"] if r["ok"])
        print(f"\n剪影: {ok_count}/{len(results['silhouettes'])} 成功")
        for r in results["silhouettes"]:
            status = "✓" if r["ok"] else "✗"
            print(f"  {status} {r['id']} ({r['name']})")


if __name__ == "__main__":
    main()
