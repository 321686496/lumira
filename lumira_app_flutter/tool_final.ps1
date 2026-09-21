$ErrorActionPreference = 'Stop'
$path = 'e:\Project\photo_post\lumira_app_flutter\lib\features\capture\pages\capture_preview_page.dart'
$c = [IO.File]::ReadAllText($path)

$pairs = @(
  @('  /// 右上角对比按钮：在「修改后」与「修改前（烘焙基线）」之间切换；', '  /// 右上角对比按钮：**按住**期间显示原图，**松开**恢复修改后；'),
  @('  /// 开启时短暂显示状态徽标（1s 后淡出），帮助用户理解当前看到的版本。', '  /// 按住期间显示状态徽标，松开即隐藏，帮助用户理解当前看到的版本。'),
  @("_isComparing ? '查看修改前' : '已回到修改后'", "'查看原图'")
)
foreach ($p in $pairs) {
  if (-not $c.Contains($p[0])) { throw ('NOT FOUND: ' + $p[0]) }
  $c = $c.Replace($p[0], $p[1])
}
[IO.File]::WriteAllText($path, $c, [System.Text.UTF8Encoding]::new($false))
Write-Output "DONE"