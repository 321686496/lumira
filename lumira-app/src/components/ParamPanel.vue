<template>
  <view class="param-panel" :class="{ 'is-visible': visible, 'raw-mode-disabled': rawMode }">
    <!-- 遮罩层 -->
    <view class="param-panel-mask" v-if="visible" @click="emit('close')" />

    <!-- 面板主体 -->
    <view class="param-panel-body" :class="{ 'is-visible': visible }">
      <!-- 拖拽手柄（点击关闭） -->
      <view class="panel-handle" @click="emit('close')">
        <view class="handle-bar" />
      </view>

      <!-- 模板概要 -->
      <view class="panel-summary">
        <view class="summary-name">{{ template.meta.name }}</view>
        <view class="summary-desc">{{ template.meta.description }}</view>
      </view>

      <!-- Tab 切换栏 -->
      <view class="panel-tabs">
        <view
          v-for="(tab, idx) in tabs"
          :key="tab.key"
          class="tab-item"
          :class="{ active: activeTab === idx }"
          @click="activeTab = idx"
        >
          <text class="ph" :class="tab.icon" />
          <text class="tab-label">{{ tab.label }}</text>
        </view>
      </view>

      <!-- 滚动内容区 -->
      <view class="panel-content">
        <!-- 相机 Tab -->
        <view v-if="activeTab === 0" class="tab-pane">
          <!-- 曝光补偿 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">曝光补偿 EV</text>
              <text class="slider-value">{{ evDisplay }}</text>
            </view>
            <slider
              class="param-slider"
              :value="template.camera.exposureCompensation"
              :min="-3"
              :max="3"
              :step="0.3"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateCamera('exposureCompensation', e.detail.value)"
            />
          </view>

          <!-- ISO -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">ISO</text>
              <text class="slider-value">{{ template.camera.iso === 0 ? '自动' : template.camera.iso }}</text>
            </view>
            <slider
              class="param-slider"
              :value="template.camera.iso"
              :min="0"
              :max="6400"
              :step="50"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateCamera('iso', e.detail.value)"
            />
          </view>

          <!-- 快门速度 -->
          <view class="param-row">
            <view class="param-label">快门速度</view>
            <view class="param-value">{{ template.camera.shutterSpeed }}</view>
          </view>

          <!-- 白平衡 -->
          <view class="param-row">
            <view class="param-label">白平衡</view>
            <view class="param-value">
              {{ wbLabel(template.camera.whiteBalance, template.camera.whiteBalanceK) }}
            </view>
          </view>
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">色温 K</text>
              <text class="slider-value">{{ template.camera.whiteBalanceK }}K</text>
            </view>
            <slider
              class="param-slider"
              :value="template.camera.whiteBalanceK"
              :min="2500"
              :max="8000"
              :step="100"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateCamera('whiteBalanceK', e.detail.value)"
            />
          </view>
          <view class="pill-row">
            <view
              v-for="wb in wbOptions"
              :key="wb.value"
              class="pill-option"
              :class="{ active: template.camera.whiteBalance === wb.value }"
              @click="updateCamera('whiteBalance', wb.value)"
            >
              {{ wb.label }}
            </view>
          </view>

          <!-- 闪光 -->
          <view class="param-row">
            <view class="param-label">闪光</view>
            <view class="param-value">{{ flashLabel(template.camera.flashMode) }}</view>
          </view>
          <view class="pill-row">
            <view
              v-for="f in flashOptions"
              :key="f.value"
              class="pill-option"
              :class="{ active: template.camera.flashMode === f.value }"
              @click="updateCamera('flashMode', f.value)"
            >
              {{ f.label }}
            </view>
          </view>

          <!-- 对焦 -->
          <view class="param-row">
            <view class="param-label">对焦</view>
            <view class="param-value">{{ focusLabel(template.camera.focusMode) }}</view>
          </view>
          <view class="pill-row">
            <view
              v-for="f in focusOptions"
              :key="f.value"
              class="pill-option"
              :class="{ active: template.camera.focusMode === f.value }"
              @click="updateCamera('focusMode', f.value)"
            >
              {{ f.label }}
            </view>
          </view>

          <!-- 镜头建议 -->
          <view class="param-row">
            <view class="param-label">镜头建议</view>
            <view class="param-value">{{ lensLabel(template.camera.lensSuggestion) }}</view>
          </view>

          <AdvancedSection
            title="高级参数"
            :open="advancedOpen.camera"
            @update:open="advancedOpen.camera = $event"
          >
            <!-- 快门速度 -->
            <view class="param-row">
              <text class="param-label">快门速度</text>
              <scroll-view scroll-x class="pill-list">
                <view class="pill-list-inner">
                  <view
                    v-for="opt in shutterSpeedOptions"
                    :key="opt.value"
                    class="pill"
                    :class="{ active: template.camera.shutterSpeed === opt.value }"
                    @click="updateCamera('shutterSpeed', opt.value)"
                  >
                    <text>{{ opt.label }}</text>
                  </view>
                </view>
              </scroll-view>
            </view>

            <!-- 镜头切换 -->
            <view class="param-row">
              <text class="param-label">镜头</text>
              <view class="pill-list-inline">
                <view
                  v-for="opt in lensTypeOptions"
                  :key="opt.value"
                  class="pill"
                  :class="{ active: (template.camera.lensType || '1x') === opt.value }"
                  @click="updateCamera('lensType', opt.value)"
                >
                  <text>{{ opt.label }}</text>
                </view>
              </view>
            </view>

            <!-- 拍照风格 -->
            <view class="param-row">
              <text class="param-label">拍照风格</text>
              <view class="pill-list-inline">
                <view
                  v-for="opt in photographicStyleOptions"
                  :key="opt.value"
                  class="pill"
                  :class="{ active: (template.camera.photographicStyle || 'standard') === opt.value }"
                  @click="updateCamera('photographicStyle', opt.value)"
                >
                  <text>{{ opt.label }}</text>
                </view>
              </view>
            </view>

            <!-- HDR -->
            <view class="param-row">
              <text class="param-label">HDR</text>
              <view class="switch-row">
                <switch
                  class="mode-toggle"
                  :checked="template.camera.hdr || false"
                  @change="updateCamera('hdr', $event.detail.value)"
                />
              </view>
            </view>
          </AdvancedSection>
        </view>

        <!-- 构图 Tab -->
        <view v-if="activeTab === 1" class="tab-pane">
          <view class="param-row">
            <view class="param-label">构图类型</view>
            <view class="param-value">{{ overlayTypeLabel(template.composition.overlayType) }}</view>
          </view>
          <view class="param-row" v-if="template.composition.gridType">
            <view class="param-label">网格细分</view>
            <view class="param-value">
              {{ ({ thirds: '三分', quarters: '四分', golden_spiral: '黄金螺旋' } as Record<string, string>)[template.composition.gridType] || template.composition.gridType }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">宽高比</view>
            <view class="param-value">{{ template.composition.aspectRatio }}</view>
          </view>
          <view class="param-row">
            <view class="param-label">主体建议框</view>
            <view class="param-value">
              <template v-if="template.composition.subjectFrame">
                {{ Math.round(template.composition.subjectFrame.x * 100) }}%, {{ Math.round(template.composition.subjectFrame.y * 100) }}%
              </template>
              <template v-else>未启用</template>
            </view>
          </view>
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">叠图透明度</text>
              <text class="slider-value">{{ Math.round(template.composition.opacity * 100) }}%</text>
            </view>
            <slider
              class="param-slider"
              :value="template.composition.opacity * 100"
              :min="0"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateComposition('opacity', e.detail.value / 100)"
            />
          </view>
          <view class="desc-block" v-if="template.composition.description">
            <view class="desc-title">构图说明</view>
            <view class="desc-text">{{ template.composition.description }}</view>
          </view>

          <AdvancedSection
            title="高级参数"
            :open="advancedOpen.composition"
            @update:open="advancedOpen.composition = $event"
          >
            <view class="param-row">
              <text class="param-label">构图类型</text>
              <view class="pill-list-inline">
                <view
                  v-for="opt in overlayTypeOptions"
                  :key="opt.value"
                  class="pill"
                  :class="{ active: template.composition.overlayType === opt.value }"
                  @click="updateComposition('overlayType', opt.value)"
                >
                  <text>{{ opt.label }}</text>
                </view>
              </view>
            </view>

            <view class="param-row">
              <text class="param-label">网格细分</text>
              <view class="pill-list-inline">
                <view
                  v-for="opt in gridTypeOptions"
                  :key="opt.value"
                  class="pill"
                  :class="{ active: (template.composition.gridType || 'thirds') === opt.value }"
                  @click="updateComposition('gridType', opt.value)"
                >
                  <text>{{ opt.label }}</text>
                </view>
              </view>
            </view>

            <view class="param-row">
              <text class="param-label">宽高比</text>
              <view class="pill-list-inline">
                <view
                  v-for="opt in aspectRatioOptions"
                  :key="opt.value"
                  class="pill"
                  :class="{ active: template.composition.aspectRatio === opt.value }"
                  @click="updateComposition('aspectRatio', opt.value)"
                >
                  <text>{{ opt.label }}</text>
                </view>
              </view>
            </view>

            <view class="param-row">
              <text class="param-label">主体建议框</text>
              <view class="switch-row">
                <switch
                  class="mode-toggle"
                  :checked="!!template.composition.subjectFrame"
                  @change="updateComposition('subjectFrame', $event.detail.value ? { x: 0.3, y: 0.3, w: 0.4, h: 0.4 } : null)"
                />
              </view>
            </view>
          </AdvancedSection>
        </view>

        <!-- 场景 Tab -->
        <view v-if="activeTab === 2" class="tab-pane">
          <!-- 场景预设选择 -->
          <view class="scene-preset-section">
            <text class="section-title">场景预设</text>
            <scroll-view scroll-x class="scene-preset-scroll">
              <view class="scene-preset-list">
                <view
                  v-for="preset in scenePresets"
                  :key="preset.id"
                  class="scene-preset-card"
                  :class="{ active: template.sceneGuide.presetId === preset.id }"
                  @click="onSelectScenePreset(preset.id)"
                >
                  <view class="scene-preset-icon-wrap">
                    <text class="ph scene-preset-icon" :class="preset.icon" />
                  </view>
                  <text class="scene-preset-name">{{ preset.name }}</text>
                </view>
              </view>
            </scroll-view>
          </view>

          <!-- 一键应用场景参数 -->
          <view class="scene-apply-btn" @click="onApplyScenePreset">
            <text class="ph ph-sparkle" />
            <text>一键应用场景参数</text>
          </view>

          <!-- 当前场景参数预览 -->
          <view v-if="currentScenePreset" class="scene-suggestion-block">
            <text class="section-title">场景氛围滤镜</text>
            <view class="param-row" v-if="currentScenePreset.filter.lut && currentScenePreset.filter.lut !== 'none'">
              <text class="param-label">建议 LUT</text>
              <text class="param-value">{{ getLutLabel(currentScenePreset.filter.lut) }}</text>
            </view>
            <view class="param-row" v-if="currentScenePreset.filter.systemFilter && currentScenePreset.filter.systemFilter !== 'none'">
              <text class="param-label">系统滤镜</text>
              <text class="param-value">{{ getSystemFilterLabel(currentScenePreset.filter.systemFilter) }}</text>
            </view>
            <view class="param-row" v-if="currentScenePreset.filter.reason">
              <text class="param-label">氛围理由</text>
              <text class="param-value">{{ currentScenePreset.filter.reason }}</text>
            </view>
          </view>

          <!-- 场景信息（只读） -->
          <view class="param-row">
            <text class="param-label">光线方向</text>
            <text class="param-value">{{ template.sceneGuide.lightDirection }}</text>
          </view>
          <view class="param-row">
            <text class="param-label">拍摄距离</text>
            <text class="param-value">{{ template.sceneGuide.shootingDistance }}</text>
          </view>
          <view class="param-row">
            <text class="param-label">背景建议</text>
            <text class="param-value">{{ template.sceneGuide.background }}</text>
          </view>
          <view class="param-row">
            <text class="param-label">最佳时间</text>
            <text class="param-value">{{ template.sceneGuide.bestTime }}</text>
          </view>

          <!-- 道具建议 -->
          <view class="tag-list-block" v-if="template.sceneGuide.props.length">
            <text class="desc-title">道具建议</text>
            <view class="tag-list">
              <view class="prop-tag" v-for="(item, idx) in template.sceneGuide.props" :key="idx">
                {{ item }}
              </view>
            </view>
          </view>

          <!-- 拍摄贴士 -->
          <view class="desc-block" v-if="template.sceneGuide.tips.length">
            <text class="desc-title">拍摄贴士</text>
            <view class="tips-list">
              <view class="tips-item" v-for="(tip, idx) in template.sceneGuide.tips" :key="idx">
                <text class="ph ph-circle tips-dot" />
                <text class="tips-text">{{ tip }}</text>
              </view>
            </view>
          </view>

          <!-- 高级：自定义场景参数 -->
          <AdvancedSection
            title="自定义场景参数"
            :open="advancedOpen.sceneCustom"
            @update:open="advancedOpen.sceneCustom = $event"
          >
            <view class="param-row">
              <text class="param-label">光线方向</text>
              <view class="pill-list-inline">
                <view
                  v-for="opt in lightDirectionOptions"
                  :key="opt.value"
                  class="pill"
                  :class="{ active: template.sceneGuide.lightDirectionAngle === opt.value }"
                  @click="updateSceneGuide('lightDirectionAngle', opt.value)"
                >
                  <text>{{ opt.label }}</text>
                </view>
              </view>
            </view>
            <view class="slider-block">
              <view class="slider-header">
                <text class="param-label">拍摄距离</text>
                <text class="slider-value">{{ template.sceneGuide.shootingDistanceM || 2 }}m</text>
              </view>
              <slider
                class="param-slider"
                :value="template.sceneGuide.shootingDistanceM || 2"
                :min="0.1"
                :max="10"
                :step="0.1"
                activeColor="var(--color-brand)"
                backgroundColor="var(--color-divider)"
                block-color="var(--color-brand)"
                @change="(e: any) => updateSceneGuide('shootingDistanceM', e.detail.value)"
              />
            </view>
          </AdvancedSection>
        </view>

        <!-- 姿势 Tab -->
        <view v-if="activeTab === 3" class="tab-pane">
          <view class="silhouette-preview">
            <view class="silhouette-wrap">
              <image
                v-if="template.pose.silhouette.type === 'image'"
                :src="template.pose.silhouette.data"
                class="silhouette-img"
                mode="aspectFit"
              />
              <view v-else class="silhouette-placeholder">
                <text class="ph ph-person silhouette-icon" />
              </view>
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">剪影类型</view>
            <view class="param-value">
              {{ ({ builtin: '内置', image: '图片', svg: 'SVG' } as Record<string, string>)[template.pose.silhouette.type] || template.pose.silhouette.type }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">位置</view>
            <view class="param-value">
              {{ Math.round(template.pose.position.x * 100) }}%, {{ Math.round(template.pose.position.y * 100) }}%
            </view>
          </view>
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">缩放</text>
              <text class="slider-value">{{ template.pose.scale.toFixed(2) }}</text>
            </view>
            <slider
              class="param-slider"
              :value="template.pose.scale"
              :min="0.3"
              :max="3"
              :step="0.05"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePose('scale', e.detail.value)"
            />
          </view>
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">旋转</text>
              <text class="slider-value">{{ template.pose.rotation }}°</text>
            </view>
            <slider
              class="param-slider"
              :value="template.pose.rotation"
              :min="-180"
              :max="180"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePose('rotation', e.detail.value)"
            />
          </view>
          <view class="desc-block" v-if="template.pose.description">
            <view class="desc-title">姿势描述</view>
            <view class="desc-text">{{ template.pose.description }}</view>
          </view>

          <AdvancedSection
            title="高级参数"
            :open="advancedOpen.pose"
            @update:open="advancedOpen.pose = $event"
          >
            <view class="param-row">
              <text class="param-label">位置 X</text>
              <slider
                class="param-slider"
                :value="template.pose.positionX || 0"
                :min="-100"
                :max="100"
                :step="1"
                @changing="updatePose('positionX', $event.detail.value)"
                @change="updatePose('positionX', $event.detail.value)"
              />
            </view>

            <view class="param-row">
              <text class="param-label">位置 Y</text>
              <slider
                class="param-slider"
                :value="template.pose.positionY || 0"
                :min="-100"
                :max="100"
                :step="1"
                @changing="updatePose('positionY', $event.detail.value)"
                @change="updatePose('positionY', $event.detail.value)"
              />
            </view>
          </AdvancedSection>
        </view>

        <!-- 后期 Tab -->
        <view v-if="activeTab === 4" class="tab-pane">
          <!-- 系统滤镜区 -->
          <view class="filter-section">
            <text class="section-title">系统滤镜</text>
            <scroll-view scroll-x class="filter-list">
              <view class="filter-list-inner">
                <view
                  v-for="f in systemFilterOptions"
                  :key="f.id"
                  class="filter-item"
                  :class="{ active: (template.postProcess.systemFilter || 'none') === f.id }"
                  @click="onSelectSystemFilter(f.id)"
                >
                  <view class="filter-thumb" :style="thumbStyle(f.filter)">
                    <image
                      class="thumb-img"
                      src="https://picsum.photos/seed/param-sys-filter/120/120"
                      mode="aspectFill"
                    />
                  </view>
                  <text class="filter-name">{{ f.name }}</text>
                </view>
              </view>
            </scroll-view>
          </view>

          <!-- LUT 预设 -->
          <view class="filter-section">
            <text class="section-title">LUT 预设</text>
            <scroll-view scroll-x class="filter-list">
              <view class="filter-list-inner">
                <view
                  v-for="lut in lutOptions"
                  :key="lut.id"
                  class="filter-item"
                  :class="{ active: (template.postProcess.lut || 'none') === lut.id }"
                  @click="onSelectLut(lut.id)"
                >
                  <view class="filter-thumb" :style="thumbStyle(lut.filter)">
                    <image
                      class="thumb-img"
                      src="https://picsum.photos/seed/param-lut/120/120"
                      mode="aspectFill"
                    />
                  </view>
                  <text class="filter-name">{{ lut.name }}</text>
                </view>
              </view>
            </scroll-view>
          </view>

          <!-- 亮度 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">亮度</text>
              <text class="slider-value">{{ template.postProcess.color.brightness }}</text>
            </view>
            <slider
              class="param-slider"
              :value="template.postProcess.color.brightness"
              :min="-100"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateColor('brightness', e.detail.value)"
            />
          </view>
          <!-- 对比度 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">对比度</text>
              <text class="slider-value">{{ template.postProcess.color.contrast }}</text>
            </view>
            <slider
              class="param-slider"
              :value="template.postProcess.color.contrast"
              :min="-100"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateColor('contrast', e.detail.value)"
            />
          </view>
          <!-- 饱和度 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">饱和度</text>
              <text class="slider-value">{{ template.postProcess.color.saturation }}</text>
            </view>
            <slider
              class="param-slider"
              :value="template.postProcess.color.saturation"
              :min="-100"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateColor('saturation', e.detail.value)"
            />
          </view>
          <!-- 锐化 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">锐化</text>
              <text class="slider-value">{{ template.postProcess.sharpen }}</text>
            </view>
            <slider
              class="param-slider"
              :value="template.postProcess.sharpen"
              :min="0"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePost('sharpen', e.detail.value)"
            />
          </view>
          <!-- 暗角 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">暗角</text>
              <text class="slider-value">{{ template.postProcess.vignette }}</text>
            </view>
            <slider
              class="param-slider"
              :value="template.postProcess.vignette"
              :min="0"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePost('vignette', e.detail.value)"
            />
          </view>
          <!-- 颗粒 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">颗粒</text>
              <text class="slider-value">{{ template.postProcess.grain }}</text>
            </view>
            <slider
              class="param-slider"
              :value="template.postProcess.grain"
              :min="0"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePost('grain', e.detail.value)"
            />
          </view>

          <AdvancedSection
            title="高级参数"
            :open="advancedOpen.post"
            @update:open="advancedOpen.post = $event"
          >
            <!-- 裁剪比 -->
            <view class="param-row">
              <text class="param-label">裁剪比</text>
              <view class="pill-list-inline">
                <view
                  v-for="opt in cropRatioOptions"
                  :key="opt.value"
                  class="pill"
                  :class="{ active: template.postProcess.cropRatio === opt.value }"
                  @click="updatePost('cropRatio', opt.value)"
                >
                  <text>{{ opt.label }}</text>
                </view>
              </view>
            </view>

            <!-- 色温 -->
            <view class="slider-block">
              <view class="slider-header">
                <text class="param-label">色温</text>
                <text class="slider-value">{{ template.postProcess.color.temperature }}</text>
              </view>
              <slider
                class="param-slider"
                :value="template.postProcess.color.temperature"
                :min="-100"
                :max="100"
                :step="1"
                activeColor="var(--color-brand)"
                backgroundColor="var(--color-divider)"
                block-color="var(--color-brand)"
                @change="(e: any) => updateColor('temperature', e.detail.value)"
              />
            </view>
            <!-- 色调 -->
            <view class="slider-block">
              <view class="slider-header">
                <text class="param-label">色调</text>
                <text class="slider-value">{{ template.postProcess.color.tint }}</text>
              </view>
              <slider
                class="param-slider"
                :value="template.postProcess.color.tint"
                :min="-100"
                :max="100"
                :step="1"
                activeColor="var(--color-brand)"
                backgroundColor="var(--color-divider)"
                block-color="var(--color-brand)"
                @change="(e: any) => updateColor('tint', e.detail.value)"
              />
            </view>
            <!-- 磨皮 -->
            <view class="slider-block">
              <view class="slider-header">
                <text class="param-label">磨皮</text>
                <text class="slider-value">{{ template.postProcess.smoothStrength }}</text>
              </view>
              <slider
                class="param-slider"
                :value="template.postProcess.smoothStrength"
                :min="0"
                :max="100"
                :step="1"
                activeColor="var(--color-brand)"
                backgroundColor="var(--color-divider)"
                block-color="var(--color-brand)"
                @change="(e: any) => updatePost('smoothStrength', e.detail.value)"
              />
            </view>
          </AdvancedSection>
        </view>
      </view>

      <!-- 底部一键应用按钮 -->
      <view class="panel-footer">
        <view
          class="apply-btn"
          :class="{ 'is-applied': applied }"
          @click="onApplyClick"
        >
          <text class="ph" :class="applied ? 'ph-check-circle' : 'ph-sparkle'" />
          <text>{{ applied ? '已应用模板参数' : '一键应用模板参数' }}</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import type { PhotoTemplate, WhiteBalance, FlashMode, FocusMode, LutPreset, SystemFilter, LensType, PhotographicStyle, OverlayType, GridType, ScenePresetId } from '@/types/template'
import { getSystemFilterOptions, getLutOptions, getLutLabel, getSystemFilterLabel } from '@/utils/filterRecipe'
import AdvancedSection from '@/components/AdvancedSection.vue'
import { SCENE_PRESETS } from '@/data/scenePresets'

const props = defineProps<{
  template: PhotoTemplate
  visible: boolean
  applied: boolean
  rawMode: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'apply'): void
  (e: 'update:opacity', value: number): void
  (e: 'update:template', template: PhotoTemplate): void
  (e: 'select-system-filter', value: SystemFilter): void
  (e: 'select-lut', value: LutPreset): void
}>()

const tabs = [
  { key: 'camera', label: '相机', icon: 'ph-camera' },
  { key: 'composition', label: '构图', icon: 'ph-frame-corners' },
  { key: 'scene', label: '场景', icon: 'ph-sun' },
  { key: 'pose', label: '姿势', icon: 'ph-person' },
  { key: 'post', label: '后期', icon: 'ph-magic-wand' }
]

const activeTab = ref(0)

// 各 Tab 高级参数折叠状态
const advancedOpen = ref<Record<string, boolean>>({
  camera: false,
  composition: false,
  pose: false,
  post: false,
  sceneCustom: false
})

const onApplyClick = () => {
  if (props.applied) {
    uni.showToast({ title: '参数已是模板原值', icon: 'none' })
    return
  }
  emit('apply')
}

// 选项列表
const shutterSpeedOptions = [
  { value: 'auto', label: 'Auto' },
  { value: '1/2000', label: '1/2000' },
  { value: '1/1000', label: '1/1000' },
  { value: '1/500', label: '1/500' },
  { value: '1/250', label: '1/250' },
  { value: '1/125', label: '1/125' },
  { value: '1/60', label: '1/60' },
  { value: '1/30', label: '1/30' },
  { value: '1/15', label: '1/15' },
  { value: '1/8', label: '1/8' },
  { value: '1/4', label: '1/4' },
  { value: '1/2', label: '1/2' },
  { value: '1"', label: '1"' },
  { value: '2"', label: '2"' },
  { value: '5"', label: '5"' },
  { value: '10"', label: '10"' },
  { value: '30"', label: '30"' }
]

const lensTypeOptions: { value: LensType; label: string }[] = [
  { value: '0.5x', label: '0.5x' },
  { value: '1x', label: '1x' },
  { value: '2x', label: '2x' },
  { value: '3x', label: '3x' }
]

const photographicStyleOptions: { value: PhotographicStyle; label: string }[] = [
  { value: 'standard', label: '标准' },
  { value: 'high_contrast', label: '高对比' },
  { value: 'warm', label: '暖色调' },
  { value: 'cool', label: '冷色调' },
  { value: 'mono', label: '单色' }
]

const photographicStyleLabel = (style: PhotographicStyle | undefined): string => {
  if (!style) return '标准'
  const opt = photographicStyleOptions.find(o => o.value === style)
  return opt ? opt.label : '标准'
}

const overlayTypeOptions: { value: OverlayType; label: string }[] = [
  { value: 'rule_of_thirds', label: '三分法' },
  { value: 'golden_ratio', label: '黄金比例' },
  { value: 'diagonal', label: '对角线' },
  { value: 'grid', label: '网格' },
  { value: 'leading_lines', label: '引导线' },
  { value: 'center', label: '居中' },
  { value: 'none', label: '无' }
]

const gridTypeOptions: { value: GridType; label: string }[] = [
  { value: 'thirds', label: '三分' },
  { value: 'quarters', label: '四分' },
  { value: 'golden_spiral', label: '黄金螺旋' }
]

const aspectRatioOptions = [
  { value: '4:3', label: '4:3' },
  { value: '1:1', label: '1:1' },
  { value: '16:9', label: '16:9' },
  { value: '3:4', label: '3:4' }
]

const cropRatioOptions = [
  { value: '3:4', label: '3:4' },
  { value: '1:1', label: '1:1' },
  { value: '4:3', label: '4:3' },
  { value: '16:9', label: '16:9' }
]

const systemFilterOptions = computed(() => getSystemFilterOptions())
const lutOptions = computed(() => getLutOptions())

// 更新参数通用方法（泛型 + 深拷贝模式，保证类型安全与单向数据流）
const updateCamera = <K extends keyof PhotoTemplate['camera']>(key: K, value: PhotoTemplate['camera'][K]) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  tpl.camera[key] = value
  emit('update:template', tpl)
}

