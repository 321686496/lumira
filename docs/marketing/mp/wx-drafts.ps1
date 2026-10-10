# 微信公众号草稿批量推送脚本（build / upload / submit 三阶段）
# 凭证从 $env:TEMP\wx-drafts\cred.txt 读取（appid|secret），不落仓库
param([Parameter(Mandatory=$true)][ValidateSet('build','upload','submit')]$Phase)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http

$work   = "$env:TEMP\wx-drafts"
$cred   = (Get-Content "$work\cred.txt" -Raw).Trim().Split('|')
$appid  = $cred[0]; $secret = $cred[1]
$mpDir  = 'd:\app\projects\photo_post\docs\marketing\mp'
$author = '如画 Lumira'

$articles = @(
  @{ slug='00-quanlan'; html="$mpDir\lumira-mp-20261010\index.html";       cover="$mpDir\lumira-mp-20261010\assets\wx-00-header.png";
    title='拍照 300 张只能发出 1 张？我一个人用 AI 写了个 App，专治「罚站式游客照」';
    digest='不会摆姿势、不会构图、后期调参总翻车？套个模板，照着拍，就能出片。' },
  @{ slug='01-yugao';   html="$mpDir\lumira-mp-series-20261010\01-预告篇.html"; cover="$mpDir\lumira-mp-20261010\assets\wx-00-header.png";
    title='被男朋友拍成“消失的她”之后，我决定自己写个 App';
    digest='不会摆姿势、不会构图、后期调参总翻车？我受够了“拍了等于白拍”，所以自己动手了。' },
  @{ slug='02-gongneng'; html="$mpDir\lumira-mp-series-20261010\02-功能篇.html"; cover="$mpDir\lumira-mp-20261010\assets\wx-02-template.png";
    title='一口气讲清：这个拍照 App 的 7 个功能，全是冲着痛点去的';
    digest='上篇说要治「罚站式游客照」，这次把药方全部公开：套模板、搜模板、实时调参、探店精选集、模板分享、自制模板、今日灵感。' },
  @{ slug='03-qinggan'; html="$mpDir\lumira-mp-series-20261010\03-情感篇.html"; cover="$mpDir\lumira-mp-20261010\assets\wx-05-explore.png";
    title='相册里躺着的 3000 张照片，你翻过几次？';
    digest='拍完就吃灰，是大多数照片的宿命。我们想给它们一个出口——把平凡的日子，拍成一本漂亮的日记。' },
  @{ slug='04-B-tongdian'; html="$mpDir\lumira-mp-series-20261010\04-B-痛点切入版.html"; cover="$mpDir\lumira-mp-20261010\assets\wx-b0-cover.png";
    title='拍照总是尬站？我们把“照着拍就能出片”这件事做成了 App';
    digest='不会摆姿势、不懂构图，拍十张废九张。我们把“照着拍就能出片”这件事，做成了一个 App。' },
  @{ slug='05-C-gongming'; html="$mpDir\lumira-mp-series-20261010\05-C-情绪共鸣版.html"; cover="$mpDir\lumira-mp-20261010\assets\wx-c0-cover.png";
    title='如画 Lumira 上架了｜不会摆姿势的人，也配拥有好看的照片';
    digest='不会摆姿势，不是你的错。我们做了一个 App，想让你拥有一张配得上今天的照片。' }
)

function Get-Token {
  $p = @{ grant_type='client_credential'; appid=$appid; secret=$secret }
  $r = Invoke-RestMethod -Uri 'https://api.weixin.qq.com/cgi-bin/token' -Body $p -TimeoutSec 20
  if (-not $r.access_token) { throw "token失败: $($r | ConvertTo-Json -Compress)" }
  return $r.access_token
}

