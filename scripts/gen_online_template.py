#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""线上模板批量生产脚本：按参考图姿势生成 9 姿势效果图 + 9 剪影图。

平台分工：
  - 姿势效果图 / 剪影图 → HAPI (gpt_image2.py, gpt-image-2)
  - 中间参考图（锚点）    → MaaS (gen_image.py, doubao-seedream-5-0)

流程：
  1. anchor  锚点（MaaS 文生图，中性站姿全身）→ _refs/anchor.png
  2. poses   9 张姿势图（HAPI 图生图，以锚点为参考图，只改姿势保人物/场景一致）
  3. sil     9 张剪影图（HAPI 图生图 → 白底黑线稿 → 本地阈值二值化转透明底）
  4. doc     生成 template.pptpl + pose_images.json

剪影提示词与二值化阈值与后端 AI 一键建模完全一致
（backend/src/modules/ai/ai-generate-silhouette.service.ts 的 AI_SILHOUETTE_PROMPTS.sketch / 阈值 245）。

用法：
  python gen_online_template.py <key> panels|anchor|poses|sil|doc|sample|all [--from panel|anchor] [--force]
  python gen_online_template.py 01_snow_cloud_hike sample     # 只出第 1 组样张
断点续跑：目标文件已存在且非空即跳过；--force 强制重生成。

姿势图两条路线（--from，默认 panel）：
  panel  用参考图切出的整格作 i2i 底图，锁定同一人物/穿搭/场景/机位，只做去 AI 味与出片感提升（推荐）
  anchor 用 MaaS 锚点图生图换姿势（人物与原图无关，易有 AI 感）