const updateComposition = <K extends keyof PhotoTemplate['composition']>(key: K, value: PhotoTemplate['composition'][K]) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  tpl.composition[key] = value
  emit('update:template', tpl)
}

const updatePose = <K extends keyof PhotoTemplate['pose']>(key: K, value: PhotoTemplate['pose'][K]) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  tpl.pose[key] = value
  emit('update:template', tpl)
}

const updatePost = <K extends keyof PhotoTemplate['postProcess']>(key: K, value: PhotoTemplate['postProcess'][K]) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  tpl.postProcess[key] = value
  emit('update:template', tpl)
}

const scenePresets = SCENE_PRESETS

const currentScenePreset = computed(() => {
  const id = props.template.sceneGuide.presetId
  return id ? scenePresets.find(p => p.id === id) : null
})

const onSelectScenePreset = (id: ScenePresetId) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  tpl.sceneGuide.presetId = id
  const preset = scenePresets.find(p => p.id === id)
  if (preset) {
    tpl.sceneGuide.lightDirection = preset.sceneGuide.lightDirection
    tpl.sceneGuide.shootingDistance = preset.sceneGuide.shootingDistance
    tpl.sceneGuide.background = preset.sceneGuide.background
    tpl.sceneGuide.props = [...preset.sceneGuide.props]
    tpl.sceneGuide.bestTime = preset.sceneGuide.bestTime
    tpl.sceneGuide.tips = [...preset.sceneGuide.tips]
  }
  emit('update:template', tpl)
}

