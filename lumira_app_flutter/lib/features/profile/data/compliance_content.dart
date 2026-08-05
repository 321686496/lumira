/// 合规文档（用户协议 / 隐私政策 / 个人信息清单与SDK目录）结构化数据。
///
/// 国内 App 上架合规要求。内容为正式占位文本，后续可替换为法务审核后的正式版本。

/// 一个章节：小节标题 + 若干正文块
class ComplianceSection {
  const ComplianceSection({required this.title, required this.blocks});

  final String title;
  final List<ComplianceBlock> blocks;
}

/// 正文块基类
abstract class ComplianceBlock {
  const ComplianceBlock();
}

/// 段落正文
class ComplianceParagraph extends ComplianceBlock {
  const ComplianceParagraph(this.text);

  final String text;
}

/// 「字段 / 内容」键值行（用于清单类条目字段）
class ComplianceKVRow extends ComplianceBlock {
  const ComplianceKVRow({required this.label, required this.value});

  final String label;
  final String value;
}

/// 带标题的列表项（用于个人信息清单 / SDK 目录中的单个条目）
class ComplianceListItem extends ComplianceBlock {
  const ComplianceListItem({required this.title, required this.rows});

  final String title;
  final List<ComplianceKVRow> rows;
}

/// 3 篇合规文档的入口
class ComplianceDocs {
  ComplianceDocs._();

  // ===== 用户协议 =====
  static const String agreementUpdatedAt = '2026-08-05';

  static const List<ComplianceSection> agreement = [
    ComplianceSection(
      title: '协议的接受与范围',
      blocks: [
        ComplianceParagraph(
          '欢迎使用「如画 Lumira」。在使用本应用前，请您仔细阅读并充分理解本用户协议的全部内容。您点击同意、开始使用或继续使用本应用，即视为您已阅读并同意接受本协议的约束。',
        ),
        ComplianceParagraph(
          '如您为未成年人，请在监护人陪同下阅读本协议，并在取得监护人同意后使用本应用。',
        ),
      ],
    ),
    ComplianceSection(
      title: '服务内容',
      blocks: [
        ComplianceParagraph(
          '本应用提供摄影模板、拍摄指导、作品管理与分享等线上服务。我们可能根据产品规划对服务内容进行增加、调整或下线，并将通过合理方式向您告知。',
        ),
      ],
    ),
    ComplianceSection(
      title: '账号与行为规范',
      blocks: [
        ComplianceParagraph(
          '您应妥善保管账号与登录凭证，不得出借、转让或与他人共享。因您保管不善导致的损失由您自行承担。',
        ),
        ComplianceParagraph(
          '您承诺在使用本应用时不发布、传播法律法规禁止的内容，不从事任何侵犯他人合法权益或危害网络安全的行为。',
        ),
      ],
    ),
    ComplianceSection(
      title: '知识产权',
      blocks: [
        ComplianceParagraph(
          '本应用所展示的界面、文案、模板素材、软件程序等内容的知识产权归我们或相关权利人所有。未经许可，您不得以任何形式复制、修改、传播或用于商业用途。',
        ),
        ComplianceParagraph(
          '您通过本应用创作的作品，其著作权归您所有。您授权我们在为您提供服务的必要范围内使用您的作品。',
        ),
      ],
    ),
    ComplianceSection(
      title: '免责声明',
      blocks: [
        ComplianceParagraph(
          '我们将尽合理努力保障服务的稳定与安全，但因不可抗力、网络故障、第三方服务异常等原因导致服务中断或数据丢失的，我们将在法律允许的范围内免除责任。',
        ),
      ],
    ),
    ComplianceSection(
      title: '协议的变更与终止',
      blocks: [
        ComplianceParagraph(
          '我们可能根据法律法规或业务需要修订本协议。修订后的协议将在应用内公布，若您继续使用本应用，即视为接受修订后的协议。',
        ),
        ComplianceParagraph(
          '如您违反本协议约定，我们有权视情况采取警示、限制功能、暂停或终止服务等措施。',
        ),
      ],
    ),
    ComplianceSection(
      title: '法律适用与争议解决',
      blocks: [
        ComplianceParagraph(
          '本协议的订立、履行与解释均适用中华人民共和国法律。因本协议产生的争议，双方应友好协商解决；协商不成的，任何一方可向有管辖权的人民法院提起诉讼。',
        ),
      ],
    ),
    ComplianceSection(
      title: '联系我们',
      blocks: [
        ComplianceKVRow(label: '官方邮箱', value: 'hello@lumira.app'),
        ComplianceKVRow(label: '用户反馈', value: 'feedback@lumira.app'),
      ],
    ),
  ];

