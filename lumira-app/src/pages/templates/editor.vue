<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">{{ pageTitle }}</text>
      <view class="lumira-nav-right"></view>
    </view>

    <!-- Step 1: 模板信息 -->
    <view class="block-pad fade-up">
      <view class="lumira-card">
        <view class="step-header">
          <view class="step-num">1</view>
          <text class="step-title">模板信息</text>
        </view>

        <view class="field-group">
          <text class="field-label">名称</text>
          <input class="field-input" v-model="form.meta.name" placeholder="输入模板名称" />
        </view>

        <view class="field-group">
          <text class="field-label">分类</text>
          <picker
            :range="categoryOptions"
            range-key="label"
            :value="pickerIdx(categoryOptions, form.meta.category)"
            @change="onCategoryChange"
          >
            <view class="picker-display">
              <text>{{ pickerLbl(categoryOptions, form.meta.category) }}</text>
              <text class="ph ph-caret-down picker-arrow"></text>
            </view>
          </picker>
        </view>

        <view class="field-group">
          <text class="field-label">标签</text>
          <input
            class="field-input"
            :value="tagsText"
            @input="onTagsInput"
            placeholder="标签1, 标签2"
          />
        </view>

        <view class="field-group">
          <text class="field-label">简介</text>
          <textarea
            class="field-textarea"
            v-model="form.meta.description"
            placeholder="模板简介"
          />
        </view>

        <view class="field-group">
          <text class="field-label">参数参考来源</text>
          <input
            class="field-input"
            v-model="form.meta.referenceSource"
            placeholder="如：样片 EXIF"
          />
        </view>
      </view>
    </view>

    <!-- Step 2: 构图叠图 -->
    <view class="block-pad-top fade-up fade-up-d1">
      <view class="lumira-card">
        <view class="step-header">
          <view class="step-num">2</view>
          <text class="step-title">构图叠图</text>
        </view>

        <view class="field-group">
          <text class="field-label">构图类型</text>
          <picker
            :range="overlayTypeOptions"
            range-key="label"
            :value="pickerIdx(overlayTypeOptions, form.composition.overlayType)"
            @change="onOverlayTypeChange"
          >
            <view class="picker-display">
              <text>{{ pickerLbl(overlayTypeOptions, form.composition.overlayType) }}</text>
              <text class="ph ph-caret-down picker-arrow"></text>
            </view>
          </picker>
        </view>

        <view class="field-group">
          <text class="field-label">宽高比</text>
          <input
            class="field-input"
            v-model="form.composition.aspectRatio"
            placeholder="如 3:4"
          />
        </view>

        <view class="slider-row">
          <text class="slider-label">透明度</text>
          <slider
            class="slider"
            :value="form.composition.opacity"
            :min="0"
            :max="1"
            :step="0.1"
            activeColor="var(--color-brand)"
            @changing="onOpacityChanging"
          />
          <text class="slider-value">{{ form.composition.opacity.toFixed(1) }}</text>
        </view>

        <view class="field-group">
          <text class="field-label">构图说明</text>
          <textarea
            class="field-textarea"
            v-model="form.composition.description"
            placeholder="构图说明"
          />
        </view>

        <view class="preview-box" :style="{ paddingBottom: compositionPreviewPadding }">
          <view class="preview-bg"></view>
          <CompositionOverlay :composition="form.composition" />
        </view>
      </view>
    </view>

    <!-- Step 3: 姿势剪影 -->
    <view class="block-pad-top fade-up fade-up-d2">
      <view class="lumira-card">
        <view class="step-header">
          <view class="step-num">3</view>
          <text class="step-title">姿势剪影</text>
        </view>

        <!-- 来源选择 -->
        <view class="field-group">
          <text class="field-label">来源</text>
          <view class="pill-group">
            <view
              v-for="opt in silhouetteSourceOptions"
              :key="opt.value"
              class="pill"
              :class="{ active: form.pose.silhouette.type === opt.value }"
              @click="onSilhouetteSourceChange(opt.value)"
            >{{ opt.label }}</view>
          </view>
        </view>

        <!-- 内置库选择 -->
        <view v-if="form.pose.silhouette.type === 'builtin'" class="field-group">
          <text class="field-label">选择剪影</text>
          <scroll-view scroll-x class="silhouette-scroll">
            <view class="silhouette-thumb-list">
              <view
                v-for="key in BUILTIN_SILHOUETTE_KEYS"
                :key="key"
                class="silhouette-thumb"
                :class="{ active: form.pose.silhouette.data === key }"
                @click="selectBuiltinSilhouette(key)"
              >
                <view class="silhouette-svg" v-html="getBuiltinSvg(key)"></view>
                <text class="silhouette-label">{{ key }}</text>
              </view>
            </view>
          </scroll-view>
        </view>

        <!-- 导入图片 -->
        <view v-if="form.pose.silhouette.type === 'image'" class="field-group">
          <text class="field-label">导入图片</text>
          <view class="lumira-btn-ghost action-btn" @click="importSilhouetteImage">
            <text class="ph ph-upload-simple"></text>
            <text>选择图片</text>
          </view>
          <text v-if="form.pose.silhouette.filename" class="import-info">
            {{ form.pose.silhouette.filename }}
            <text v-if="form.pose.silhouette.sizeKB"> ({{ form.pose.silhouette.sizeKB }}KB)</text>
          </text>
        </view>

        <!-- 绘制剪影 -->
        <view v-if="form.pose.silhouette.type === 'svg'" class="field-group">
          <text class="field-label">绘制剪影</text>
          <view class="lumira-btn-ghost action-btn" @click="editorVisible = true">
            <text class="ph ph-paint-brush"></text>
            <text>打开画布</text>
          </view>
        </view>

        <!-- 位置/缩放/旋转 -->
        <view class="slider-row">
          <text class="slider-label">位置 X</text>
          <slider
            class="slider"
            :value="form.pose.position.x"
            :min="0"
            :max="1"
            :step="0.01"
            activeColor="var(--color-brand)"
            @changing="onPoseXChanging"
          />
          <text class="slider-value">{{ form.pose.position.x.toFixed(2) }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">位置 Y</text>
          <slider
            class="slider"
            :value="form.pose.position.y"
            :min="0"
            :max="1"
            :step="0.01"
            activeColor="var(--color-brand)"
            @changing="onPoseYChanging"
          />
          <text class="slider-value">{{ form.pose.position.y.toFixed(2) }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">缩放</text>
          <slider
            class="slider"
            :value="form.pose.scale"
            :min="0.5"
            :max="1.5"
            :step="0.01"
            activeColor="var(--color-brand)"
            @changing="onScaleChanging"
          />
          <text class="slider-value">{{ form.pose.scale.toFixed(2) }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">旋转</text>
          <slider
            class="slider"
            :value="form.pose.rotation"
            :min="-45"
            :max="45"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onRotationChanging"
          />
          <text class="slider-value">{{ form.pose.rotation }}°</text>
        </view>

        <view class="field-group">
          <text class="field-label">姿势描述</text>
          <textarea
            class="field-textarea"
            v-model="form.pose.description"
            placeholder="姿势描述"
          />
        </view>

        <!-- 预览 -->
        <view class="preview-box" :style="{ paddingBottom: '100%' }">
          <view class="preview-bg"></view>
          <PoseSilhouette :pose="form.pose" />
        </view>
      </view>
    </view>

    <!-- Step 4: 相机参数 -->
    <view class="block-pad-top fade-up fade-up-d3">
      <view class="lumira-card">
        <view class="step-header">
          <view class="step-num">4</view>
          <text class="step-title">相机参数</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">EV</text>
          <slider
            class="slider"
            :value="form.camera.exposureCompensation"
            :min="-3"
            :max="3"
            :step="0.3"
            activeColor="var(--color-brand)"
            @changing="onEvChanging"
          />
          <text class="slider-value">{{ formatEv(form.camera.exposureCompensation) }}</text>
        </view>

        <view class="field-group">
          <text class="field-label">ISO 模式</text>
          <view class="pill-group">
            <view
              v-for="opt in isoModeOptions"
              :key="opt.value"
              class="pill"
              :class="{ active: form.camera.isoMode === opt.value }"
              @click="form.camera.isoMode = opt.value"
            >{{ opt.label }}</view>
          </view>
        </view>

        <view class="field-group">
          <text class="field-label">ISO 值</text>
          <input
            class="field-input"
            type="number"
            :value="String(form.camera.iso)"
            @input="onIsoInput"
            placeholder="200"
          />
        </view>

        <view class="field-group">
          <text class="field-label">快门</text>
          <input
            class="field-input"
            v-model="form.camera.shutterSpeed"
            placeholder="如 1/200"
          />
        </view>

        <view class="field-group">
          <text class="field-label">白平衡</text>
          <picker
            :range="whiteBalanceOptions"
            range-key="label"
            :value="pickerIdx(whiteBalanceOptions, form.camera.whiteBalance)"
            @change="onWhiteBalanceChange"
          >
            <view class="picker-display">
              <text>{{ pickerLbl(whiteBalanceOptions, form.camera.whiteBalance) }}</text>
              <text class="ph ph-caret-down picker-arrow"></text>
            </view>
          </picker>
        </view>

        <view class="field-group">
          <text class="field-label">色温 K</text>
          <input
            class="field-input"
            type="number"
            :value="String(form.camera.whiteBalanceK)"
            @input="onWbKInput"
            placeholder="5500"
          />
        </view>

        <view class="field-group">
          <text class="field-label">闪光</text>
          <picker
            :range="flashModeOptions"
            range-key="label"
            :value="pickerIdx(flashModeOptions, form.camera.flashMode)"
            @change="onFlashModeChange"
          >
            <view class="picker-display">
              <text>{{ pickerLbl(flashModeOptions, form.camera.flashMode) }}</text>
              <text class="ph ph-caret-down picker-arrow"></text>
            </view>
          </picker>
        </view>

        <view class="field-group">
          <text class="field-label">对焦</text>
          <picker
            :range="focusModeOptions"
            range-key="label"
            :value="pickerIdx(focusModeOptions, form.camera.focusMode)"
            @change="onFocusModeChange"
          >
            <view class="picker-display">
              <text>{{ pickerLbl(focusModeOptions, form.camera.focusMode) }}</text>
              <text class="ph ph-caret-down picker-arrow"></text>
            </view>
          </picker>
        </view>

        <view class="field-group">
          <text class="field-label">镜头</text>
          <picker
            :range="lensOptions"
            range-key="label"
            :value="pickerIdx(lensOptions, form.camera.lensSuggestion)"
            @change="onLensChange"
          >
            <view class="picker-display">
              <text>{{ pickerLbl(lensOptions, form.camera.lensSuggestion) }}</text>
              <text class="ph ph-caret-down picker-arrow"></text>
            </view>
          </picker>
        </view>
      </view>
    </view>

    <!-- Step 5: 场景指南 -->
    <view class="block-pad-top fade-up fade-up-d4">
      <view class="lumira-card">
        <view class="step-header">
          <view class="step-num">5</view>
          <text class="step-title">场景指南</text>
        </view>

        <view class="field-group">
          <text class="field-label">光线方向</text>
          <input
            class="field-input"
            v-model="form.sceneGuide.lightDirection"
            placeholder="如 逆光 45°"
          />
        </view>

        <view class="field-group">
          <text class="field-label">拍摄距离</text>
          <input
            class="field-input"
            v-model="form.sceneGuide.shootingDistance"
            placeholder="如 2-3m"
          />
        </view>

        <view class="field-group">
          <text class="field-label">背景</text>
          <input
            class="field-input"
            v-model="form.sceneGuide.background"
            placeholder="背景建议"
          />
        </view>

        <view class="field-group">
          <text class="field-label">最佳时间</text>
          <input
            class="field-input"
            v-model="form.sceneGuide.bestTime"
            placeholder="如 黄金时刻"
          />
        </view>

        <view class="field-group">
          <text class="field-label">道具</text>
          <input
            class="field-input"
            :value="propsText"
            @input="onPropsInput"
            placeholder="道具1, 道具2"
          />
        </view>

        <view class="field-group">
          <text class="field-label">贴士</text>
          <textarea
            class="field-textarea"
            :value="tipsText"
            @input="onTipsInput"
            placeholder="每行一条"
          />
        </view>
      </view>
    </view>

    <!-- Step 6: 后期参数 -->
    <view class="block-pad-top fade-up fade-up-d5">
      <view class="lumira-card">
        <view class="step-header">
          <view class="step-num">6</view>
          <text class="step-title">后期参数</text>
        </view>

        <view class="field-group">
          <text class="field-label">裁剪比</text>
          <input
            class="field-input"
            v-model="form.postProcess.cropRatio"
            placeholder="如 3:4"
          />
        </view>

        <view class="field-group">
          <text class="field-label">LUT</text>
          <picker
            :range="lutOptions"
            range-key="label"
            :value="pickerIdx(lutOptions, form.postProcess.lut)"
            @change="onLutChange"
          >
            <view class="picker-display">
              <text>{{ pickerLbl(lutOptions, form.postProcess.lut) }}</text>
              <text class="ph ph-caret-down picker-arrow"></text>
            </view>
          </picker>
        </view>

        <view class="slider-row">
          <text class="slider-label">亮度</text>
          <slider
            class="slider"
            :value="form.postProcess.color.brightness"
            :min="-100"
            :max="100"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onBrightnessChanging"
          />
          <text class="slider-value">{{ formatSigned(form.postProcess.color.brightness) }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">对比</text>
          <slider
            class="slider"
            :value="form.postProcess.color.contrast"
            :min="-100"
            :max="100"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onContrastChanging"
          />
          <text class="slider-value">{{ formatSigned(form.postProcess.color.contrast) }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">饱和</text>
          <slider
            class="slider"
            :value="form.postProcess.color.saturation"
            :min="-100"
            :max="100"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onSaturationChanging"
          />
          <text class="slider-value">{{ formatSigned(form.postProcess.color.saturation) }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">色温</text>
          <slider
            class="slider"
            :value="form.postProcess.color.temperature"
            :min="-100"
            :max="100"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onTemperatureChanging"
          />
          <text class="slider-value">{{ formatSigned(form.postProcess.color.temperature) }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">色调</text>
          <slider
            class="slider"
            :value="form.postProcess.color.tint"
            :min="-100"
            :max="100"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onTintChanging"
          />
          <text class="slider-value">{{ formatSigned(form.postProcess.color.tint) }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">磨皮</text>
          <slider
            class="slider"
            :value="form.postProcess.smoothStrength"
            :min="0"
            :max="100"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onSmoothChanging"
          />
          <text class="slider-value">{{ form.postProcess.smoothStrength }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">锐化</text>
          <slider
            class="slider"
            :value="form.postProcess.sharpen"
            :min="0"
            :max="100"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onSharpenChanging"
          />
          <text class="slider-value">{{ form.postProcess.sharpen }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">暗角</text>
          <slider
            class="slider"
            :value="form.postProcess.vignette"
            :min="0"
            :max="100"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onVignetteChanging"
          />
          <text class="slider-value">{{ form.postProcess.vignette }}</text>
        </view>

        <view class="slider-row">
          <text class="slider-label">颗粒</text>
          <slider
            class="slider"
            :value="form.postProcess.grain"
            :min="0"
            :max="100"
            :step="1"
            activeColor="var(--color-brand)"
            @changing="onGrainChanging"
          />
          <text class="slider-value">{{ form.postProcess.grain }}</text>
        </view>
      </view>
    </view>

    <!-- Spacer for footer -->
    <view class="footer-spacer"></view>

    <!-- Fixed Footer -->
    <view class="editor-footer">
      <view class="footer-btns">
        <view
          class="lumira-btn-ghost footer-btn"
          :class="{ disabled: !isEditMode }"
          @click="onPreview"
        >
          <text class="ph ph-eye"></text>
          <text>预览</text>
        </view>
        <view class="lumira-btn-primary footer-btn footer-btn-main" @click="onSave">
          <text class="ph ph-floppy-disk"></text>
          <text>保存</text>
        </view>
        <view
          v-if="isEditMode"
          class="lumira-btn-ghost footer-btn"
          @click="onExport"
        >
          <text class="ph ph-export"></text>
          <text>导出</text>
        </view>
      </view>
    </view>

    <!-- Silhouette Editor Modal -->
    <SilhouetteEditor
      :visible="editorVisible"
      @close="onEditorClose"
      @complete="onSilhouetteComplete"
    />
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import { useTemplateIO } from '@/composables/useTemplateIO'
import { BUILTIN_SILHOUETTES, BUILTIN_SILHOUETTE_KEYS } from '@/data/silhouettes'
import CompositionOverlay from '@/components/CompositionOverlay.vue'
import PoseSilhouette from '@/components/PoseSilhouette.vue'
import SilhouetteEditor from '@/components/SilhouetteEditor.vue'
import type {
  PhotoTemplate,
  Target,
  OverlayType,
  WhiteBalance,
  FlashMode,
  FocusMode,
  LensSuggestion,
  LutPreset,
  SilhouetteType,
  IsoMode
} from '@/types/template'

const { loadTemplate, saveCustomTemplate, createBlankTemplate } = useTemplate()
const { exportTemplate } = useTemplateIO()

const isEditMode = ref(false)
const form = ref<PhotoTemplate>(createBlankTemplate())
const editorVisible = ref(false)

// 文本缓冲（数组字段与输入框双向同步，避免 cursor 跳动）
const tagsText = ref('')
const propsText = ref('')
const tipsText = ref('')

// ===== 选项数组 =====
const categoryOptions: { label: string; value: Target }[] = [
  { label: '人像', value: 'portrait' },
  { label: '风光', value: 'landscape' },
  { label: '美食', value: 'food' },
  { label: '夜景', value: 'night' },
  { label: '街拍', value: 'street' },
  { label: '微距', value: 'macro' },
  { label: '静物', value: 'still-life' }
]

const overlayTypeOptions: { label: string; value: OverlayType }[] = [
  { label: '三分法', value: 'rule_of_thirds' },
  { label: '黄金比例', value: 'golden_ratio' },
  { label: '对角线', value: 'diagonal' },
  { label: '网格', value: 'grid' },
  { label: '引导线', value: 'leading_lines' },
  { label: '中心构图', value: 'center' },
  { label: '无', value: 'none' }
]

const whiteBalanceOptions: { label: string; value: WhiteBalance }[] = [
  { label: '日光', value: 'daylight' },
  { label: '阴天', value: 'cloudy' },
  { label: '阴影', value: 'shade' },
  { label: '白炽灯', value: 'tungsten' },
  { label: '荧光灯', value: 'fluorescent' },
  { label: '自定义', value: 'custom' }
]

const flashModeOptions: { label: string; value: FlashMode }[] = [
  { label: '关闭', value: 'off' },
  { label: '开启', value: 'on' },
  { label: '自动', value: 'auto' },
  { label: '常亮', value: 'torch' }
]

const focusModeOptions: { label: string; value: FocusMode }[] = [
  { label: '自动', value: 'auto' },
  { label: '手动', value: 'manual' },
  { label: '连续', value: 'continuous' }
]

const lensOptions: { label: string; value: LensSuggestion }[] = [
  { label: '广角', value: 'wide' },
  { label: '主摄', value: 'main' },
  { label: '长焦', value: 'telephoto' },
  { label: '超广角', value: 'ultra_wide' }
]

const lutOptions: { label: string; value: LutPreset }[] = [
  { label: '无', value: 'none' },
  { label: '电影感', value: 'cinematic' },
  { label: '复古', value: 'vintage' },
  { label: '黑白', value: 'bw' },
  { label: '暖色胶片', value: 'warm_film' },
  { label: '冷色胶片', value: 'cool_film' },
  { label: '柔色', value: 'pastel' },
  { label: '富士', value: 'fuji' }
]

const silhouetteSourceOptions: { label: string; value: SilhouetteType }[] = [
  { label: '内置库', value: 'builtin' },
  { label: '导入图片', value: 'image' },
  { label: '绘制剪影', value: 'svg' }
]

const isoModeOptions: { label: string; value: IsoMode }[] = [
  { label: '自动', value: 'auto' },
  { label: '手动', value: 'manual' }
]

// ===== Picker 辅助函数 =====
function pickerIdx<T>(opts: { value: T }[], v: T): number {
  const i = opts.findIndex(o => o.value === v)
  return i >= 0 ? i : 0
}

function pickerLbl<T>(opts: { label: string; value: T }[], v: T): string {
  return opts.find(o => o.value === v)?.label || ''
}

function getBuiltinSvg(key: string): string {
  return BUILTIN_SILHOUETTES[key] || ''
}

// ===== 计算属性 =====
const pageTitle = computed(() => (isEditMode.value ? '编辑模板' : '新建模板'))

const compositionPreviewPadding = computed(() => {
  const ratio = form.value.composition.aspectRatio || '4:3'
  const parts = ratio.split(':')
  const w = Number(parts[0]) || 4
  const h = Number(parts[1]) || 3
  return `${(h / w) * 100}%`
})

// ===== 格式化 =====
function formatEv(v: number): string {
  return v > 0 ? `+${v.toFixed(1)}` : v.toFixed(1)
}

function formatSigned(v: number): string {
  return v > 0 ? `+${v}` : String(v)
}

// ===== onLoad =====
onLoad((options) => {
  if (options?.templateId) {
    const tpl = loadTemplate(options.templateId)
    if (tpl) {
      form.value = JSON.parse(JSON.stringify(tpl)) as PhotoTemplate
      isEditMode.value = true
    }
  }
  // 同步文本缓冲
  tagsText.value = form.value.meta.tags.join(', ')
  propsText.value = form.value.sceneGuide.props.join(', ')
  tipsText.value = form.value.sceneGuide.tips.join('\n')
})

// ===== Picker 变更处理 =====
function onCategoryChange(e: { detail: { value: number | string } }) {
  const idx = Number(e.detail.value)
  form.value.meta.category = categoryOptions[idx]?.value ?? 'portrait'
}

function onOverlayTypeChange(e: { detail: { value: number | string } }) {
  const idx = Number(e.detail.value)
  form.value.composition.overlayType = overlayTypeOptions[idx]?.value ?? 'rule_of_thirds'
}

function onWhiteBalanceChange(e: { detail: { value: number | string } }) {
  const idx = Number(e.detail.value)
  form.value.camera.whiteBalance = whiteBalanceOptions[idx]?.value ?? 'daylight'
}

function onFlashModeChange(e: { detail: { value: number | string } }) {
  const idx = Number(e.detail.value)
  form.value.camera.flashMode = flashModeOptions[idx]?.value ?? 'off'
}

function onFocusModeChange(e: { detail: { value: number | string } }) {
  const idx = Number(e.detail.value)
  form.value.camera.focusMode = focusModeOptions[idx]?.value ?? 'auto'
}

function onLensChange(e: { detail: { value: number | string } }) {
  const idx = Number(e.detail.value)
  form.value.camera.lensSuggestion = lensOptions[idx]?.value ?? 'main'
}

function onLutChange(e: { detail: { value: number | string } }) {
  const idx = Number(e.detail.value)
  form.value.postProcess.lut = lutOptions[idx]?.value ?? 'none'
}

// ===== Slider 变更处理 =====
function onOpacityChanging(e: { detail: { value: number } }) {
  form.value.composition.opacity = e.detail.value
}

function onPoseXChanging(e: { detail: { value: number } }) {
  form.value.pose.position.x = e.detail.value
}

function onPoseYChanging(e: { detail: { value: number } }) {
  form.value.pose.position.y = e.detail.value
}

function onScaleChanging(e: { detail: { value: number } }) {
  form.value.pose.scale = e.detail.value
}

function onRotationChanging(e: { detail: { value: number } }) {
  form.value.pose.rotation = e.detail.value
}

function onEvChanging(e: { detail: { value: number } }) {
  form.value.camera.exposureCompensation = e.detail.value
}

function onBrightnessChanging(e: { detail: { value: number } }) {
  form.value.postProcess.color.brightness = e.detail.value
}

function onContrastChanging(e: { detail: { value: number } }) {
  form.value.postProcess.color.contrast = e.detail.value
}

function onSaturationChanging(e: { detail: { value: number } }) {
  form.value.postProcess.color.saturation = e.detail.value
}

function onTemperatureChanging(e: { detail: { value: number } }) {
  form.value.postProcess.color.temperature = e.detail.value
}

function onTintChanging(e: { detail: { value: number } }) {
  form.value.postProcess.color.tint = e.detail.value
}

function onSmoothChanging(e: { detail: { value: number } }) {
  form.value.postProcess.smoothStrength = e.detail.value
}

function onSharpenChanging(e: { detail: { value: number } }) {
  form.value.postProcess.sharpen = e.detail.value
}

function onVignetteChanging(e: { detail: { value: number } }) {
  form.value.postProcess.vignette = e.detail.value
}

function onGrainChanging(e: { detail: { value: number } }) {
  form.value.postProcess.grain = e.detail.value
}

// ===== 数字输入处理 =====
function onIsoInput(e: { detail: { value: string } }) {
  form.value.camera.iso = Number(e.detail.value) || 0
}

function onWbKInput(e: { detail: { value: string } }) {
  form.value.camera.whiteBalanceK = Number(e.detail.value) || 0
}

// ===== 剪影处理 =====
function onSilhouetteSourceChange(type: SilhouetteType) {
  form.value.pose.silhouette.type = type
  if (type === 'builtin') {
    form.value.pose.silhouette.data = 'none'
  } else if (type === 'image' || type === 'svg') {
    form.value.pose.silhouette.data = ''
  }
}

function selectBuiltinSilhouette(key: string) {
  form.value.pose.silhouette.data = key
}

async function importSilhouetteImage() {
  // #ifdef H5
  uni.chooseImage({
    count: 1,
    success: async (res) => {
      const tempPath = res.tempFilePaths[0]
      // 读取为 base64
      const response = await fetch(tempPath)
      const blob = await response.blob()
      const reader = new FileReader()
      reader.onload = () => {
        const base64 = reader.result as string
        form.value.pose.silhouette = {
          type: 'image',
          data: base64,
          filename: 'silhouette.png',
          sizeKB: Math.round(blob.size / 1024)
        }
      }
      reader.readAsDataURL(blob)
    }
  })
  // #endif
  // #ifndef H5
  uni.showToast({ title: '当前环境暂不支持导入图片', icon: 'none' })
  // #endif
}

function onSilhouetteComplete(svg: string) {
  form.value.pose.silhouette = {
    type: 'svg',
    data: svg
  }
  editorVisible.value = false
}

function onEditorClose() {
  editorVisible.value = false
}

// ===== 数组字段输入处理 =====
function onTagsInput(e: { detail: { value: string } }) {
  const text = e.detail.value
  tagsText.value = text
  form.value.meta.tags = text.split(',').map(t => t.trim()).filter(Boolean)
}

function onPropsInput(e: { detail: { value: string } }) {
  const text = e.detail.value
  propsText.value = text
  form.value.sceneGuide.props = text.split(',').map(t => t.trim()).filter(Boolean)
}

function onTipsInput(e: { detail: { value: string } }) {
  const text = e.detail.value
  tipsText.value = text
  form.value.sceneGuide.tips = text.split('\n').map(t => t.trim()).filter(Boolean)
}

// ===== 操作 =====
function onSave() {
  if (!form.value.meta.name.trim()) {
    uni.showToast({ title: '请输入模板名称', icon: 'none' })
    return
  }
  saveCustomTemplate(form.value)
  uni.showToast({ title: '保存成功', icon: 'success' })
  setTimeout(() => uni.navigateBack(), 800)
}

function onExport() {
  exportTemplate(form.value)
}

function onPreview() {
  if (!isEditMode.value) {
    uni.showToast({ title: '请先保存模板', icon: 'none' })
    return
  }
  uni.navigateTo({ url: `/pages/templates/detail?templateId=${form.value.meta.id}` })
}

function back() {
  uni.navigateBack()
}
</script>

<style lang="scss" scoped>
.back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.block-pad {
  padding: 32rpx 48rpx 0;
}

.block-pad-top {
  padding: 32rpx 48rpx 0;
}

/* 步骤卡片头 */
.step-header {
  display: flex;
  align-items: center;
  gap: 20rpx;
  margin-bottom: 36rpx;
}

.step-num {
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background: var(--color-brand);
  color: var(--color-text-inverse);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 26rpx;
  font-weight: 600;
  flex-shrink: 0;
  box-shadow: var(--shadow-convex-brand);
}

.step-title {
  font-family: var(--font-cn-title);
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  letter-spacing: 0.04em;
}

/* 字段组 */
.field-group {
  margin-bottom: 28rpx;
}

.field-group:last-child {
  margin-bottom: 0;
}

.field-label {
  display: block;
  font-size: 26rpx;
  font-weight: 500;
  color: var(--color-text-secondary);
  margin-bottom: 12rpx;
}

.field-input {
  width: 100%;
  height: 80rpx;
  padding: 0 24rpx;
  background-color: var(--color-canvas-deep);
  border-radius: 16rpx;
  font-size: 28rpx;
  color: var(--color-text-primary);
  border: none;
  box-sizing: border-box;
}

.field-textarea {
  width: 100%;
  min-height: 120rpx;
  padding: 20rpx 24rpx;
  background-color: var(--color-canvas-deep);
  border-radius: 16rpx;
  font-size: 28rpx;
  color: var(--color-text-primary);
  border: none;
  box-sizing: border-box;
}

/* Picker */
.picker-display {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 80rpx;
  padding: 0 24rpx;
  background-color: var(--color-canvas-deep);
  border-radius: 16rpx;
  font-size: 28rpx;
  color: var(--color-text-primary);
}

.picker-arrow {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
}

/* Slider */
.slider-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 28rpx;
}

.slider-row:last-child {
  margin-bottom: 0;
}

.slider-label {
  width: 96rpx;
  flex-shrink: 0;
  font-size: 26rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.slider {
  flex: 1;
  margin: 0;
}

.slider-value {
  width: 80rpx;
  flex-shrink: 0;
  text-align: right;
  font-size: 24rpx;
  font-family: 'Courier New', monospace;
  color: var(--color-text-secondary);
}

/* Pills (radio-like) */
.pill-group {
  display: flex;
  gap: 12rpx;
  flex-wrap: wrap;
}

.pill {
  padding: 12rpx 28rpx;
  font-size: 26rpx;
  border-radius: 9999rpx;
  background-color: var(--color-canvas-deep);
  color: var(--color-text-secondary);
  border: 2rpx solid transparent;
  line-height: 1;
  transition: all 0.2s ease;
}

.pill.active {
  background: var(--color-brand);
  color: var(--color-text-inverse);
  border-color: transparent;
}

/* Silhouette thumbnails */
.silhouette-scroll {
  width: 100%;
  white-space: nowrap;
}

.silhouette-thumb-list {
  display: inline-flex;
  gap: 16rpx;
  padding: 4rpx;
}

.silhouette-thumb {
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  width: 120rpx;
  padding: 16rpx 8rpx;
  border-radius: 16rpx;
  background-color: var(--color-canvas-deep);
  border: 2rpx solid transparent;
  transition: all 0.2s ease;
  flex-shrink: 0;
}

.silhouette-thumb.active {
  background-color: var(--color-brand-subtle);
  border-color: var(--color-brand);
}

.silhouette-svg {
  width: 48rpx;
  height: 80rpx;
  color: var(--color-text-secondary);
  margin-bottom: 8rpx;
}

.silhouette-thumb.active .silhouette-svg {
  color: var(--color-brand-deep);
}

:deep(.silhouette-svg svg) {
  width: 100%;
  height: 100%;
}

.silhouette-label {
  font-size: 18rpx;
  color: var(--color-text-tertiary);
  text-align: center;
  word-break: break-all;
  line-height: 1.2;
}

/* Action buttons */
.action-btn {
  display: inline-flex;
  align-items: center;
  gap: 12rpx;
}

.import-info {
  display: block;
  margin-top: 12rpx;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

/* Preview box */
.preview-box {
  position: relative;
  width: 100%;
  height: 0;
  border-radius: 20rpx;
  overflow: hidden;
  margin-top: 24rpx;
}

.preview-bg {
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, #3A3631 0%, #2A2622 100%);
}

/* Footer */
.footer-spacer {
  height: 200rpx;
}

.editor-footer {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 24rpx 32rpx;
  padding-bottom: calc(24rpx + env(safe-area-inset-bottom, 0));
  background: linear-gradient(to top, var(--color-canvas) 60%, transparent);
  z-index: 100;
}

.footer-btns {
  display: flex;
  gap: 16rpx;
  align-items: stretch;
}

.footer-btn {
  flex: 1;
  height: 88rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8rpx;
  padding: 0;
}

.footer-btn-main {
  flex: 2;
}

.footer-btn.disabled {
  opacity: 0.4;
}
</style>