const onApplyScenePreset = () => {
  if (props.rawMode) return
  const preset = currentScenePreset.value
  if (!preset) {
    uni.showToast({ title: '请先选择场景预设', icon: 'none' })
    return
  }
  const tpl = cloneTemplate()
  // 场景预设仅保留氛围滤镜，应用到后期参数（替代旧的 cameraSuggestion/postSuggestion）
  tpl.postProcess.lut = preset.filter.lut
  if (preset.filter.systemFilter) {
    tpl.postProcess.systemFilter = preset.filter.systemFilter
  }
  emit('update:template', tpl)
  uni.showToast({ title: '已应用场景滤镜', icon: 'success' })
}

const updateSceneGuide = <K extends keyof PhotoTemplate['sceneGuide']>(
  key: K,
  value: PhotoTemplate['sceneGuide'][K]
) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  tpl.sceneGuide[key] = value
  emit('update:template', tpl)
}

const lightDirectionOptions = [
  { value: 0, label: '顺光' },
  { value: 45, label: '前侧光' },
  { value: 90, label: '侧光' },
  { value: 135, label: '侧逆光' },
  { value: 180, label: '逆光' },
  { value: 270, label: '反射光' }
]

const onSelectSystemFilter = (id: SystemFilter) => {
  emit('select-system-filter', id)
}

