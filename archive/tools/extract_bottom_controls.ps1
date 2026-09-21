$ErrorActionPreference = 'Stop'
$src = 'd:\app\projects\photo_post\lumira_app_flutter\lib\features\capture\pages\capture_page.dart'
$dst = 'd:\app\projects\photo_post\lumira_app_flutter\lib\features\capture\widgets\capture_bottom_controls.dart'
$enc = New-Object System.Text.UTF8Encoding($false)

$origText = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
$nl = if ($origText.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = $origText.Split([string[]]@($nl), [StringSplitOptions]::None)

# Region A: lines 2488..4387 -> indices 2487..4386
# Region B: lines 4985..5056 (EOF) -> indices 4984..5055
$a = $lines[2487..4386]
$b = $lines[4984..5055]

$map = [ordered]@{
  '_BottomControlArea'     = 'CaptureBottomBar'
  '_ZoomBarState'          = 'ZoomBarState'
  '_ZoomBar'               = 'ZoomBar'
  '_ZoomTab'               = 'ZoomTab'
  '_HalfCircleDial'        = 'HalfCircleDial'
  '_HalfCircleTickPainter' = 'HalfCircleTickPainter'
  '_PointerPainter'        = 'PointerPainter'
  '_CaptureToolbar'        = 'CaptureToolbar'
  '_ToolDef'               = 'ToolDef'
  '_ToolButton'            = 'ToolButton'
  '_AnimatedToolDrawer'    = 'AnimatedToolDrawer'
  '_FillLightPanel'        = 'CaptureFillLightPanel'
  '_FillLightPreset'       = 'FillLightPreset'
  '_PresetColorDot'        = 'PresetColorDot'
  '_ActionDot'             = 'ActionDot'
  '_SquareColorPickerState'= 'SquareColorPickerState'
  '_SquareColorPicker'     = 'SquareColorPicker'
  '_SvPanelPainter'        = 'SvPanelPainter'
  '_HueBarPainter'         = 'HueBarPainter'
  '_SaveColorsRowState'    = 'SaveColorsRowState'
  '_SaveColorsRow'         = 'SaveColorsRow'
  '_SavedColorDot'         = 'SavedColorDot'
  '_CaptureButtonRow'      = 'CaptureButtonRow'
  '_LockedCaptureButton'   = 'LockedCaptureButton'
  '_CameraPermissionGuide' = 'CameraPermissionGuide'
  '_TrialWatermarkOverlay' = 'TrialWatermarkOverlay'
  '_TrialWatermarkPainter' = 'TrialWatermarkPainter'
  '_PoseSwitchButton'      = 'CapturePoseSwitchButton'
}
function Apply-Renames([string[]]$arr) {
  for ($k = 0; $k -lt $arr.Count; $k++) {
    foreach ($e in $map.GetEnumerator()) {
      $arr[$k] = $arr[$k].Replace($e.Key, $e.Value)
    }
  }
  return ,$arr
}

$a = Apply-Renames $a
$b = Apply-Renames $b

$header = (
'// Bottom control area widgets for the capture page, extracted (pure move)',
'// from capture_page.dart so the template preview page can reuse the exact',
'// same layout/controls as the real capture screen.',
'import ''dart:math'' as math;',
'',
'import ''package:flutter/material.dart'';',
'import ''package:flutter/services.dart''',
"    show HapticFeedback, SystemSound, SystemSoundType;",
'import ''package:flutter_riverpod/flutter_riverpod.dart'';',
'',
"import '../../../core/theme/theme_controller.dart';",
"import '../../../core/theme/theme_tokens.dart';",
"import '../data/capture_state.dart';",
"import '../data/custom_fill_light_colors.dart';",
"import '../domain/photo_template.dart';",
"import 'capture_button.dart';",
"import 'filter_picker.dart';",
"import 'param_panel.dart';",
"import 'scene_preset_strip.dart';",
"import 'shutter_feedback.dart';",
"import 'template_drawer_panel.dart';",
"import 'template_strip.dart';",
''
)

$combined = @()
$combined += $header
$combined += $a
$combined += $b
$outText = ($combined -join $nl) + $nl
[System.IO.File]::WriteAllText($dst, $outText, $enc)

# ---- rebuild capture_page.dart ----
$kept = New-Object 'System.Collections.Generic.List[string]'
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($i -ge 2487 -and $i -le 4386) { continue }
  if ($i -ge 4984 -and $i -le 5055) { continue }
  $kept.Add($lines[$i])
}
$remaining = Apply-Renames $kept.ToArray()

$insertIdx = -1
for ($i = 0; $i -lt $remaining.Count; $i++) {
  if ($remaining[$i] -match "import '../widgets/template_strip.dart';") {
    $insertIdx = $i
    break
  }
}
$out = New-Object 'System.Collections.Generic.List[string]'
for ($i = 0; $i -lt $remaining.Count; $i++) {
  $out.Add($remaining[$i])
  if ($i -eq $insertIdx) {
    $out.Add("import '../widgets/capture_bottom_controls.dart';")
  }
}
$pageText = ($out.ToArray() -join $nl) + $nl
[System.IO.File]::WriteAllText($src, $pageText, $enc)

Write-Output ("OK dst_lines=" + $combined.Count + " page_lines=" + $out.Count)