"""
import argparse
import io
import json
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
OUT_ROOT = ROOT / "online_templates"
HAPI_SCRIPT = SCRIPT_DIR / "gpt_image2.py"
MASS_SCRIPT = SCRIPT_DIR / "gen_image.py"

HAPI_KEY = "sk-ra-QGXBDTeNXX08c0Ae36c4CWbBBrNyQ4xO"
HAPI_MODEL = "gpt-image-2"
MASS_MODEL = "qwen-image-3.0-pro"   # MaaS 可用图像模型（doubao-seedream-5-0 当前无可用渠道）
SIZE = "3:4"                 # 竖构图（与模板 aspectRatio 一致）
MAX_TRY = 3                  # 单张重试上限
CALL_TIMEOUT = 660           # 单次子进程超时(秒)，HAPI 同步生成较慢

# 剪影：与后端 AI 引擎完全一致的提示词与二值化阈值
SIL_PROMPT = (
    "纯白背景上的极简单色人物轮廓线稿插画，用少量平滑线条勾勒参考图中人物的整体姿势和四肢位置，"
    "保留姿势比例与画面位置；只画头、躯干、四肢的大轮廓，禁止绘制发型发丝、五官、眼睛、颈纹、"
    "手部细节、衣物褶皱和任何背景细节，无底色无文字"
)
SIL_THRESHOLD = 245          # 灰度 >= 阈值视为白底 → 透明
SIL_BBOX_THRESHOLD = 0.3     # alpha 包围盒前景判定
SIL_BBOX_PAD_RATIO = 0.05    # 包围盒四周余量

# 以参考图整格为底图的「提质重绘」提示词：严格锁定人物/穿搭/场景/姿势，只做去 AI 味与出片感提升
REFINE_PROMPT = (
    "以参考图为准重绘这张户外雪山人像：严格保持同一个人物的长相与体型、同一套穿搭"
    "（橙橘色羽绒服、白色鸭舌帽、深色雪山护目镜、黑色面罩、黑色登山裤、灰白登山鞋、深灰背包、登山杖）、"
    "同一雪山云海场景与光线方向、同一机位与姿势动作，以上任何一项都不得改变。"
    "机位、透视与人物在画面中的位置大小比例也保持不变，不要重新构图或拉近拉远。"
    "把它变成真实相机直出的高清旅拍照片：3:4竖构图，真实户外大光比，侧逆光勾出轮廓，"
    "雪山与云海保留高光与层次；皮肤与衣物保留真实物理质感（皮肤纹理与自然肤色不均、面料褶皱、"
    "羽绒蓬松感、护目镜环境反射、鞋底积雪），轻微胶片颗粒。"
    "手部结构准确：五指比例正确、指节清晰、无多指、无手指融合或残缺。"
    "脸部只露出眼睛与护目镜，黑色面罩完整遮住口鼻、不露嘴不露下巴。"
    "禁止磨皮与塑料感，禁止CG或3D渲染感，禁止插画感与过度锐化，禁止完美对称的网红脸，"
    "禁止改变人物姿势、穿搭与场景，禁止添加文字水印。"
)


# ---------------------------------------------------------------- 模板配置

TEMPLATES = {
    "01_snow_cloud_hike": {
        "name": "雪山云海觅橘人像",
        "short_desc": "把整个冬天穿在身上，站在云上面",
        "description": (
            "写实户外雪山人像。花岗岩峰顶之上、脚下翻涌云海与连绵雪山，冷调天空漫射光叠加午后侧逆光，"
            "暖杏橘冲锋衣在冷调环境里成为唯一暖色主体，冷暖对比强烈。人物低马尾编发、清透淡妆，"
            "护目镜推在奶白针织帽檐上，深灰轻量背包与登山杖构成户外叙事。"
            "适合徒步、露营、雪山旅行等户外场景，人物全身入画，姿态松弛有力量感，画面干净有质感。"
        ),
        "tags": "人像, 户外, 雪山, 云海, 徒步, 旅拍",
        "reference_source": "小红书「雪山人像」「云海徒步」热门模板；户外旅拍姿势合集",
        "classification": {
            "majorStyle": "outdoor_travel",
            "style": "snow_cloud_hike",
            "method": "",
        },
        "ambience": {
            "seasons": ["autumn", "winter"],
            "weathers": ["sunny", "cloudy", "snow"],
            "timeTones": ["day", "cool"],
        },
        # 锚点：同造型同场景的中性站姿，作为 9 张姿势图的一致底图（MaaS 文生图）
        "style_prompt": (
            "写实户外雪山人像摄影，一位约24岁东亚女性，暖杏橘色轻薄冲锋衣、奶白针织帽、"
            "深灰色雪山护目镜推在帽檐上、浅灰登山裤、米白登山鞋、深灰轻量登山背包，"
            "低马尾编发垂在肩侧，清透淡妆，站在花岗岩峰顶，脚下是翻涌云海与连绵雪山，"
            "冷调天空，午后侧逆光勾出人物边缘轮廓光，单一主光源，"
            "3:4竖构图，全身人像，画面干净有质感，真实摄影质感，保留皮肤毛孔纹理，禁止磨皮过度"
        ),
        "anchor_pose": "正面站立，双脚与肩同宽，双手自然垂在身体两侧，目视镜头，全身完整入画",
        "poses": [
            {
                "name": "封面·伸手探镜",
                "description": (
                    "人物身体正对镜头略微后仰，屏幕右侧手臂向前伸出、五指最大限度张开直指镜头，"
                    "形成超近景手部前景遮挡画面，屏幕左侧手臂自然下垂扶住背包肩带，"
                    "重心略靠后，双腿自然站立，视线越过手掌看向镜头"
                ),
            },
            {
                "name": "头顶比框",
                "description": (
                    "人物正面站立，双臂在头顶两侧抬起，屏幕左侧手掌横放、屏幕右侧手掌竖放，"
                    "两手组合成取景框手势置于额前上方，肩膀放松，双腿自然分开与肩同宽，"
                    "下巴微抬，视线透过手势框看向镜头"
                ),
            },
            {
                "name": "岩石蹲踞双手前探",
                "description": (
                    "人物单膝蹲踞在峰顶岩石上，左腿屈膝下蹲、右膝抵近地面，上身向前倾，"
                    "双臂向前伸出、双手掌心向上摊开朝向镜头，手指自然张开，肩膀前送，"
                    "视线看向双手之间"
                ),
            },
            {
                "name": "半蹲比耶",
                "description": (
                    "人物半蹲，膝盖弯曲、重心下沉，屏幕右侧手在脸侧举起比出V字手势，"
                    "屏幕左侧手臂横持登山杖搭在身前，身体微侧，头略向屏幕右侧倾，视线看向镜头"
                ),
            },
            {
                "name": "蹲姿横杖",
                "description": (
                    "人物下蹲，双膝弯曲使身体贴近岩石，双手握住同一根登山杖的两端横放在膝盖前方，"
                    "手肘自然外展，上身直立略前倾，视线平视镜头"
                ),
            },
            {
                "name": "马步双杖",
                "description": (
                    "人物下蹲成马步，双腿分开、膝盖外展，双手各握一根登山杖垂直于身体两侧、"
                    "杖尖点地作支撑，手臂半伸直，上身挺直，头略微低下，视线看向画面前方"
                ),
            },
            {
                "name": "单腿后踢欢呼",
                "description": (
                    "人物以左腿单腿站立，右腿向后上方抬起并屈膝，屏幕右侧手臂向后上方高高举起、"
                    "手掌摊开，屏幕左侧手握着登山杖向侧下方伸展，上身随之后仰，头抬起，"
                    "视线看向斜上方，情绪兴奋"
                ),
            },
            {
                "name": "侧身持杖望远",
                "description": (
                    "人物侧身站立（身体朝向屏幕右侧约90度），双手一上一下握住同一根竖直的登山杖"
                    "立于身前，肩膀放松下沉，双腿前后自然错开站立，头部转向画面外远方，"
                    "侧脸轮廓清晰，视线望向远山"
                ),
            },
            {
                "name": "坐岩扶帽",
                "description": (
                    "人物坐在峰顶岩石上，上身微微后仰，双臂在头顶两侧抬起、双手扶住帽檐做整理帽子的动作，"
                    "屏幕左侧手臂手肘朝上、屏幕右侧手臂手肘朝外，屏幕左侧腿向前伸直、鞋底正对镜头形成前景，"
                    "另一腿屈膝收起，视线看向镜头"
                ),
            },
        ],
    },
    "02_blue_hour_beach": {
        "name": "蓝调海边夜风人像",
        "short_desc": "把晚风与海蓝穿在身上",
        "description": (
            "写实蓝调时刻海边环境人像。日落后 20-40 分钟的蓝调时刻，海边沙滩与浅滩海浪之上，"
            "天空与海面呈现深蓝、靛蓝、紫蓝色的渐变色调，远处点缀远山与船灯。"
            "覆盖黑/白/红/粉、米白等多套吊带长裙与配饰，搭配宽檐草帽、复古煤油灯、纱巾、花朵等氛围道具，"
            "冷调天空余光勾出轮廓，暖橙光源点出冷暖对比。适合海边、岛屿、假期旅拍等场景。"
        ),
        "tags": "人像, 海边, 蓝调, 夜景, 氛围, 旅拍",
        "reference_source": "小红书「海边蓝调」「夜色海边人像」热门模板；蓝调时刻旅拍姿势合集",
        "classification": {
            "majorStyle": "dreamy_night",
            "style": "blue_night",
            "method": "",
        },
        "ambience": {
            "seasons": ["spring", "summer", "autumn", "winter"],
            "weathers": ["sunny", "cloudy", "overcast"],
            "timeTones": ["night", "dusk", "cool"],
        },
        # 面板路线：source_grid.png（3×3）每格对应一个姿势的参考图；本模板不生成中间锚点。
        "refine_prompt": (
            "以参考图为准重绘这张蓝调时刻海边人像：严格保持参考图中人物的姿势动作、表情神态、身材身形、"
            "发型与站位方向不变，严格保持同一套穿搭（裙装长短与版型、配饰道具）与同一蓝调海边场景、"
            "光线方向、构图机位不变，以上任何一项都不得改变。为避免与原图雷同侵权，仅轻微调整人物五官"
            "脸型与妆容、以及服装的颜色与花色，但姿态、场景、穿搭与氛围必须保持一致。人物要年轻精致："
            "约20岁年轻东亚女性，五官精致立体、皮肤细腻有光泽、身材匀称柔美、发型时尚自然。"
            "把它变成真实相机直出的高清蓝调海边人像照片：黄昏后蓝调时刻，深蓝紫渐变海天，冷调光线与轮廓光，"
            "海风微动发丝与裙摆，皮肤细腻柔软，轻微胶片颗粒。手部结构准确：五指比例正确、指节清晰、"
            "无多指、无手指融合或残缺。禁止改变人物姿势、场景与道具，禁止添加文字水印。"
        ),
        "poses": [
            {
                "name": "纱裙回眸",
                "description": (
                    "人物侧身站立回眸看向镜头，浅绿色吊带抹胸纱裙、极细肩带、低胸设计，裙摆随风飘逸，"
                    "湿发贴合颈部肌肤，一手轻触发际，眼神勾连，S形侧身曲线，撩人又优雅"
                ),
            },
            {
                "name": "撩发踏浪",
                "description": (
                    "人物立于浅水海浪中，黑色比基尼式套装（短上衣+短裤）露腰腹，一手高举过头顶拨弄湿发"
                    "撩发，另一手自然下垂，海浪环绕脚下，湿身诱惑，活力十足"
                ),
            },
            {
                "name": "卧沙托腮",
                "description": (
                    "人物侧身蜷缩卧于沙滩，白色吊带长裙，一手托腮作沉思状，另一手轻搭身前，腰臀曲线"
                    "自然折叠、比例突出，发间点缀花朵，少女人畜无害的纯欲感，望向镜头"
                ),
            },
            {
                "name": "敞衣回眸",
                "description": (
                    "人物侧身转头凝视镜头，黑色深V敞开式长外套，内搭若隐若现，海风吹起外套下摆与长发，"
                    "眼神极具气场，女王范与野性魅力并存的性感"
                ),
            },
            {
                "name": "持花回眸",
                "description": (
                    "人物背对镜头头部大角度侧转回望，黑色深沉吊带长裙露背设计，低挽发髻露出颈背线条，"
                    "手持一束花于身侧，含蓄性感的成熟风韵，海风轻拂"
                ),
            },
            {
                "name": "坐沙仰天",
                "description": (
                    "人物侧坐沙滩，白色抹胸长裙，一手撑地、一手轻放膝上，仰头望向夜空拉长颈部线条露出"
                    "天鹅颈，锁骨与肩胸轮廓清晰，裙摆铺开如花瓣，纯洁的脆弱与撩人并存"
                ),
            },
            {
                "name": "红裙踏沙",
                "description": (
                    "人物背对镜头行走于沙滩，红色吊带长裙高开叉设计，行走中路侧首望向一侧，手持宽檐草帽，"
                    "海风吹动裙摆露出修长腿线，动态风情、热烈性感"
                ),
            },
            {
                "name": "侧影掠风",
                "description": (
                    "人物侧身站立于海边，黑色细吊带短裙，一手轻触胸前，视线凝视镜头，海风勾勒出侧乳线"
                    "与腰身曲线，冷调蓝光下神秘而性感"
                ),
            },
            {
                "name": "背影听风",
                "description": (
                    "人物背对镜头立于海边，白色短上衣配黑色及膝裙、外搭半脱露出肩背线条，海风吹起衣摆与"
                    "长发，面向大海，背影杀/露背短裙，随性又撩人"
                ),
            },
        ],
    },
    "03_zoo_healing": {
        "name": "清新动物园治愈人像",
        "short_desc": "和小动物撞个满怀，治愈一整天",
        "description": (
            "写实清新治愈动物园人像。明亮晴日下的动物园，错落的绿树、木质围栏与灰白石墙构成清爽背景，"
            "柔和自然光叠加林间透光，画面通透明亮。人物浅色轻薄夏装、齐肩发微卷、清透淡妆，"
            "与小鹿、长颈鹿、鹦鹉等小动物自然互动，姿态松弛、眼神温柔，整体清新治愈、干净有质感。"
            "适合亲子出游、情侣约会、闺蜜同游等动物园场景，人物全身入画，氛围慵懒美好。"
        ),
        "tags": "人像, 动物园, 萌宠, 治愈, 清新, 周末游",
        "reference_source": "小红书博主「虫子拍照啦📸」《存一些去动物园的拍照姿势》；动物园拍照姿势合集",
        "classification": {
            "majorStyle": "fresh_healing",
            "style": "zoo_healing",
            "method": "",
        },
        "ambience": {
            "seasons": ["spring", "summer"],
            "weathers": ["sunny", "cloudy"],
            "timeTones": ["day", "warm"],
        },
        "docOverride": {
            "compositionDescription": (
                "竖版 3:4，三分法构图。人物全身置于画面中下部，主体与栅栏/石墙/观景台构成前后景层次；"
                "顶部保留绿树与天空留白，动物互动的视线方向尽量朝画面中心，形成人物与动物的呼应关系。"
            ),
            "sceneGuide": {
                "lightDirection": "明亮晴日的林间自然光，主光从画面上方约 60° 柔柔打下，绿树与石墙形成均匀柔光，少量逆光勾出人物发丝轮廓，光比约 2:1，整体通透清新、皮肤保留自然暖色",
                "shootingDistance": "1-2.5m（与动物互动时保持安全距离，蹲姿/俯身可更近）",
                "background": "动物园的绿树、木质围栏与灰白石墙，远处隐约露出展区；避免杂乱人流与其他动物入框",
                "props": ["小鹿饲料", "米色宽檐草帽", "红白波点小阳伞"],
                "bestTime": "晴日 09:00-11:00 或 15:00-17:00（光线柔和、动物精神好）",
                "tips": [
                    "长按锁定对焦在人脸，动物动得快时连拍抓拍更稳，别让动物糊掉。",
                    "蹲下或俯身到与动物平视的高度，互动感更强，背景也不容易拍到人群。",
                    "穿浅色系穿搭与绿树石墙更搭，避免与背景融为一体。",
                    "尊重动物，保持安静与安全距离，用饲料、帽伞等道具自然引导互动。",
                    "优先选择清晨或傍晚，避免正午强光导致动物眯眼、面部过曝。",
                ],
            },
            "postProcess": {
                "cropRatio": "3:4",
                "color": {
                    "brightness": 4,
                    "contrast": 6,
                    "saturation": 6,
                    "temperature": 4,
                    "tint": 2,
                    "highlights": -10,
                    "shadows": 8,
                },
                "smoothStrength": 8,
                "sharpen": 14,
                "vignette": 6,
                "grain": 8,
                "lut": "warm_film",
            },
        },
        # 锚点：同造型同场景的中性站姿，作为 9 张姿势图的一致底图（MaaS 文生图）
        "style_prompt": (
            "写实清新ins随手拍动物园人像摄影，一位约22岁东亚女性，长发直黑发自然披散垂至中背，"
            "小巧鹅蛋脸、五官精致、皮肤白皙带暖调，纤细体型，身穿白色短袖上衣搭配米色宽松长裙、"
            "浅色帆布鞋，头戴米色宽檐草帽，站在动物园绿意步道旁，木质围栏、低矮石墙与绿树环绕，"
            "远处露出小鹿与长颈鹿展区，明亮晴日柔和自然光、轻透暖调，3:4竖构图，全身人像，"
            "真实手机随拍质感与生活感，轻微胶片感与空气感，保留皮肤毛孔纹理，禁止磨皮过度，"
            "清新治愈氛围"
        ),
        "anchor_pose": "正面站立，双脚自然分开与肩同宽，双手自然垂在身体两侧，微微歪头带上浅笑，目视镜头，全身完整入画",
        "poses": [
            {
                "name": "封面·隔栏喂鹿",
                "description": (
                    "人物蹲在木质栅栏外侧，屏幕右侧手臂向前伸出、手掌握着一小把饲料递向栅栏里的小鹿，"
                    "屏幕左侧手自然搭在膝上，上身微微前倾，双腿屈膝下蹲，头微低，视线温柔地看向小鹿"
                ),
            },
            {
                "name": "伸手摸小鹿脸颊",
                "description": (
                    "人物站在半开放的鹿园旁，身体微微俯身向前，屏幕右侧手轻轻向前托着小鹿的脸颊，"
                    "屏幕左侧手自然垂在身侧，头微倾，眉眼带笑视线看向小鹿，双腿自然前后站立"
                ),
            },
            {
                "name": "石墙侧倚回眸",
                "description": (
                    "人物身体侧面轻靠在浅灰石墙上，屏幕左侧肩膀与手臂搭在墙面，屏幕右侧手臂自然垂于体侧，"
                    "双腿在脚踝处自然交叉，头转向镜头回眸浅笑，神情松弛，视线看向镜头"
                ),
            },
            {
                "name": "木台与长颈鹿同框",
                "description": (
                    "人物站在木质观景平台上，微微踮脚伸长脖子看向远处低头吃树叶的长颈鹿，"
                    "屏幕右侧手臂举到胸前做扶望姿势，屏幕左侧手自然垂落，身体微微后仰，双腿自然分立，"
                    "侧脸轮廓清晰，视线望向长颈鹿"
                ),
            },
            {
                "name": "戴草帽坐观长颈鹿",
                "description": (
                    "人物戴着米色宽檐草帽坐在石凳上，双膝并拢自然侧坐，双手交叠搭在膝上，"
                    "上身微微前倾，头转向画面右侧看向长颈鹿展区，侧脸清晰，视线望向前方，神情悠闲"
                ),
            },
            {
                "name": "红伞优雅站",
                "description": (
                    "人物右手举着一把红白波点小阳伞搭在右肩上方，伞面微微倾斜，左手自然垂在身侧，"
                    "身体笔直微微侧转，双腿前后错落站立，头微扬，视线带笑看向镜头，姿态优雅松弛"
                ),
            },
            {
                "name": "白裙栅栏远眺",
                "description": (
                    "人物穿白色轻盈长裙、戴宽檐帽，背对围栏而站，屏幕右侧手轻轻搭在栅栏横木上，"
                    "屏幕左侧手臂自然下垂，身体微侧并回头看向镜头，另一侧视线望向远处，裙摆随微风轻扬"
                ),
            },
            {
                "name": "蹲地逗梅花鹿",
                "description": (
                    "人物蹲在鹿园栅栏边的草坪上，双臂向前伸出、手指微张做逗引姿势朝向草地上低头撒娇的小鹿，"
                    "身体前倾压低，双腿屈膝下蹲，头微低，视线温柔地看向小鹿，神情宠溺"
                ),
            },
            {
                "name": "张臂迎鹦鹉",
                "description": (
                    "人物站在鹦鹉园前，双臂向两侧自然张开、掌心向上做出迎接姿势，头微扬看向停在肩侧的彩色鹦鹉，"
                    "上身微微后仰，双腿自然站立与肩同宽，表情惊喜又放松，视线看向鹦鹉"
                ),
            },
        ],
    },
    "04_tiananmen_basket": {
        "name": "国庆大花篮红旗人像",
        "short_desc": "把国庆的喜庆和小红旗一起，定格成最体面的纪念",
        "description": (
            "写实国庆天安门人像。巨型国庆编织大花篮（黄红暖调，缀满石榴、葡萄、向日葵、菊花、月季）"
            "居于画面主体，远景为天安门城楼与长安街，深秋通透蓝天下洋溢着国庆喜庆氛围。"
            "人物作黑/白/红或牛仔配色穿搭，手持一面小红旗，借助花篮与花坛遮挡人流、抬升的低机位视角，"
            "避开人群也能拍出大气干净的国庆纪念照。人物全身入画，姿态自然舒展，画面喜庆、干净且有质感。"
        ),
        "tags": "人像, 国庆, 天安门, 大花篮, 城市地标, 旅拍, 纪念照",
        "reference_source": "小红书《9.23实拍大花篮进入完全体！附避开人群机位》爆款笔记；天安门大花篮旅拍姿势",
        "classification": {
            "majorStyle": "holiday_travel",
            "style": "tiananmen_basket",
            "method": "",
        },
        "ambience": {
            "seasons": ["autumn"],
            "weathers": ["sunny"],
            "timeTones": ["day", "warm"],
        },
        # 锚点：同造型同场景的中性站姿，作为 9 张姿势图的一致底图（MaaS 文生图）
        "style_prompt": (
            "写实国庆天安门人像摄影，一位约24岁东亚女性，大红色针织衫内搭白衬衫、牛仔外套敞穿，"
            "深蓝牛仔裤，右手自然握一面小红旗，站在天安门广场巨型国庆编织大花篮前，"
            "花篮黄红暖调缀满石榴、葡萄、向日葵、菊花、月季，花篮后远景为天安门城楼与长安街，"
            "深秋通透蓝天，顺光，单一主光源，3:4竖构图，全身人像，画面干净喜庆有质感，"
            "真实摄影质感，保留皮肤毛孔纹理与真实面料质感，禁止磨皮过度"
        ),
        "anchor_pose": "正面站立，双脚与肩同宽，左手自然握小红旗垂在身侧，右手自然下垂，目视镜头，全身完整入画",
        "poses": [
            {
                "name": "封面·持旗回眸",
                "description": (
                    "人物侧身回眸看向镜头，双手将小红旗举在肩侧，微侧身让身后的大花篮遮住人流，"
                    "重心放后脚，衣角被风带起，身后为国庆大花篮与远景天安门城楼"
                ),
            },
            {
                "name": "花坛前蹲举旗",
                "description": (
                    "人物蹲在大花坛前，身前花坛的花卉挡住身后人群，一手将小红旗高高举起，"
                    "另一手托腮，下巴微抬看向镜头，低机位仰拍，大花篮与天安门作背景"
                ),
            },
            {
                "name": "侧身依花篮",
                "description": (
                    "人物侧身轻靠大花篮外围栏杆，一手搭在栏杆上，另一手持旗自然垂放，"
                    "一腿微弯靠近镜头，近景花篮遮去背景人流，视线看向镜头"
                ),
            },
            {
                "name": "仰头看花篮",
                "description": (
                    "人物站大花篮正下方，半侧身仰头望向巨型花篮，一手举起小红旗指向花篮顶部，"
                    "构图带到天安门城楼，人物取小景别留白，大花篮填满画面中上部"
                ),
            },
            {
                "name": "举旗欢呼",
                "description": (
                    "人物正面站立，双手高举小红旗欢呼，双脚分开与肩同宽，表情明朗，"
                    "大花篮与天安门城楼完整作背景，低机位借花篮遮挡人流"
                ),
            },
            {
                "name": "插兜闲站",
                "description": (
                    "人物站在大花篮侧面（背景为大理石基座），一手插兜一手持旗自然垂放，"
                    "身体微侧面对镜头，以近景花篮局部遮挡身后人群，表情放松，点缀喜庆氛围"
                ),
            },
            {
                "name": "坐姿曲腿低角度",
                "description": (
                    "人物坐在花坛边沿，一脚向前伸出、一脚屈膝，双手自然在上方持旗，"
                    "低角度拍摄使大花篮填满身后画面上部、挡住人流，视线看向镜头"
                ),
            },
            {
                "name": "背影望城楼",
                "description": (
                    "人物背对镜头望向天安门城楼方向，手持小红旗自然垂于身侧，"
                    "长发与旗角被风带起，构图以大花篮为前景、天安门城楼为远景"
                ),
            },
            {
                "name": "正面比心持旗",
                "description": (
                    "人物正面站立，一手将小红旗置于胸前，另一手在脸侧比出心形，站姿板正，"
                    "大花篮与天安门城楼同框取景，喜庆庄重"
                ),
            },
        ],
        "docOverride": {
            "compositionDescription": "竖版 3:4，三分法构图。人物全身置于画面中下部，巨型国庆大花篮作为前景填满画面中上部并带入天安门城楼；借花篮与花坛的低机位遮挡人流，画面顶部保留花篮与天空留白。",
            "sceneGuide": {
                "lightDirection": "白天顺光/侧光，主光来自人物前方约 30°，面部受光均匀；上午面对大花篮一侧顺光、午后背面一侧顺光，光比约 2:1，整体暖调喜庆、皮肤保留暖色",
                "shootingDistance": "2-5m",
                "background": "天安门广场巨型国庆编织大花篮（黄红暖调缀满花果花卉）、远景天安门城楼或国博、长安街；避开密集人流，以花篮/花坛为前景遮挡",
                "props": ["小红旗", "小花篮", "牛仔外套", "白衬衫"],
                "bestTime": "深秋国庆，天气通透时；上午面对大花篮一侧顺光，或下午换另一侧顺光",
                "tips": [
                    "借大花篮与花坛做前景遮挡人流，低机位把花篮填满画面上部。",
                    "黑白红或牛仔配色更容易在喜庆花篮前出片。",
                    "长按锁定对焦，背景天安门与花篮明暗反差大时略微降曝光保住高光。",
                    "人物尽量与花篮、天安门形成纵深感，避免被背景人流穿帮。",
                    "提前预约、带身份证与防晒，尽量错峰或选侧面机位避开人群。",
                ],
            },
            "postProcess": {
                "cropRatio": "3:4",
                "color": {
                    "brightness": 2,
                    "contrast": 10,
                    "saturation": 8,
                    "temperature": 3,
                    "tint": 1,
                    "highlights": -12,
                    "shadows": 8,
                },
                "smoothStrength": 8,
                "sharpen": 16,
                "vignette": 8,
                "grain": 6,
                "lut": "warm_film",
            },
        },
    },
}


# ---------------------------------------------------------------- 工具

def tdir(out_dir: Path) -> Path:
    """调用产物的临时目录（每次调用独立，便于稳定取到新文件）"""
    d = out_dir / "_refs" / "_tmp" / str(int(time.time() * 1000))
    d.mkdir(parents=True, exist_ok=True)
    return d


def newest_png(d: Path):
    pngs = sorted(d.glob("*.png"), key=lambda p: p.stat().st_mtime)
    return pngs[-1] if pngs else None


def valid(p: Path) -> bool:
    return p.is_file() and p.stat().st_size > 0


def run_cmd(cmd, out_dir: Path, label: str):
    """执行一次生成命令；成功返回新产出的 png，失败返回 None"""
    before = set(out_dir.glob("*.png"))
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=CALL_TIMEOUT)
    except subprocess.TimeoutExpired:
        print(f"   [{label}] 超时({CALL_TIMEOUT}s)", flush=True)
        return None
    time.sleep(0.5)
    for p in sorted(out_dir.glob("*.png"), key=lambda p: p.stat().st_mtime, reverse=True):
        if p not in before:
            return p
    err = (r.stderr or r.stdout or "")[-400:]
    print(f"   [{label}] 失败 exit={r.returncode} {err}", flush=True)
    return None


def gen_hapi(prompt: str, out_dir: Path, label: str, ref: Path = None, fidelity: str = None):
    """HAPI 生成；fidelity='high' 时先带参考图保真度重试，全部失败再降级为不带该参数"""
    variants = [["--input-fidelity", fidelity] if fidelity else [], []]
    if not fidelity:
        variants = [[]]
    for extra in variants:
        for attempt in range(1, MAX_TRY + 1):
            tmp = tdir(out_dir)
            cmd = [sys.executable, str(HAPI_SCRIPT), prompt,
                   "--platform", "hapi", "--model", HAPI_MODEL, "--size", SIZE,
                   "--out", str(tmp), "--api-key", HAPI_KEY, "--timeout", str(CALL_TIMEOUT)]
            cmd += extra
            if ref is not None:
                cmd += ["--image", str(ref), "--once"]
            print(f"   [{label}] hapi 尝试 {attempt}/{MAX_TRY}"
                  f"{'  fidelity=' + fidelity if extra else ''}", flush=True)
            f = run_cmd(cmd, tmp, label)
            if f:
                return f
            time.sleep(3)
    return None


def gen_maas(prompt: str, out_dir: Path, label: str, ref: Path = None):
    """MaaS 生成；ref 给定时用本地参考图做图生图（--image-file），保持提示词约束不改姿势/场景"""
    tmp = tdir(out_dir)
    cmd = [sys.executable, str(MASS_SCRIPT), prompt,
           "--model", MASS_MODEL, "--size", SIZE, "--out", str(tmp)]
    if ref is not None:
        cmd += ["--image-file", str(ref)]
    for attempt in range(1, MAX_TRY + 1):
        print(f"   [{label}] maas 尝试 {attempt}/{MAX_TRY}" + (" (图生图)" if ref else ""), flush=True)
        f = run_cmd(cmd, tmp, label)
        if f:
            return f
        time.sleep(3)
    return None


# ---------------------------------------------------------------- 剪影后处理

def binarize_to_transparent(raw_path: Path) -> Image.Image:
    """白底黑线稿 → 透明底黑线（与后端 AI 剪影引擎同口径：灰度 < 阈值 → 纯黑不透明）"""
    gray = Image.open(raw_path).convert("L")
    arr = np.asarray(gray)
    alpha = np.where(arr < SIL_THRESHOLD, 255, 0).astype(np.uint8)
    rgb = np.zeros(arr.shape + (3,), dtype=np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def crop_to_content(img: Image.Image) -> Image.Image:
    """按 alpha 包围盒裁掉全透明边距（留 5% 余量），无前景时原样返回"""
    alpha = np.asarray(img)[:, :, 3]
    ys, xs = np.where(alpha >= int(SIL_BBOX_THRESHOLD * 255))
    if len(xs) == 0:
        return img
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    pad_x = int(round((x1 - x0 + 1) * SIL_BBOX_PAD_RATIO))
    pad_y = int(round((y1 - y0 + 1) * SIL_BBOX_PAD_RATIO))
    w, h = img.size
    box = (max(0, x0 - pad_x), max(0, y0 - pad_y),
           min(w, x1 + pad_x + 1), min(h, y1 + pad_y + 1))
    return img.crop(box)


# ---------------------------------------------------------------- 步骤

def step_anchor(cfg, out_dir: Path, force: bool) -> bool:
    anchor = out_dir / "_refs" / "anchor.png"
    if valid(anchor) and not force:
        print(f"跳过 锚点（已存在 {anchor.name}）", flush=True)
        return True
    anchor.parent.mkdir(parents=True, exist_ok=True)
    prompt = f"{cfg['style_prompt']}。姿势动作：{cfg['anchor_pose']}。"
    print("生成锚点（MaaS 文生图）…", flush=True)
    f = gen_maas(prompt, out_dir, "锚点")
    if not f:
        print("!! 锚点生成失败", flush=True)
        return False
    f.replace(anchor)
    print(f"锚点就绪 -> {anchor}", flush=True)
    return True


def pose_prompt(cfg, pose) -> str:
    return (
        "保持参考图中同一人物（同一张脸、同一发型、同一套穿搭）以及同一背景场景、"
        "同一光线与色调不变，只改变人物的姿势动作。"
        f"姿势动作：{pose['description']}。"
        "3:4竖构图，全身人像，写实摄影质感：保留皮肤毛孔与真实面料质感，单一主光源方向，"
        "手部五指比例正确、指节清晰，背景层次真实，画面干净有质感。"
    )


def step_panels(out_dir: Path, force: bool = False):
    """把 _refs/source_grid.png（3x3 九宫格参考图）按格切开，作为 9 个姿势的提质底图"""
    src = out_dir / "_refs" / "source_grid.png"
    if not valid(src):
        print(f"!! 缺少参考图 {src}", flush=True)
        return False
    refs = out_dir / "_refs"
    grid = Image.open(src)
    w, h = grid.size
    pw, ph = w // 3, h // 3
    for r in range(3):
        for c in range(3):
            idx = r * 3 + c + 1
            target = refs / f"panel{idx}.png"
            if valid(target) and not force:
                continue
            grid.crop((c * pw, r * ph, (c + 1) * pw, (r + 1) * ph)).save(target)
            print(f"切格 panel{idx} -> {target.name} {target.stat().st_size // 1024}KB", flush=True)
    return True


def step_pose(cfg, out_dir: Path, idx: int, force: bool, source: str = "panel", pform: str = "hapi") -> bool:
    """idx: 1-based；source=panel 用参考图整格提质重绘，source=anchor 用锚点图生图换姿势；pform=hapi|maas"""
    target = out_dir / f"pose{idx}.png"
    if valid(target) and not force:
        print(f"跳过 pose{idx}（已存在）", flush=True)
        return True
    pose = cfg["poses"][idx - 1]
    if source == "panel":
        ref = out_dir / "_refs" / f"panel{idx}.png"
        if not valid(ref):
            print(f"!! panel{idx}.png 缺失，先执行 panels", flush=True)
            return False
        prompt = (cfg.get("refine_prompt") or REFINE_PROMPT) + \
            f"。该图人物唯一的姿势动作与穿着：{pose['description']}。"
        if pform == "maas":
            print(f"生成 pose{idx} · {pose['name']}（MaaS 图生图·参考图整格提质）…", flush=True)
            f = gen_maas(prompt, out_dir, f"pose{idx} {pose['name']}", ref=ref)
        else:
            print(f"生成 pose{idx} · {pose['name']}（HAPI 图生图·参考图整格提质）…", flush=True)
            f = gen_hapi(prompt, out_dir, f"pose{idx} {pose['name']}", ref=ref, fidelity="high")
    else:
        anchor = out_dir / "_refs" / "anchor.png"
        if not valid(anchor):
            print("!! 锚点缺失，先执行 anchor", flush=True)
            return False
        if pform == "maas":
            print(f"生成 pose{idx} · {pose['name']}（MaaS 图生图·锚点换姿势）…", flush=True)
            f = gen_maas(pose_prompt(cfg, pose), out_dir, f"pose{idx} {pose['name']}", ref=anchor)
        else:
            print(f"生成 pose{idx} · {pose['name']}（HAPI 图生图·锚点换姿势）…", flush=True)
            f = gen_hapi(pose_prompt(cfg, pose), out_dir, f"pose{idx} {pose['name']}", ref=anchor)
    if not f:
        return False
    f.replace(target)
    print(f"pose{idx} -> {target.name}", flush=True)
    return True


def step_sil(cfg, out_dir: Path, idx: int, force: bool, pform: str = "hapi") -> bool:
    """由 pose{idx}.png 生成 pose{idx}_sil.png（白底黑线稿 → 透明底黑线）"""
    target = out_dir / f"pose{idx}_sil.png"
    if valid(target) and not force:
        print(f"跳过 pose{idx} 剪影（已存在）", flush=True)
        return True
    src = out_dir / f"pose{idx}.png"
    if not valid(src):
        print(f"!! pose{idx}.png 缺失，先执行 poses", flush=True)
        return False
    if pform == "maas":
        print(f"生成 pose{idx} 剪影（MaaS 文生图·按姿势描述 + 本地二值化）…", flush=True)
        pose_desc = cfg["poses"][idx - 1]["description"]
        raw = gen_maas(
            SIL_PROMPT + "。" + f"人物姿势：{pose_desc}。",
            out_dir, f"pose{idx} 剪影")
    else:
        print(f"生成 pose{idx} 剪影（HAPI 图生图 + 本地二值化）…", flush=True)
        raw = gen_hapi(SIL_PROMPT, out_dir, f"pose{idx} 剪影", ref=src)
    if not raw:
        return False
    # 原始白底图留档，便于不重复调用接口重新后处理
    keep = out_dir / "_refs" / "sil_raw"
    keep.mkdir(parents=True, exist_ok=True)
    raw.replace(keep / f"pose{idx}_sil_raw.png")
    img = crop_to_content(binarize_to_transparent(keep / f"pose{idx}_sil_raw.png"))
    img.save(target)
    print(f"pose{idx} 剪影 -> {target.name} {img.size}", flush=True)
    return True


def write_docs(cfg, out_dir: Path):
    """产出 pose_images.json（姿势名→文件）与 template.pptpl（模板 5 段结构）"""
    poses = cfg["poses"]
    mapping = {p["name"]: f"pose{i}.png" for i, p in enumerate(poses, 1)}
    (out_dir / "pose_images.json").write_text(
        json.dumps(mapping, ensure_ascii=False, indent=2), encoding="utf-8")

    pptpl = {
        "format": "pptpl",
        "version": "1.0.0",
        "_meta": {
            "name": cfg["name"],
            "author": "Lumira",
            "category": "portrait",
            "price": 0,
            "description": cfg["description"],
            "shortDesc": cfg["short_desc"],
            "tags": [t.strip() for t in cfg["tags"].split(",") if t.strip()],
            "referenceSource": cfg["reference_source"],
            "classification": {
                "type": "portrait",
                "majorStyle": cfg["classification"]["majorStyle"],
                "style": cfg["classification"]["style"],
                "subStyle": cfg["classification"]["style"],
                "method": cfg["classification"]["method"],
            },
            "ambience": cfg["ambience"],
        },
        "composition": {
            "overlayType": "rule_of_thirds",
            "aspectRatio": "3:4",
            "opacity": 0.5,
            "description": cfg.get("docOverride", {}).get(
                "compositionDescription",
                "竖版 3:4，三分法构图。人物全身置于画面中下部，顶部保留雪山与云海留白；"
                "峰顶岩石压住画面下缘形成前后景层次，云海水平线放在画面上 1/3 处。",
            ),
        },
        "pose": [
            {
                "name": p["name"],
                "silhouette": {"type": "image", "data": f"pose{i}_sil.png"},
                "position": {"x": 0.5, "y": 0.55},
                "scale": 1.0,
                "rotation": 0,
                "description": p["description"],
                "cameraDirection": "back",
            }
            for i, p in enumerate(poses, 1)
        ],
        "camera": {
            "exposureCompensation": 0.3,
            "isoMode": "auto",
            "iso": 200,
            "shutterSpeed": "1/500",
            "whiteBalance": "daylight",
            "whiteBalanceK": 5600,
            "flashMode": "off",
            "focusMode": "auto",
            "lensType": "26mm",
            "lensSuggestion": "main",
        },
        "sceneGuide": cfg.get("docOverride", {}).get(
            "sceneGuide",
            {
                "lightDirection": "午后侧逆光，主光从画面左后方约 135° 打来，人物边缘勾出轮廓光，正面由雪地与云海的高反射补光，光比约 3:1，整体冷调、皮肤保留暖色",
                "shootingDistance": "2.5-4m",
                "background": "花岗岩峰顶、连绵雪山与翻涌云海，冷调天空带少量云层；避免杂乱植被与人群",
                "props": ["登山杖", "轻量登山背包", "针织帽", "雪山护目镜"],
                "bestTime": "晴日午后 14:00-17:00（云海最稳定）",
                "tips": [
                    "长按锁定对焦，云海与雪山明暗反差大时略微降低曝光补偿保住天空层次。",
                    "人物尽量落在岩石边缘并留出身后云海，避免与山体轮廓重叠糊在一起。",
                    "侧逆光时开启 HDR 或补一点正面反光板，别让面部完全压暗。",
                    "穿暖色外衣与冷调环境形成冷暖对比，避免全身同色系淹没在背景里。",
                    "注意脚下与风力，峰顶岩石湿滑，优先保证安全与稳定握持。",
                ],
            },
        ),
        "postProcess": cfg.get("docOverride", {}).get(
            "postProcess",
            {
                "cropRatio": "3:4",
                "color": {
                    "brightness": 3,
                    "contrast": 12,
                    "saturation": -6,
                    "temperature": -8,
                    "tint": 2,
                    "highlights": -18,
                    "shadows": 12,
                },
                "smoothStrength": 10,
                "sharpen": 18,
                "vignette": 14,
                "grain": 14,
                "lut": "cool_film",
            },
        ),
    }
    (out_dir / "template.pptpl").write_text(
        json.dumps(pptpl, ensure_ascii=False, indent=2), encoding="utf-8")
    print("已产出 pose_images.json 与 template.pptpl", flush=True)


# ---------------------------------------------------------------- 入口

def main():
    ap = argparse.ArgumentParser(description="线上模板批量生产（姿势图/剪影图）")
    ap.add_argument("key", help=f"模板 key，可选: {', '.join(TEMPLATES)}")
    ap.add_argument("step",
                    choices=["panels", "anchor", "poses", "sil", "doc", "sample", "all"])
    ap.add_argument("--from", dest="source", choices=["panel", "anchor"], default="panel",
                    help="姿势图路线：panel=参考图整格提质（默认），anchor=锚点换姿势")
    ap.add_argument("--pose-platform", choices=["hapi", "maas"], default="hapi",
                    help="panel 路线提质所用平台：hapi=gpt-image-2（默认），maas=qwen-image-3.0-pro")
    ap.add_argument("--force", action="store_true", help="强制重生成（忽略已有文件）")
    args = ap.parse_args()

    cfg = TEMPLATES.get(args.key)
    if cfg is None:
        print(f"未知模板 key: {args.key}，可选: {', '.join(TEMPLATES)}", flush=True)
        sys.exit(1)
    out_dir = OUT_ROOT / args.key
    out_dir.mkdir(parents=True, exist_ok=True)
    n = len(cfg["poses"])
    src = args.source

    def ensure_ready() -> bool:
        """按所选路线准备底图：panel 需切格，anchor 需锚点"""
        if src == "panel":
            return step_panels(out_dir, args.force)
        return step_anchor(cfg, out_dir, args.force)

    if args.step == "panels":
        step_panels(out_dir, args.force)
    elif args.step == "anchor":
        step_anchor(cfg, out_dir, args.force)
    elif args.step == "sample":
        # 样张：底图 + 第 1 张姿势图 + 第 1 张剪影
        if ensure_ready():
            if step_pose(cfg, out_dir, 1, args.force, source=src, pform=args.pose_platform):
                step_sil(cfg, out_dir, 1, args.force, pform=args.pose_platform)
    elif args.step == "poses":
        if not ensure_ready():
            sys.exit(1)
        for i in range(1, n + 1):
            step_pose(cfg, out_dir, i, args.force, source=src, pform=args.pose_platform)
    elif args.step == "sil":
        for i in range(1, n + 1):
            step_sil(cfg, out_dir, i, args.force, pform=args.pose_platform)
    elif args.step == "doc":
        write_docs(cfg, out_dir)
    else:  # all
        if ensure_ready():
            for i in range(1, n + 1):
                step_pose(cfg, out_dir, i, args.force, source=src, pform=args.pose_platform)
            for i in range(1, n + 1):
                step_sil(cfg, out_dir, i, args.force, pform=args.pose_platform)
            write_docs(cfg, out_dir)

    print(f"输出目录: {out_dir}", flush=True)


if __name__ == "__main__":
    main()