const onSelectLut = (id: LutPreset) => {
  emit('select-lut', id)
}

// 原有选项列表（pill 行使用）
const wbOptions: { value: WhiteBalance; label: string }[] = [
  { value: 'daylight', label: '日光' },
  { value: 'cloudy', label: '阴天' },
  { value: 'shade', label: '阴影' },
  { value: 'tungsten', label: '钨丝灯' },
  { value: 'fluorescent', label: '荧光灯' },
  { value: 'custom', label: '自定义' }
]
const flashOptions: { value: FlashMode; label: string }[] = [
  { value: 'off', label: '关闭' },
  { value: 'on', label: '常开' },
  { value: 'auto', label: '自动' },
  { value: 'torch', label: '手电筒' }
]
const focusOptions: { value: FocusMode; label: string }[] = [
  { value: 'auto', label: '自动' },
  { value: 'manual', label: '手动' },
  { value: 'continuous', label: '连续' }
]

const evDisplay = computed(() => {
  const ev = props.template.camera.exposureCompensation
  return ev > 0 ? `+${ev.toFixed(1)}` : ev.toFixed(1)
})

const overlayTypeLabel = (t: string) => ({
  rule_of_thirds: '三分法',
  golden_ratio: '黄金比例',
  diagonal: '对角线',
  grid: '网格',
  leading_lines: '引导线',
  center: '中心',
  none: '无'
}[t] || t)

