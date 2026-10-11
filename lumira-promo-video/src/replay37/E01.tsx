import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {V, FONT2} from '../v2/theme';
import {Paper, Stamp, StickyCap, InkPath, DrawOnImage} from '../v2/ink';
import {ShotClosedEyes, ShotTilted, ShotStiff} from '../v2/props';

/* ============================ 局部组件（竖屏专用） ============================ */

/** 竖屏拍立得：尺寸可调（V2 的 Polaroid 固定 340 不适合竖屏大图） */
const VPolaroid: React.FC<{
  frame: number;
  fps: number;
  start: number;
  w: number;
  rotate?: number;
  children?: React.ReactNode;
}> = ({frame, fps, start, w, rotate = 0, children}) => {
  const s = spring({
    frame: Math.max(0, frame - start),
    fps,
    config: {damping: 13, stiffness: 150},
  });
  const pad = Math.round(w * 0.055);
  const photo = w - pad * 2;
  return (
    <div
      style={{
        width: w,
        background: V.white,
        border: `5px solid ${V.ink}`,
        borderRadius: 12,
        boxShadow: `${Math.round(w * 0.03)}px ${Math.round(w * 0.036)}px 0 rgba(26,26,26,0.12)`,
        transform: `rotate(${rotate}deg) scale(${s}) translateY(${(1 - s) * 60}px)`,
        opacity: s,
        padding: `${pad}px ${pad}px 0`,
      }}
    >
      <div
        style={{
          width: photo,
          height: photo,
          border: `4px solid ${V.ink}`,
          borderRadius: 8,
          overflow: 'hidden',
          background: V.paper,
          position: 'relative',
        }}
      >
        {children}
      </div>
      <div style={{height: Math.round(w * 0.12)}}>
        <svg width={photo * 0.22} height={photo * 0.14} viewBox="0 0 60 40">
          <InkPath
            d="M6 34 Q18 8 30 22 Q40 32 52 10"
            frame={frame}
            start={start + 14}
            duration={12}
            width={3.5}
            color={V.gray}
          />
        </svg>
      </div>
    </div>
  );
};

/** 大计数器：红色数字随重拍次数递减，最后一次变金 */
const TICKS: {f: number; n: number; gold?: boolean}[] = [
  {f: 66, n: 36},
  {f: 100, n: 30},
  {f: 134, n: 24},
  {f: 168, n: 18},
  {f: 202, n: 12},
  {f: 236, n: 10},
  {f: 270, n: 9},
  {f: 285, n: 8},
  {f: 300, n: 7},
  {f: 315, n: 6},
  {f: 330, n: 5},
  {f: 345, n: 4},
  {f: 450, n: 2},
  {f: 480, n: 1, gold: true},
];

const Counter: React.FC<{frame: number; fps: number}> = ({frame, fps}) => {
  let cur = TICKS[0];
  for (const t of TICKS) if (frame >= t.f) cur = t;
  const pop = spring({
    frame: Math.max(0, frame - cur.f),
    fps,
    config: {damping: 11, stiffness: 300},
  });
  const show =
    interpolate(frame, [58, 66], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}) *
    interpolate(frame, [638, 652], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const color = cur.gold ? V.goldDeep : V.red;
  return (
    <div
      style={{
        position: 'absolute',
        top: 110,
        left: 0,
        right: 0,
        textAlign: 'center',
        opacity: show,
        transform: `rotate(-2deg) scale(${interpolate(pop, [0, 1], [1.5, 1])})`,
      }}
    >
      <div style={{fontSize: 40, fontWeight: 700, color: V.inkSoft, letterSpacing: 10}}>
        重拍
      </div>
      <div
        style={{
          fontSize: 180,
          fontWeight: 900,
          color,
          lineHeight: 1.05,
          textShadow: `0 0 2px ${color}`,
        }}
      >
        {cur.n}
      </div>
    </div>
  );
};

/** 废片：路人乱入 */
const ShotCrasher: React.FC<{frame: number; start: number}> = ({frame, start}) => (
  <svg viewBox="0 0 300 260" width="100%" height="100%">
    <InkPath d="M120 66 a38 38 0 1 1 0 76 a38 38 0 1 1 0 -76" frame={frame} start={start} duration={12} width={4.5} />
    <InkPath d="M112 100 q7 5 14 0 M128 100 q7 5 14 0" frame={frame} start={start + 4} duration={6} width={4} />
    <InkPath d="M120 142 q0 44 -12 70 M152 136 q18 44 22 88" frame={frame} start={start + 6} duration={10} width={4} />
    {/* 乱入者：从右侧探头 */}
    <InkPath d="M232 96 a26 26 0 1 1 0.1 0" frame={frame} start={start + 10} duration={8} width={4.5} color={V.inkSoft} />
    <InkPath d="M224 124 q-4 30 6 58" frame={frame} start={start + 14} duration={8} width={4} color={V.inkSoft} />
    <InkPath d="M212 78 h20 l-20 16 h20" frame={frame} start={start + 16} duration={8} width={4.5} color={V.goldDeep} />
  </svg>
);

