// lib/features/home/data/tip_knowledge_base.dart
//
// 拍照小贴士知识库
// 按 category × 自拍/他拍 维度组织，每个分类若干条贴士
// TipRecommendationService 命中后随机取 N 条返回
//
// 复用 home_mock_data.dart 的 ShootingTip 模型

import 'home_mock_data.dart';

/// 拍摄主体类型
enum ShootSubject {
  /// 自拍
  selfie,
  /// 他拍（拍别人）
  other,
}

/// 小贴士知识库
/// key = category, value = { selfie?: List<ShootingTip>, other?: List<ShootingTip> }
/// 若某 category 不区分自拍/他拍，仅提供 other 即可
class TipKnowledgeBase {
  TipKnowledgeBase._();

  static const Map<String, Map<ShootSubject, List<ShootingTip>>> _kb = {
    'portrait': {
      ShootSubject.selfie: [
        ShootingTip(
          text: '自拍侧 45° 角：让脸部一侧轻微转向光源，显瘦又立体',
          sub: '— 适合窗边或柔光环境',
        ),
        ShootingTip(
          text: '自拍手伸直略高于眼睛：俯拍 15° 显脸小，避免双下巴',
          sub: '— 手机略向上倾斜',
        ),
        ShootingTip(
          text: '自拍用后置主摄+定时 3 秒：画质比前置摄像头高一档',
          sub: '— 配三脚架或稳定物',
        ),
        ShootingTip(
          text: '自拍眼神光：面对光源（窗/灯），眼睛里会出现亮点',
          sub: '— 让眼神更有神',
        ),
        ShootingTip(
          text: '自拍背景简洁：选纯色墙或虚化绿植，避免杂物抢戏',
          sub: '— 大光圈或人像模式',
        ),
        ShootingTip(
          text: '自拍表情自然：闭眼深呼吸再睁开的瞬间按下快门',
          sub: '— 避免僵硬假笑',
        ),
      ],
      ShootSubject.other: [
        ShootingTip(
          text: '他拍侧逆光：让模特侧向镜头，光从侧后方打来，发丝有金边',
          sub: '— 适合午后窗边或树下',
        ),
        ShootingTip(
          text: '他拍引导视线：让模特看远方或低头，比直视镜头更自然',
          sub: '— 情绪感更强',
        ),
        ShootingTip(
          text: '他拍手部姿态：让模特手扶帽檐、整理头发或拿道具',
          sub: '— 避免手不知道放哪',
        ),
        ShootingTip(
          text: '他拍眼睛对焦：单次对焦锁定眼睛，再构图拍摄',
          sub: '— 人像核心原则',
        ),
        ShootingTip(
          text: '他拍构图留白：人物视线方向留出空间，画面更透气',
          sub: '— 三分构图法',
        ),
        ShootingTip(
          text: '他拍沟通引导：让模特走动或转身抓拍，比摆拍更生动',
          sub: '— 连拍模式抓瞬间',
        ),
      ],
    },
    'landscape': {
      ShootSubject.other: [
        ShootingTip(
          text: '风光前景构图：找岩石、花朵或溪流做前景，层次更丰富',
          sub: '— 广角镜头低角度',
        ),
        ShootingTip(
          text: '风光黄金时刻：日出后或日落前 1 小时光线暖黄柔和',
          sub: '— 提前踩点等光线',
        ),
        ShootingTip(
          text: '风光加偏振镜：消除反光，天空更蓝，树叶更饱和',
          sub: '— 顺光效果最佳',
        ),
        ShootingTip(
          text: '风光长曝光流水：用 ND 镜 + 1-3 秒快门，水流如丝绸',
          sub: '— 需三脚架',
        ),
        ShootingTip(
          text: '风光引导线：用道路、河流或山脊线引导视线到主体',
          sub: '— 增强纵深',
        ),
        ShootingTip(
          text: '风光拍全景接片：横向 3-5 张接片，超广角变形更小',
          sub: '— 后期合成',
        ),
      ],
    },
    'food': {
      ShootSubject.other: [
        ShootingTip(
          text: '美食俯拍平铺： overhead 90° 俯拍，桌面摆件构成画面',
          sub: '— 适合咖啡甜点',
        ),
        ShootingTip(
          text: '美食侧 45°：侧斜角拍出层次和高度，立体感更强',
          sub: '— 适合汉堡蛋糕',
        ),
        ShootingTip(
          text: '美食自然光：靠窗用日光，关闭室内灯避免色温混杂',
          sub: '— 白平衡更准',
        ),
        ShootingTip(
          text: '美食道具搭配：餐具、餐巾、原料作配，画面更丰富',
          sub: '— 注意不要喧宾夺主',
        ),
        ShootingTip(
          text: '美食热气捕捉：刚上桌时拍摄，利用热气增加食欲感',
          sub: '— 暗背景更明显',
        ),
        ShootingTip(
          text: '美食局部特写：拍食物纹理或切面，细节更诱人',
          sub: '— 微距或大光圈',
        ),
      ],
    },
    'street': {
      ShootSubject.other: [
        ShootingTip(
          text: '街拍等待构图：先找好背景，等主体走入画面再按快门',
          sub: '— 决定性瞬间',
        ),
        ShootingTip(
          text: '街拍盲拍：相机挂胸前不抬手，广角盲拍抓自然状态',
          sub: '— 28-35mm 焦段',
        ),
        ShootingTip(
          text: '街拍光影对比：找阴阳交界处，等主体走入光区',
          sub: '— 戏剧感强',
        ),
        ShootingTip(
          text: '街拍背影故事：人物背影 + 远方场景，留想象空间',
          sub: '— 情绪感',
        ),
        ShootingTip(
          text: '街拍雨后倒影：路面水洼拍倒影，画面翻倍',
          sub: '— 低角度贴近水面',
        ),
        ShootingTip(
          text: '街拍黑白：复杂场景转黑白，突出几何与情绪',
          sub: '— 后期或直拍',
        ),
      ],
    },
    'night': {
      ShootSubject.other: [
        ShootingTip(
          text: '夜景稳定拍摄：找栏杆、墙沿当支撑，或用三脚架',
          sub: '— 避免抖动',
        ),
        ShootingTip(
          text: '夜景蓝调时刻：日落后 30 分钟天空深蓝，城市灯光已亮',
          sub: '— 最佳夜景时段',
        ),
        ShootingTip(
          text: '夜景霓虹人像：让人物靠近霓虹招牌，色光染发丝',
          sub: '— 赛博朋克感',
        ),
        ShootingTip(
          text: '夜景车轨长曝光：2-5 秒快门拍车灯轨迹',
          sub: '— 需三脚架',
        ),
        ShootingTip(
          text: '夜景高 ISO 权衡：ISO 800-1600 + 大光圈 + 1/30s',
          sub: '— 既能保画质又防抖',
        ),
        ShootingTip(
          text: '夜景手动对焦：暗处自动对焦易失败，估焦或峰值对焦',
          sub: '— 提前预对焦',
        ),
      ],
    },
    'macro': {
      ShootSubject.other: [
        ShootingTip(
          text: '微距稳定：任何微风都让主体模糊，用高速快门 1/500+',
          sub: '— 或用环闪补光',
        ),
        ShootingTip(
          text: '微距景深极浅：f/8-11 光圈，对焦在眼睛或花蕊',
          sub: '— 景深合成更稳',
        ),
        ShootingTip(
          text: '微距晨露：清晨 6-8 点花草有露珠，自带装饰',
          sub: '— 最佳微距时段',
        ),
        ShootingTip(
          text: '微距散景：背景离主体越远越虚化，色斑更圆',
          sub: '— 避免杂乱背景',
        ),
        ShootingTip(
          text: '微距昆虫：先对焦再慢慢靠近，连拍 5-10 张',
          sub: '— 不要惊扰',
        ),
        ShootingTip(
          text: '微距用环闪或柔光：直射硬光会让高光过曝',
          sub: '— 柔光罩必备',
        ),
      ],
    },
    'still-life': {
      ShootSubject.other: [
        ShootingTip(
          text: '静物侧光：单一窗户侧光 90°，明暗对比有油画感',
          sub: '— 古典静物画法',
        ),
        ShootingTip(
          text: '静物道具呼应：颜色或形状呼应，画面更整体',
          sub: '— 三件套法则',
        ),
        ShootingTip(
          text: '静物留白：画面 1/3 留白，主体不占满，呼吸感',
          sub: '— 极简风',
        ),
        ShootingTip(
          text: '静物质感：侧光突出纹理，逆光突出轮廓',
          sub: '— 玻璃/金属各有打法',
        ),
        ShootingTip(
          text: '静物背景：纯色绒布或木纹板，避免反光',
          sub: '— 与主体色对比',
        ),
        ShootingTip(
          text: '静物构图：三角构图最稳，对角线构图更有动感',
          sub: '— 经典构图法',
        ),
      ],
    },
  };