const wbLabel = (wb: string, k: number) => ({
  daylight: `日光 ${k}K`,
  cloudy: `阴天 ${k}K`,
  shade: `阴影 ${k}K`,
  tungsten: `钨丝灯 ${k}K`,
  fluorescent: '荧光灯',
  custom: `自定义 ${k}K`
}[wb] || wb)

const flashLabel = (f: string) => ({
  off: '关闭',
  on: '常开',
  auto: '自动',
  torch: '手电筒'
}[f] || f)

const focusLabel = (f: string) => ({
  auto: '自动',
  manual: '手动',
  continuous: '连续'
}[f] || f)

const lensLabel = (l?: string) => {
  if (!l) return '标准'
  return ({
    wide: '广角',
    main: '主摄',
    telephoto: '长焦',
    ultra_wide: '超广角',
    standard: '标准'
  } as Record<string, string>)[l] || l
}


// ===== 深拷贝辅助与 color 子对象/postProcess 顶层字段更新方法 =====

/** 深拷贝当前 template，避免 mutate prop */
function cloneTemplate(): PhotoTemplate {
  return JSON.parse(JSON.stringify(props.template))
}

function updateColor<K extends keyof PhotoTemplate['postProcess']['color']>(key: K, value: PhotoTemplate['postProcess']['color'][K]) {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  tpl.postProcess.color[key] = value
  emit('update:template', tpl)
}