/** 废片：腿拍没了（半身卡到膝盖） */
const ShotLegs: React.FC<{frame: number; start: number}> = ({frame, start}) => (
  <svg viewBox="0 0 300 260" width="100%" height="100%">
    <InkPath d="M150 54 a40 40 0 1 1 0 80 a40 40 0 1 1 0 -80" frame={frame} start={start} duration={12} width={4.5} />
    <InkPath d="M138 90 q8 6 16 0 M162 90 q8 6 16 0" frame={frame} start={start + 4} duration={6} width={4} />
    <InkPath d="M150 134 q-4 52 -6 96 M186 128 q2 52 0 100" frame={frame} start={start + 6} duration={10} width={4} />
    {/* 地平线切在脚踝 */}
    <InkPath d="M60 236 h180" frame={frame} start={start + 12} duration={8} width={4} color={V.gray} />
    <InkPath d="M96 200 h40 M180 196 h44" frame={frame} start={start + 14} duration={8} width={4} color={V.gray} />
  </svg>
);

/** 废片：手抖糊了 */
const ShotBlur: React.FC<{frame: number; start: number}> = ({frame, start}) => (
  <svg viewBox="0 0 300 260" width="100%" height="100%">
    <g filter="url(#e01-blur)">
      <InkPath d="M150 58 a42 42 0 1 1 0 84 a42 42 0 1 1 0 -84" frame={frame} start={start} duration={12} width={5} />
      <InkPath d="M132 96 q9 7 18 0 M162 96 q9 7 18 0" frame={frame} start={start + 4} duration={6} width={4.5} />
      <InkPath d="M136 124 q16 10 32 0" frame={frame} start={start + 6} duration={6} width={4.5} />
    </g>
    <defs>
      <filter id="e01-blur">
        <feGaussianBlur stdDeviation="4" />
      </filter>
    </defs>
    {/* 抖动轨迹线 */}
    <InkPath d="M70 120 q20 -26 0 -52 M230 140 q-20 26 0 52" frame={frame} start={start + 10} duration={10} width={3.5} color={V.gray} dash="0.04 0.05" />
  </svg>
);