  /// 通用贴士（无 category 数据时使用）
  static const List<ShootingTip> generalTips = [
    ShootingTip(
      text: '三分构图：将主体放在画面九宫格交叉点上，让画面更平衡有张力',
      sub: '— 适合所有场景',
    ),
    ShootingTip(
      text: '黄金时刻：日出后或日落前 1 小时，光线柔和暖黄，适合拍摄人像与风光',
      sub: '— 注意提前踩点',
    ),
    ShootingTip(
      text: '前景遮挡：用花草、树叶、玻璃等作为前景，增加画面层次感',
      sub: '— 适合静物与人像',
    ),
    ShootingTip(
      text: '寻找引导线：道路、河流、栏杆引导视线到主体，画面更有纵深',
      sub: '— 风光街拍通用',
    ),
    ShootingTip(
      text: '低角度拍摄：蹲下或贴地，看到的视角更新鲜',
      sub: '— 适合儿童宠物',
    ),
    ShootingTip(
      text: '留白构图：主体周围留出空间，画面更透气、更有想象空间',
      sub: '— 极简风格',
    ),
  ];

  /// 按 category + subject 取贴士列表
  /// 若指定 subject 无数据，自动 fallback 到 other
  /// 若整个 category 无数据，返回 null（由调用方 fallback 到 generalTips）
  static List<ShootingTip> getTips(String category, ShootSubject subject) {
    final entry = _kb[category];
    if (entry == null) return const [];
    final list = entry[subject];
    if (list != null && list.isNotEmpty) return list;
    // fallback 到 other
    return entry[ShootSubject.other] ?? const [];
  }
}