/** 滤镜缩略图样式（CSS filter 预览） */
const thumbStyle = (filter: string) => {
  if (!filter) return {}
  return { filter, webkitFilter: filter }
}
</script>

<style lang="scss" scoped>
.param-panel {
  position: fixed;
  inset: 0;
  z-index: 1000;
  pointer-events: none;
}

.param-panel-mask {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  pointer-events: auto;
  animation: fadeIn 0.25s ease;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.param-panel-body {
  /* 拍照页面始终使用深色配色，不跟随全局主题 */
  --color-canvas: #1C1A17;
  --color-surface: #262320;
  --color-surface-alt: #2E2B27;
  --color-canvas-deep: #151310;
  --color-text-primary: #F2EEE6;
  --color-text-secondary: #A39D94;
  --color-text-tertiary: #6E695F;
  --color-text-inverse: #1A1A1A;
  --color-divider: #3A3630;
  --color-brand: #D4B57A;
  --color-brand-deep: #B8985A;
  --color-brand-light: #D4B57A;
  --color-brand-subtle: #2E2820;
  --color-brand-text: #D4B57A;
  --color-brand-rgb: 212, 181, 122;
  --color-danger: #D4706C;
  --color-danger-subtle: #2E201E;
  --color-success: #8FA06A;
  --color-success-subtle: #22251D;
  --color-canvas-rgb: 28, 26, 23;

  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 60vh;
  background-color: var(--color-surface);
  border-radius: 32rpx 32rpx 0 0;
  box-shadow: 0 -8rpx 32rpx rgba(0, 0, 0, 0.12);
  transform: translateY(100%);
  transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
  display: flex;
  flex-direction: column;
  pointer-events: auto;
  overflow-x: hidden;
  box-sizing: border-box;

  &.is-visible {
    transform: translateY(0);
  }
}

/* 拖拽手柄 */
.panel-handle {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20rpx 0 8rpx;
  flex-shrink: 0;
}

.handle-bar {
  width: 80rpx;
  height: 8rpx;
  border-radius: 9999rpx;
  background-color: var(--color-divider);
}

/* 模板概要 */
.panel-summary {
  padding: 12rpx 40rpx 20rpx;
  flex-shrink: 0;
  box-sizing: border-box;
}

.summary-name {
  font-family: var(--font-cn-title);
  font-size: 36rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  line-height: 1.3;
}

.summary-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

/* Tab 切换栏 */
.panel-tabs {
  display: flex;
  padding: 0 20rpx;
  border-bottom: 1rpx solid var(--color-divider);
  flex-shrink: 0;
  overflow-x: auto;
  box-sizing: border-box;
}

.tab-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6rpx;
  padding: 16rpx 0;
  color: var(--color-text-tertiary);
  position: relative;
  transition: color 0.2s ease;

  .ph {
    font-size: 36rpx;
    line-height: 1;
  }

  .tab-label {
    font-size: 22rpx;
    letter-spacing: 0.04em;
  }

  &.active {
    color: var(--color-brand);

    &::after {
      content: '';
      position: absolute;
      bottom: -1rpx;
      left: 50%;
      transform: translateX(-50%);
      width: 48rpx;
      height: 4rpx;
      border-radius: 9999rpx;
      background-color: var(--color-brand);
    }
  }
}