/** 模板手机：三分线 + 剪影 + 参数 */
const TemplatePhone: React.FC<{frame: number; start: number; fps: number}> = ({frame, start, fps}) => {
  const s = spring({frame: Math.max(0, frame - start), fps, config: {damping: 12, stiffness: 160}});
  const pills = ['EV -0.3', '4800K', '三分线·右下'];
  return (
    <div
      style={{
        width: 430,
        height: 860,
        background: V.white,
        border: `7px solid ${V.ink}`,
        borderRadius: 64,
        transform: `translateX(-50%) rotate(1.5deg) scale(${s}) translateY(${(1 - s) * 90}px)`,
        opacity: s,
        position: 'absolute',
        left: '50%',
        top: 560,
        padding: 22,
        boxShadow: '14px 16px 0 rgba(26,26,26,0.12)',
      }}
    >
      <div
        style={{
          width: '100%',
          height: '100%',
          border: '4px solid ' + V.ink,
          borderRadius: 40,
          background: V.paper,
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        {/* 三分线 */}
        <svg viewBox="0 0 360 760" width="100%" height="100%" style={{position: 'absolute', inset: 0}}>
          {[120, 240].map((x, i) => (
            <InkPath key={'v' + i} d={`M${x} 20 V740`} frame={frame} start={start + 14 + i * 4} duration={14} width={2.5} color={V.gray} dash="0.03 0.04" />
          ))}
          {[253, 506].map((y, i) => (
            <InkPath key={'h' + i} d={`M20 ${y} H340`} frame={frame} start={start + 18 + i * 4} duration={14} width={2.5} color={V.gray} dash="0.03 0.04" />
          ))}
          {/* 剪影（右下交点） */}
          <circle cx="248" cy="330" r="34" fill="none" stroke={V.ink} strokeWidth={5} opacity={interpolate(frame, [start + 26, start + 36], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})} />
          <InkPath d="M248 366 C 240 440, 238 500, 242 580" frame={frame} start={start + 28} duration={16} width={5.5} />
          <InkPath d="M242 580 L224 716 M242 580 L268 712" frame={frame} start={start + 36} duration={12} width={5} />
          <InkPath d="M247 400 C 226 440, 220 470, 228 494" frame={frame} start={start + 38} duration={10} width={5} />
          {/* 金色呼吸光点：落点提示 */}
          <circle cx="248" cy="506" r={10 + Math.sin(frame * 0.15) * 4} fill={V.gold} opacity={0.7} />
        </svg>
        {/* 参数 pill */}
        <div style={{position: 'absolute', left: 0, right: 0, bottom: 26, display: 'flex', justifyContent: 'center', gap: 12, flexWrap: 'wrap', padding: '0 18px'}}>
          {pills.map((p, i) => {
            const ps = spring({frame: Math.max(0, frame - start - 46 - i * 8), fps, config: {damping: 13, stiffness: 220}});
            return (
              <div
                key={p}
                style={{
                  background: V.white,
                  border: `3px solid ${V.goldDeep}`,
                  borderRadius: 999,
                  padding: '8px 20px',
                  fontSize: 27,
                  fontWeight: 800,
                  color: V.goldDeep,
                  transform: `scale(${ps})`,
                  opacity: ps,
                }}
              >
                {p}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

/** 金色星尘迸发 */
const SparkleBurst: React.FC<{frame: number; start: number; cx: number; cy: number}> = ({frame, start, cx, cy}) => (
  <svg width={900} height={900} viewBox="-450 -450 900 900" style={{position: 'absolute', left: cx - 450, top: cy - 450, pointerEvents: 'none'}}>
    {[0, 60, 120, 180, 240, 300].map((deg, i) => {
      const p = interpolate(frame, [start + i * 2, start + 34 + i * 2], [0, 1], {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      });
      const r1 = 120 + p * 260;
      const r2 = r1 + 46;
      const rad = (deg * Math.PI) / 180;
      return (
        <line
          key={i}
          x1={Math.cos(rad) * r1}
          y1={Math.sin(rad) * r1}
          x2={Math.cos(rad) * r2}
          y2={Math.sin(rad) * r2}
          stroke={V.gold}
          strokeWidth={7}
          strokeLinecap="round"
          opacity={(1 - p) * 0.9}
        />
      );
    })}
  </svg>
);

/** 竖屏字幕包装：等比缩小 StickyCap 适配 1080 宽 */
const Cap: React.FC<{text: string; frame: number; fps: number; start: number; duration: number; rotate?: number; highlight?: string[]}> = (p) => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      transform: 'scale(0.88)',
      transformOrigin: '50% calc(100% - 60px)',
    }}
  >
    <StickyCap {...p} />
  </div>
);

/* ================================ 音效清单 ================================ */

const SFX: {f: number; src: string; v: number}[] = [
  {f: 34, src: 'sfx/shutter.wav', v: 0.5},
  {f: 66, src: 'sfx/pop.wav', v: 0.32},
  {f: 100, src: 'sfx/pop.wav', v: 0.32},
  {f: 134, src: 'sfx/pop.wav', v: 0.32},
  {f: 168, src: 'sfx/pop.wav', v: 0.32},
  {f: 202, src: 'sfx/pop.wav', v: 0.32},
  {f: 236, src: 'sfx/pop.wav', v: 0.32},
  {f: 270, src: 'sfx/pop.wav', v: 0.28},
  {f: 285, src: 'sfx/pop.wav', v: 0.26},
  {f: 300, src: 'sfx/pop.wav', v: 0.26},
  {f: 315, src: 'sfx/pop.wav', v: 0.26},
  {f: 330, src: 'sfx/pop.wav', v: 0.26},
  {f: 345, src: 'sfx/pop.wav', v: 0.26},
  {f: 360, src: 'sfx/riser.wav', v: 0.45},
  {f: 408, src: 'sfx/pop.wav', v: 0.35},
  {f: 450, src: 'sfx/pop.wav', v: 0.3},
  {f: 480, src: 'sfx/shutter.wav', v: 0.5},
  {f: 530, src: 'sfx/ding.wav', v: 0.45},
  {f: 545, src: 'sfx/pop.wav', v: 0.35},
  {f: 685, src: 'sfx/shutter.wav', v: 0.5},
  {f: 710, src: 'sfx/whoosh.wav', v: 0.4},
];

/* ================================== 正片 ================================== */

export const Replay37E01: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  /* ---- 蒙太奇卡片配置（act2 慢速 + act3 加速） ---- */
  const CARDS: {f: number; n: number; label: string; node: React.ReactNode}[] = [
    {f: 66, n: 36, label: '构图歪了', node: <ShotTilted frame={frame} start={70} />},
    {f: 100, n: 30, label: '有人乱入', node: <ShotCrasher frame={frame} start={104} />},
    {f: 134, n: 24, label: '又闭眼', node: <ShotClosedEyes frame={frame} start={138} />},
    {f: 168, n: 18, label: '腿拍没了', node: <ShotLegs frame={frame} start={172} />},
    {f: 202, n: 12, label: '表情僵硬', node: <ShotStiff frame={frame} start={206} />},
    {f: 236, n: 10, label: '手抖了', node: <ShotBlur frame={frame} start={240} />},
    {f: 270, n: 9, label: '……', node: <ShotTilted frame={frame} start={272} />},
    {f: 285, n: 8, label: '……', node: <ShotClosedEyes frame={frame} start={287} />},
    {f: 300, n: 7, label: '……', node: <ShotStiff frame={frame} start={302} />},
    {f: 315, n: 6, label: '……', node: <ShotCrasher frame={frame} start={317} />},
    {f: 330, n: 5, label: '……', node: <ShotLegs frame={frame} start={332} />},
    {f: 345, n: 4, label: '……', node: <ShotBlur frame={frame} start={347} />},
  ];
  const curCard = [...CARDS].reverse().find((c) => frame >= c.f);

  /* ---- 手机段（360-450） ---- */
  const phoneOut = interpolate(frame, [440, 456], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  /* ---- 终局照片（480 起） ---- */
  const finalIn = interpolate(frame, [472, 486], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  /* ---- 尾幕：贴墙 + 变焦回环（660-750） ---- */
  const wallIn = interpolate(frame, [654, 672], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const zp = interpolate(frame, [710, 748], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // 回环目标：闭眼小照片中心 (185,1677) → 开场大照片中心 (540,805)
  const zoomT = `translate(${355 * zp}px, ${-872 * zp}px) scale(${1 + 3.63 * zp})`;
  const overlayIn = Math.pow(Math.max(0, (zp - 0.72) / 0.28), 2);

  return (
    <AbsoluteFill style={{backgroundColor: V.paper, fontFamily: FONT2}}>
      <Paper>
        {/* ============ Act1 钩子：废片特写 + 红章（0-66，随后退场） ============ */}
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: 300,
            transform: 'translateX(-50%)',
            opacity: interpolate(frame, [58, 70], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}),
          }}
        >
          <VPolaroid frame={frame} fps={fps} start={-999} w={880} rotate={-2}>
            <ShotClosedEyes frame={frame} start={-999} />
          </VPolaroid>
        </div>
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: 1210,
            display: 'flex',
            justifyContent: 'center',
            opacity: interpolate(frame, [56, 68], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}),
          }}
        >
          <Stamp text="重拍 37 次" frame={frame} fps={fps} start={34} size={128} color={V.red} border rotate={-4} />
        </div>

        {/* ============ 计数器 ============ */}
        <Counter frame={frame} fps={fps} />

        {/* ============ Act2/3 蒙太奇卡片 ============ */}
        {curCard && frame < 356 && (
          <>
            <div
              key={curCard.n}
              style={{
                position: 'absolute',
                left: '50%',
                top: 470,
                transform: 'translateX(-50%)',
              }}
            >
              <VPolaroid frame={frame} fps={fps} start={curCard.f} w={700} rotate={curCard.n % 2 === 0 ? 1.6 : -1.6}>
                {curCard.node}
              </VPolaroid>
            </div>
            <div style={{position: 'absolute', left: 0, right: 0, top: 1420, display: 'flex', justifyContent: 'center'}}>
              <Stamp text={curCard.label} frame={frame} fps={fps} start={curCard.f + 4} size={84} color={V.ink} />
            </div>
          </>
        )}

        {/* ============ Act3 模板手机降临（360-450） ============ */}
        {frame >= 356 && (
          <div style={{opacity: phoneOut}}>
            {/* 金光一闪 */}
            <AbsoluteFill
              style={{
                background: `radial-gradient(circle at 50% 58%, rgba(201,169,110,${0.28 * (1 - phoneOut) + 0.2}) 0%, transparent 62%)`,
                opacity: interpolate(frame, [360, 380, 404], [0, 1, 0.35], {extrapolateRight: 'clamp'}),
              }}
            />
            <TemplatePhone frame={frame} start={360} fps={fps} />
          </div>
        )}

        {/* ============ Act4 终局：第 1 次，过了（480-660） ============ */}
        {frame >= 470 && (
          <div style={{opacity: finalIn * (1 - wallIn), position: 'absolute', inset: 0}}>
            <div style={{position: 'absolute', left: '50%', top: 350, transform: 'translateX(-50%)'}}>
              <VPolaroid frame={frame} fps={fps} start={476} w={860} rotate={1.6}>
                <DrawOnImage
                  src="v2/girl-gold.png"
                  frame={frame}
                  start={480}
                  duration={46}
                  width={740}
                  height={740}
                />
              </VPolaroid>
            </div>
            <SparkleBurst frame={frame} start={530} cx={540} cy={830} />
            <div style={{position: 'absolute', left: 0, right: 0, top: 1300, display: 'flex', justifyContent: 'center'}}>
              <Stamp text="一次过" frame={frame} fps={fps} start={545} size={130} color={V.goldDeep} border rotate={-3} />
            </div>
          </div>
        )}

        {/* ============ Act5 尾幕：贴墙 + 变焦回环（654-750） ============ */}
        {frame >= 654 && (
          <AbsoluteFill style={{opacity: wallIn}}>
            <div
              style={{
                position: 'absolute',
                inset: 0,
                transform: zoomT,
                transformOrigin: '185px 1677px',
              }}
            >
              {/* 完美成片（中心） */}
              <div style={{position: 'absolute', left: 290, top: 500}}>
                <VPolaroid frame={frame} fps={fps} start={660} w={500} rotate={2}>
                  <Img
                    src={staticFile('v2/girl-gold.png')}
                    style={{width: '100%', height: '100%', objectFit: 'cover', mixBlendMode: 'multiply'}}
                  />
                </VPolaroid>
              </div>
              {/* 废片群（回环目标：闭眼片 left 90 top 1560 rotate -2） */}
              <div style={{position: 'absolute', left: 90, top: 1560}}>
                <VPolaroid frame={frame} fps={fps} start={664} w={190} rotate={-2}>
                  <ShotClosedEyes frame={frame} start={664} />
                </VPolaroid>
              </div>
              <div style={{position: 'absolute', left: 800, top: 1470}}>
                <VPolaroid frame={frame} fps={fps} start={668} w={190} rotate={5}>
                  <ShotTilted frame={frame} start={668} />
                </VPolaroid>
              </div>
              <div style={{position: 'absolute', left: 830, top: 230}}>
                <VPolaroid frame={frame} fps={fps} start={672} w={190} rotate={-6}>
                  <ShotStiff frame={frame} start={672} />
                </VPolaroid>
              </div>
              <div style={{position: 'absolute', left: 70, top: 210}}>
                <VPolaroid frame={frame} fps={fps} start={676} w={190} rotate={8}>
                  <ShotCrasher frame={frame} start={676} />
                </VPolaroid>
              </div>
            </div>
            <div
              style={{
                position: 'absolute',
                left: 0,
                right: 0,
                top: 1080,
                display: 'flex',
                justifyContent: 'center',
                opacity: interpolate(frame, [704, 714], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}),
              }}
            >
              <Stamp text="第 0 次重拍" frame={frame} fps={fps} start={685} size={92} color={V.red} border rotate={-3} />
            </div>
          </AbsoluteFill>
        )}

        {/* 回环接缝补偿：变焦收尾时叠一张与开场完全一致的静帧 */}
        {zp > 0 && (
          <AbsoluteFill style={{opacity: overlayIn, pointerEvents: 'none'}}>
            <div style={{position: 'absolute', left: '50%', top: 300, transform: 'translateX(-50%)'}}>
              <VPolaroid frame={frame} fps={fps} start={-999} w={880} rotate={-2}>
                <ShotClosedEyes frame={frame} start={-999} />
              </VPolaroid>
            </div>
          </AbsoluteFill>
        )}

        {/* ============ 字幕（3 条，短句快节奏） ============ */}
        <Cap text="每一张，都差一点意思" frame={frame} fps={fps} start={76} duration={82} highlight={['差一点意思']} />
        <Cap text="直到她打开了那个模板" frame={frame} fps={fps} start={372} duration={74} rotate={1} highlight={['模板']} />
        <Cap text="原来好看的照片，是有方法的" frame={frame} fps={fps} start={548} duration={88} rotate={-0.8} highlight={['方法']} />

        {/* ============ 音效 ============ */}
        {SFX.map((s, i) => (
          <Sequence key={i} from={s.f} durationInFrames={60}>
            <Audio src={staticFile(s.src)} volume={s.v} />
          </Sequence>
        ))}
      </Paper>
    </AbsoluteFill>
  );
};