  // ===== 隐私政策 =====
  static const String privacyUpdatedAt = '2026-08-05';

  static const List<ComplianceSection> privacy = [
    ComplianceSection(
      title: '引言',
      blocks: [
        ComplianceParagraph(
          '我们深知个人信息对您的重要性，并会尽全力保护您的个人信息安全。本隐私政策旨在说明我们如何收集、使用、存储、共享和保护您的个人信息，以及您享有的相关权利。',
        ),
      ],
    ),
    ComplianceSection(
      title: '我们收集的信息',
      blocks: [
        ComplianceParagraph('在您使用本应用的过程中，我们可能会收集以下类别的信息：'),
        ComplianceListItem(
          title: '账号信息',
          rows: [
            ComplianceKVRow(label: '信息类型', value: '昵称、头像、联系方式（如您主动提供）'),
            ComplianceKVRow(label: '使用目的', value: '用于账号注册、登录与身份验证'),
            ComplianceKVRow(label: '是否必需', value: '否，仅在您主动填写时收集'),
          ],
        ),
        ComplianceListItem(
          title: '设备信息',
          rows: [
            ComplianceKVRow(label: '信息类型', value: '设备型号、操作系统版本、设备标识符'),
            ComplianceKVRow(label: '使用目的', value: '用于保障服务安全、排查故障与统计分析'),
            ComplianceKVRow(label: '是否必需', value: '是，用于基础功能运行'),
          ],
        ),
        ComplianceListItem(
          title: '作品数据',
          rows: [
            ComplianceKVRow(label: '信息类型', value: '您拍摄的照片、创作的作品与相关设置'),
            ComplianceKVRow(label: '使用目的', value: '用于为您提供拍摄、编辑与作品管理功能'),
            ComplianceKVRow(label: '是否必需', value: '是，为功能核心数据'),
          ],
        ),
      ],
    ),
    ComplianceSection(
      title: '信息的使用目的',
      blocks: [
        ComplianceParagraph(
          '我们仅在实现以下目的所必需的范围内使用您的信息：提供与维护服务、改进产品体验、保障账户与网络安全、履行法律法规义务。',
        ),
      ],
    ),
    ComplianceSection(
      title: '信息的存储与保护',
      blocks: [
        ComplianceParagraph(
          '您的作品数据默认保存在您的设备本地。若您使用云端相关功能，数据将存储于中国大陆境内的服务器。',
        ),
        ComplianceParagraph(
          '我们采用加密传输、访问控制等合理的技术与管理措施保护您的个人信息，并定期开展安全评估。',
        ),
      ],
    ),
    ComplianceSection(
      title: '信息的共享与第三方服务',
      blocks: [
        ComplianceParagraph(
          '我们不会向第三方出售您的个人信息。仅在与第三方 SDK 提供方合作、且为实现基本功能所必需时，我们才会共享必要的信息，具体见《个人信息清单与第三方 SDK 目录》。',
        ),
      ],
    ),
    ComplianceSection(
      title: '您的权利',
      blocks: [
        ComplianceParagraph(
          '您有权查询、更正、删除您的个人信息，有权撤回授权同意，并有权注销您的账号。您可以通过本政策底部提供的联系方式行使上述权利，我们将在 15 个工作日内予以响应。',
        ),
      ],
    ),
    ComplianceSection(
      title: '未成年人保护',
      blocks: [
        ComplianceParagraph(
          '我们非常重视未成年人的个人信息保护。若您为未满 14 周岁的儿童，请在监护人同意和指导下使用本应用；如我们发现在未取得监护人同意的情况下收集了儿童个人信息，将尽快删除相关数据。',
        ),
      ],
    ),
    ComplianceSection(
      title: '政策的更新',
      blocks: [
        ComplianceParagraph(
          '我们可能适时修订本隐私政策。重大变更将以应用内显著方式通知您，您继续使用本应用即视为接受修订后的政策。',
        ),
      ],
    ),
    ComplianceSection(
      title: '联系我们',
      blocks: [
        ComplianceKVRow(label: '隐私保护负责人邮箱', value: 'privacy@lumira.app'),
        ComplianceKVRow(label: '用户反馈', value: 'feedback@lumira.app'),
      ],
    ),
  ];