/* 滚动内容区 */
.panel-content {
  flex: 1;
  overflow-x: hidden;
  overflow-y: auto;
  padding: 20rpx 40rpx;
  box-sizing: border-box;
}

.tab-pane {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

/* 参数行 */
.param-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12rpx;
  padding: 20rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
}

.param-label {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  flex-shrink: 0;
}

.param-value {
  flex: 1;
  min-width: 0;
  text-align: right;
  font-size: 26rpx;
  color: var(--color-text-primary);
  font-weight: 500;
  word-break: break-all;
}

/* 滑块块 */
.slider-block {
  padding: 20rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
}

.slider-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12rpx;
}

.slider-value {
  font-size: 26rpx;
  color: var(--color-text-primary);
  font-weight: 500;
}

/* 选项 pill 行 */
.pill {
  display: inline-flex;
  align-items: center;
  padding: 10rpx 20rpx;
  border-radius: 9999rpx;
  background-color: var(--color-surface-alt);
  font-size: 24rpx;
  color: var(--color-text-secondary);
  flex-shrink: 0;
  line-height: 1.2;
}

.pill.active {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #fff;
  font-weight: 500;
}

/* 水平滚动 pill 列表（scroll-view scroll-x 容器） */
.pill-list {
  white-space: nowrap;
}

.pill-list-inner {
  display: inline-flex;
  gap: 8rpx;
  padding: 0 4rpx;
}

.pill-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8rpx;
  padding: 12rpx 0 20rpx;
  border-bottom: 1rpx solid var(--color-divider);
}

.pill-option {
  display: inline-flex;
  align-items: center;
  padding: 10rpx 20rpx;
  border-radius: 9999rpx;
  background-color: var(--color-surface-alt);
  font-size: 24rpx;
  color: var(--color-text-secondary);
  flex-shrink: 0;
  line-height: 1.2;
}

.pill-option.active {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #fff;
  font-weight: 500;
}