function Upload-Image($client, $token, $path, $api) {
  $url = "https://api.weixin.qq.com/cgi-bin/$api`?access_token=$token"
  if ($api -eq 'material/add_material') { $url += '&type=image' }
  $out = & curl.exe -s -S $url -F "media=@`"$path`";type=image/png" 2>&1
  $body = ($out -join '')
  return $body | ConvertFrom-Json
}

if ($Phase -eq 'build') {
  $map = @{}
  $built = @()
  foreach ($a in $articles) {
    $html = [System.IO.File]::ReadAllText($a.html, [System.Text.Encoding]::UTF8)
    $m = [regex]::Match($html, '<div class="article" id="content">([\s\S]*?)</div>')
    if (-not $m.Success) { throw "未提取到正文: $($a.slug)" }
    $content = $m.Groups[1].Value.Trim()
    $imgs = [regex]::Matches($content, 'src="([^"]+\.png)"') | ForEach-Object {
      $src = $_.Groups[1].Value
      if ($src -notmatch '^https?://') { [System.IO.Path]::GetFullPath((Join-Path (Split-Path $a.html) $src)) } else { $src }
    } | Select-Object -Unique
    foreach ($i in $imgs) { if (-not (Test-Path $i)) { throw "图片不存在: $i" } }
    [System.IO.File]::WriteAllText((Join-Path $work "$($a.slug).content.html"), $content, [System.Text.Encoding]::UTF8)
    $built += [pscustomobject]@{ slug=$a.slug; titleLen=$a.title.Length; digestLen=$a.digest.Length; contentLen=$content.Length; imgCount=($imgs | Measure-Object).Count }
    foreach ($i in $imgs) { $map[$i] = $true }
  }
  ($map.Keys | Sort-Object) | ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $work 'image-list.json')
  "===== 待传图片 $($map.Count) 张 ====="
  $map.Keys | Sort-Object | ForEach-Object { Split-Path $_ -Leaf }
  "===== 文章概览 ====="
  $built | Format-Table slug, titleLen, digestLen, contentLen, imgCount -AutoSize | Out-String
}

if ($Phase -eq 'upload') {
  $client  = New-Object System.Net.Http.HttpClient
  $token   = Get-Token
  $imgList = Get-Content (Join-Path $work 'image-list.json') -Raw | ConvertFrom-Json
  $mapFile = Join-Path $work 'url-map.json'
  $urlMap  = if (Test-Path $mapFile) { Get-Content $mapFile -Raw | ConvertFrom-Json } else { New-Object psobject }
  $i = 0
  foreach ($img in $imgList) {
    $i++
    $leaf = Split-Path $img -Leaf
    if ($urlMap.PSObject.Properties.Name -contains $img) { "[$i/$($imgList.Count)] 已有: $leaf"; continue }
    $r = Upload-Image $client $token $img 'media/uploadimg'
    if ($r.url) { $urlMap | Add-Member -NotePropertyName $img -NotePropertyValue $r.url -Force; "[$i/$($imgList.Count)] OK: $leaf" }
    else { throw "上传失败 $leaf : $($r | ConvertTo-Json -Compress)" }
  }
  $urlMap | ConvertTo-Json | Out-File -Encoding utf8 $mapFile

  $coverFile = Join-Path $work 'cover-map.json'
  $coverMap  = if (Test-Path $coverFile) { Get-Content $coverFile -Raw | ConvertFrom-Json } else { New-Object psobject }
  $covers = $articles | ForEach-Object { $_.cover } | Select-Object -Unique
  $ci = 0
  foreach ($c in $covers) {
    $ci++
    $leaf = Split-Path $c -Leaf
    if ($coverMap.PSObject.Properties.Name -contains $c) { "[封面 $ci/$($covers.Count)] 已有: $leaf"; continue }
    $r = Upload-Image $client $token $c 'material/add_material'
    if ($r.media_id) { $coverMap | Add-Member -NotePropertyName $c -NotePropertyValue $r.media_id -Force; "[封面 $ci/$($covers.Count)] OK: $leaf" }
    else { throw "封面上传失败 $leaf : $($r | ConvertTo-Json -Compress)" }
  }
  $coverMap | ConvertTo-Json | Out-File -Encoding utf8 $coverFile
  "===== 上传完成 ====="
}

if ($Phase -eq 'submit') {
  $urlMap   = Get-Content (Join-Path $work 'url-map.json') -Raw | ConvertFrom-Json
  $coverMap = Get-Content (Join-Path $work 'cover-map.json') -Raw | ConvertFrom-Json
  $token    = Get-Token
  foreach ($a in $articles) {
    $content = [System.IO.File]::ReadAllText((Join-Path $work "$($a.slug).content.html"), [System.Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'src="([^"]+\.png)"', { param($m)
      $src = $m.Groups[1].Value
      if ($src -match '^https?://') { return $src }
      $abs = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $a.html) $src))
      $u = $urlMap.$abs
      if (-not $u) { throw "$($a.slug) 无映射: $abs" }
      return $u })
    $thumb = $coverMap.$($a.cover)
    if (-not $thumb) { throw "$($a.slug) 封面 media_id 缺失: $($a.cover)" }
    $art = @{ title=$a.title; author=$author; digest=$a.digest; content=$content;
              thumb_media_id=$thumb; need_open_comment=0; only_fans_can_comment=0 }
    $json  = @{ articles = @($art) } | ConvertTo-Json -Depth 6
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $resp = Invoke-RestMethod -Uri "https://api.weixin.qq.com/cgi-bin/draft/add`?access_token=$token" -Method Post -Body $bytes -ContentType 'application/json' -TimeoutSec 30
    if ($resp.media_id) { "[$($a.slug)] 草稿OK 《$($a.title)》" }
    else { "[$($a.slug)] 失败: $($resp | ConvertTo-Json -Compress)" }
  }
}