  // ===== 个人信息清单与第三方 SDK 目录 =====
  static const String sdkUpdatedAt = '2026-08-05';

  static const List<ComplianceSection> sdk = [
    ComplianceSection(
      title: '个人信息收集使用清单',
      blocks: [
        ComplianceListItem(
          title: '基础功能运行',
          rows: [
            ComplianceKVRow(label: '收集场景', value: '启动应用、浏览首页'),
            ComplianceKVRow(label: '信息类型', value: '设备型号、操作系统版本、设备标识符'),
            ComplianceKVRow(label: '使用目的', value: '保障服务稳定运行、故障排查'),
            ComplianceKVRow(label: '是否必需', value: '是'),
          ],
        ),
        ComplianceListItem(
          title: '账号注册与登录',
          rows: [
            ComplianceKVRow(label: '收集场景', value: '注册、登录'),
            ComplianceKVRow(label: '信息类型', value: '昵称、头像、联系方式'),
            ComplianceKVRow(label: '使用目的', value: '身份验证与账号管理'),
            ComplianceKVRow(label: '是否必需', value: '否，仅在主动填写时收集'),
          ],
        ),
        ComplianceListItem(
          title: '拍摄与作品管理',
          rows: [
            ComplianceKVRow(label: '收集场景', value: '拍摄照片、编辑作品'),
            ComplianceKVRow(label: '信息类型', value: '照片、作品数据与相关设置'),
            ComplianceKVRow(label: '使用目的', value: '提供拍摄与编辑功能'),
            ComplianceKVRow(label: '是否必需', value: '是'),
          ],
        ),
      ],
    ),
    ComplianceSection(
      title: '第三方 SDK 目录',
      blocks: [
        ComplianceParagraph('为实现以下功能，我们接入了第三方 SDK。相关 SDK 仅在您使用对应功能时收集必要信息：'),
        ComplianceKVRow(label: 'SDK 目录更新日期', value: '2026-08-05'),
        ComplianceListItem(
          title: '统计分析 SDK',
          rows: [
            ComplianceKVRow(label: 'SDK 名称', value: '基础统计服务'),
            ComplianceKVRow(label: '提供方', value: '本应用运营方自建'),
            ComplianceKVRow(label: '使用目的', value: '崩溃日志与使用统计'),
            ComplianceKVRow(label: '收集的信息', value: '设备型号、操作系统版本、崩溃日志'),
          ],
        ),
        ComplianceListItem(
          title: '图像处理能力',
          rows: [
            ComplianceKVRow(label: 'SDK 名称', value: '本地图像处理组件'),
            ComplianceKVRow(label: '提供方', value: '本应用内置组件'),
            ComplianceKVRow(label: '使用目的', value: '照片编辑、滤镜与模板合成'),
            ComplianceKVRow(label: '收集的信息', value: '不收集，均在设备本地完成'),
          ],
        ),
      ],
    ),
  ];
}