/* 描述块 */
.desc-block {
  padding: 20rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
}

.desc-title {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  margin-bottom: 12rpx;
}

.desc-text {
  font-size: 26rpx;
  color: var(--color-text-primary);
  line-height: 1.6;
  word-break: break-all;
}

/* 标签列表 */
.tag-list-block {
  padding: 20rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
}

.prop-tag {
  display: inline-flex;
  align-items: center;
  padding: 8rpx 20rpx;
  border-radius: 9999rpx;
  font-size: 22rpx;
  background-color: var(--color-brand-subtle);
  color: var(--color-brand-text);
}

/* 贴士列表 */
.tips-list {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.tips-item {
  display: flex;
  align-items: flex-start;
  gap: 12rpx;
}

.tips-dot {
  font-size: 24rpx;
  color: var(--color-brand);
  margin-top: 4rpx;
  line-height: 1;
}

.tips-text {
  font-size: 26rpx;
  color: var(--color-text-primary);
  line-height: 1.6;
  flex: 1;
  min-width: 0;
}

.scene-preset-section {
  margin-bottom: 24rpx;
}

.scene-preset-scroll {
  white-space: nowrap;
  margin-top: 16rpx;
}

.scene-preset-list {
  display: inline-flex;
  gap: 16rpx;
  padding: 4rpx;
}

.scene-preset-card {
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
  padding: 20rpx 24rpx;
  border-radius: 20rpx;
  background-color: var(--color-surface-alt);
  border: 2rpx solid transparent;
  min-width: 120rpx;
}

.scene-preset-card.active {
  border-color: var(--color-brand);
  background-color: rgba(255, 200, 120, 0.12);
}

.scene-preset-icon-wrap {
  width: 64rpx;
  height: 64rpx;
  border-radius: 50%;
  background-color: var(--color-canvas-deep);
  display: flex;
  align-items: center;
  justify-content: center;
}

.scene-preset-icon {
  font-size: 36rpx;
  color: var(--color-text-primary);
}

.scene-preset-card.active .scene-preset-icon {
  color: var(--color-brand);
}

.scene-preset-name {
  font-size: 24rpx;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.scene-preset-card.active .scene-preset-name {
  color: var(--color-brand);
}

.scene-apply-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  padding: 24rpx;
  margin: 24rpx 0;
  border-radius: 9999rpx;
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #ffffff;
  font-size: 28rpx;
  font-weight: 500;
}

.scene-apply-btn:active {
  transform: scale(0.98);
  opacity: 0.9;
}

.scene-apply-btn .ph {
  font-size: 32rpx;
}

.scene-suggestion-block {
  padding: 24rpx;
  margin-bottom: 24rpx;
  border-radius: 20rpx;
  background-color: var(--color-surface-alt);
}

/* 剪影预览 */
.silhouette-preview {
  display: flex;
  justify-content: center;
  padding: 20rpx 0;
  margin-bottom: 12rpx;
}

.silhouette-wrap {
  width: 240rpx;
  height: 320rpx;
  background-color: var(--color-canvas-deep);
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.silhouette-img {
  width: 80%;
  height: 80%;
  opacity: 0.7;
}

.silhouette-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
}

.silhouette-icon {
  font-size: 120rpx;
  color: var(--color-text-tertiary);
  opacity: 0.4;
}

/* 底部按钮 */
.panel-footer {
  padding: 20rpx 40rpx;
  padding-bottom: calc(20rpx + env(safe-area-inset-bottom, 0));
  flex-shrink: 0;
  border-top: 1rpx solid var(--color-divider);
  box-sizing: border-box;
}

.apply-btn {
  height: 96rpx;
  border-radius: 16rpx;
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: var(--color-text-inverse);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  font-size: 30rpx;
  font-weight: 500;
  letter-spacing: 0.04em;
  transition: transform 0.15s ease, background 0.3s ease;

  .ph {
    font-size: 32rpx;
  }

  &:active {
    transform: scale(0.97);
  }

  &.is-applied {
    background: linear-gradient(135deg, var(--color-success) 0%, var(--color-success) 100%);
  }
}

/* 原相机模式下参数控件灰化 */
.raw-mode-disabled .pill,
.raw-mode-disabled .pill-option,
.raw-mode-disabled .param-slider,
.raw-mode-disabled .mode-toggle,
.raw-mode-disabled .filter-item,
.raw-mode-disabled .scene-preset-card,
.raw-mode-disabled .scene-apply-btn {
  opacity: 0.5;
  pointer-events: none;
}

.filter-section {
  margin-top: 16rpx;
}

.section-title {
  display: block;
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.6);
  font-weight: 500;
  margin-bottom: 12rpx;
}

.filter-list {
  white-space: nowrap;
}

.filter-list-inner {
  display: inline-flex;
  gap: 16rpx;
  padding: 0 4rpx;
}

.filter-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
  width: 120rpx;
}

.filter-thumb {
  width: 120rpx;
  height: 120rpx;
  border-radius: 16rpx;
  overflow: hidden;
  border: 3rpx solid transparent;
}

.filter-item.active .filter-thumb {
  border-color: #ffcc00;
}

.thumb-img {
  width: 100%;
  height: 100%;
}

.filter-name {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.85);
}

.filter-item.active .filter-name {
  color: #ffcc00;
  font-weight: 600;
}

.pill-list-inline {
  display: flex;
  flex-wrap: wrap;
  gap: 8rpx;
}

.switch-row {
  display: flex;
  justify-content: flex-end;
}
</style>
