/// 自定义模板分享凭证（后端 `POST/GET /templates/share` 返回）。
class ShareToken {
  /// 分享 token（base64url 字符串），用于二维码 / 终端拉取分享内容。
  final String token;

  /// 分享过期时间（Unix 秒级时间戳）。
  final int expiresAt;

  const ShareToken({required this.token, required this.expiresAt});

  factory ShareToken.fromJson(Map<String, dynamic> json) {
    return ShareToken(
      token: json['token'] as String,
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
    );
  }
}