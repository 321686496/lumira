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
import {C} from '../theme';
import {Paper, Stamp, StickyCap, InkPath} from '../v2/ink';
import {ShotClosedEyes, ShotTilted, ShotStiff} from '../v2/props';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

/** 金色星尘迸发（双描边 + 端点光点，12 向星芒） */
const SparkleBurst: React.FC<{frame: number; start: number; cx: number; cy: number}> = ({frame, start, cx, cy}) => (
  <svg width={1500} height={1500} viewBox="-750 -750 1500 1500" style={{position: 'absolute', left: cx - 750, top: cy - 750, pointerEvents: 'none'}}>
    {Array.from({length: 12}, (_, i) => i * 30).map((deg) => {
      const p = interpolate(frame, [start + (deg % 90) / 30, start + 52 + (deg % 90) / 30], [0, 1], clamp);
      const r1 = 60 + p * 520;
      const r2 = r1 + 110;
      const rad = (deg * Math.PI) / 180;
      const o = 1 - p;
      const x1 = Math.cos(rad) * r1;
      const y1 = Math.sin(rad) * r1;
      const x2 = Math.cos(rad) * r2;
      const y2 = Math.sin(rad) * r2;
      return (
        <g key={deg}>
          <line x1={x1} y1={y1} x2={x2} y2={y2} stroke={C.goldBright} strokeWidth={18} strokeLinecap="round" opacity={o * 0.5} />
          <line x1={x1} y1={y1} x2={x2} y2={y2} stroke={C.goldBright} strokeWidth={8} strokeLinecap="round" opacity={o} />
          <circle cx={x2} cy={y2} r={9} fill={C.goldBright} opacity={o} />
        </g>
      );
    })}
  </svg>
);

/* ============================ 局部组件（竖屏专用） ============================ */

/** 竖屏拍立得（自 replay37/E01.tsx 拷贝） */
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

/** 竖屏字幕包装（自 replay37/E01.tsx 拷贝） */
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

/** P2 竖排金句（暗场专用）：底层辉光 + 顶层锐利金属渐变 */
const AtmoWord: React.FC<{text: string; s: number}> = ({text, s}) => (
  <div style={{position: 'relative', transform: `scale(${s})`, opacity: s}}>
    <div
      style={{
        position: 'absolute',
        inset: 0,
        writingMode: 'vertical-rl',
        fontSize: 158,
        fontWeight: 900,
        letterSpacing: 14,
        lineHeight: 1.1,
        color: C.goldBright,
        filter: 'blur(24px)',
        opacity: 0.95,
      }}
    >
      {text}
    </div>
    <div
      style={{
        position: 'relative',
        writingMode: 'vertical-rl',
        fontSize: 158,
        fontWeight: 900,
        letterSpacing: 14,
        lineHeight: 1.1,
        backgroundImage: 'linear-gradient(175deg, #FFF6DC 0%, #FFD98A 32%, #FFB45B 58%, #E8954A 100%)',
        WebkitBackgroundClip: 'text',
        backgroundClip: 'text',
        color: 'transparent',
        filter: 'drop-shadow(0 5px 12px rgba(0,0,0,0.5))',
      }}
    >
      {text}
    </div>
  </div>
);

/** P3 标注：藏——沿人物轮廓强调线 + 箭头指向 */
const TipHideAnno: React.FC<{frame: number; start: number}> = ({frame, start}) => (
  <svg viewBox="0 0 766 766" style={{position: 'absolute', inset: 0, width: '100%', height: '100%'}}>
    <InkPath d="M300 180 C 250 300, 255 470, 300 620" frame={frame} start={start + 16} duration={18} width={7} color={V.goldDeep} />
    <InkPath d="M356 190 C 402 300, 404 460, 356 612" frame={frame} start={start + 21} duration={18} width={7} color={V.goldDeep} opacity={0.75} />
    <InkPath d="M612 236 C 530 252, 448 276, 384 318" frame={frame} start={start + 36} duration={14} width={8} color={V.goldDeep} />
    <InkPath d="M438 292 L 384 318 L 428 352" frame={frame} start={start + 48} duration={8} width={8} color={V.goldDeep} />
  </svg>
);

/** P3 标注：光——光斑圈选 + 短射线 */
const TipLightAnno: React.FC<{frame: number; start: number}> = ({frame, start}) => (
  <svg viewBox="0 0 766 766" style={{position: 'absolute', inset: 0, width: '100%', height: '100%'}}>
    <InkPath d="M615 195 a95 95 0 1 1 -0.1 0" frame={frame} start={start + 16} duration={18} width={7} color={V.goldDeep} />
    {[0, 60, 120, 180, 240, 300].map((deg) => {
      const rad = (deg * Math.PI) / 180;
      const x1 = 520 + Math.cos(rad) * 118;
      const y1 = 195 + Math.sin(rad) * 118;
      const x2 = 520 + Math.cos(rad) * 168;
      const y2 = 195 + Math.sin(rad) * 168;
      return (
        <InkPath key={deg} d={`M${x1} ${y1} L${x2} ${y2}`} frame={frame} start={start + 34} duration={10} width={6} color={V.goldDeep} />
      );
    })}
  </svg>
);

/** P3 标注：远——三分线 + 交点金色呼吸光点 */
const TipFarAnno: React.FC<{frame: number; start: number}> = ({frame, start}) => (
  <svg viewBox="0 0 766 766" style={{position: 'absolute', inset: 0, width: '100%', height: '100%'}}>
    <InkPath d="M255 30 V736" frame={frame} start={start + 14} duration={14} width={4} color={V.white} opacity={0.9} dash="0.03 0.04" />
    <InkPath d="M511 30 V736" frame={frame} start={start + 18} duration={14} width={4} color={V.white} opacity={0.9} dash="0.03 0.04" />
    <InkPath d="M30 255 H736" frame={frame} start={start + 22} duration={14} width={4} color={V.white} opacity={0.9} dash="0.03 0.04" />
    <InkPath d="M30 511 H736" frame={frame} start={start + 26} duration={14} width={4} color={V.white} opacity={0.9} dash="0.03 0.04" />
    <circle cx={511} cy={511} r={16 + Math.sin(frame * 0.15) * 4} fill={V.gold} opacity={0.9} stroke="rgba(26,26,26,0.4)" strokeWidth={3} />
    <circle cx={511} cy={511} r={6} fill={V.white} />
  </svg>
);

/** P3 三招拍立得卡：AI 图 + 手绘标注 + 金章 */
const TipCard: React.FC<{
  frame: number;
  fps: number;
  start: number;
  img: string;
  label: string;
  anno: React.ReactNode;
}> = ({frame, fps, start, img, label, anno}) => (
  <div style={{position: 'absolute', left: '50%', top: 430, transform: 'translateX(-50%)'}}>
    <VPolaroid frame={frame} fps={fps} start={start} w={860} rotate={-1.2}>
      <Img src={staticFile(img)} style={{width: '100%', height: '100%', objectFit: 'cover'}} />
      {anno}
    </VPolaroid>
    <div style={{position: 'absolute', top: -24, right: -34}}>
      <Stamp text={label} frame={frame} fps={fps} start={start + 30} size={96} color={V.goldDeep} rotate={6} />
    </div>
  </div>
);

/** P4 对比：左→右擦除，before 渐被 after 替换 + 金章「出片」 */
const BeforeAfter: React.FC<{frame: number; start: number; fps: number}> = ({frame, start, fps}) => {
  const p = interpolate(frame, [start, start + 50], [100, 0], clamp);
  const left = `${100 - p}%`;
  return (
    <div style={{position: 'absolute', inset: 0}}>
      <Img src={staticFile('atmo/after.jpg')} style={{position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover'}} />
      <div style={{position: 'absolute', inset: 0, clipPath: `inset(0 0 0 ${left})`}}>
        <Img src={staticFile('atmo/before.jpg')} style={{width: '100%', height: '100%', objectFit: 'cover'}} />
      </div>
      {p > 0 && p < 100 && <div style={{position: 'absolute', top: 0, bottom: 0, left, width: 4, background: V.ink}} />}
      <div style={{position: 'absolute', left: '50%', bottom: 30, transform: 'translateX(-50%)'}}>
        <Stamp text="出片" frame={frame} fps={fps} start={start + 50} size={70} color={V.goldDeep} rotate={-3} border />
      </div>
    </div>
  );
};

/** P4 手机：模板库列表 → 模板详情 → 擦除对比（屏内三幕） */
const DemoPhone: React.FC<{frame: number; start: number; fps: number}> = ({frame, start, fps}) => {
  const s = spring({frame: Math.max(0, frame - start), fps, config: {damping: 12, stiffness: 160}});
  const rows = [
    {name: '黄昏逆光', tag: '氛围 · 黄昏', bg: 'linear-gradient(135deg,#F7B267,#E2571B)'},
    {name: '窗边光斑', tag: '氛围 · 室内', bg: 'linear-gradient(135deg,#FDF3E0,#D9C9A8)'},
    {name: '街角远景', tag: '氛围 · 街拍', bg: 'linear-gradient(135deg,#9AA7B8,#4A5468)'},
  ];
  const pills = ['构图·三分线', '姿势·侧身', '场景·黄昏'];
  const o1 =
    interpolate(frame, [start + 12, start + 18], [0, 1], clamp) * interpolate(frame, [736, 744], [1, 0], clamp);
  const o2 = interpolate(frame, [740, 746], [0, 1], clamp) * interpolate(frame, [826, 832], [1, 0], clamp);
  const o3 = interpolate(frame, [830, 836], [0, 1], clamp);
  return (
    <div
      style={{
        position: 'absolute',
        left: '50%',
        top: 500,
        width: 430,
        height: 860,
        background: V.white,
        border: `7px solid ${V.ink}`,
        borderRadius: 64,
        transform: `translateX(-50%) rotate(1.5deg) scale(${s}) translateY(${(1 - s) * 90}px)`,
        opacity: s,
        padding: 22,
        boxShadow: '14px 16px 0 rgba(26,26,26,0.12)',
      }}
    >
      <div
        style={{
          width: '100%',
          height: '100%',
          border: `4px solid ${V.ink}`,
          borderRadius: 40,
          background: V.paper,
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        {/* 幕1：模板库列表 */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            padding: '26px 22px',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            gap: 18,
            opacity: o1,
          }}
        >
          {rows.map((r, i) => {
            const rs = spring({frame: Math.max(0, frame - start - 20 - i * 10), fps, config: {damping: 13, stiffness: 200}});
            return (
              <div
                key={r.name}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 16,
                  background: V.white,
                  border: `3px solid ${V.ink}`,
                  borderRadius: 18,
                  padding: 14,
                  transform: `translateX(${(1 - rs) * 120}px)`,
                  opacity: rs,
                }}
              >
                <div style={{width: 92, height: 92, borderRadius: 12, border: `3px solid ${V.ink}`, background: r.bg, flexShrink: 0}} />
                <div style={{flex: 1}}>
                  <div style={{fontSize: 33, fontWeight: 800, color: V.ink}}>{r.name}</div>
                  <div
                    style={{
                      marginTop: 8,
                      display: 'inline-block',
                      border: `2.5px solid ${V.goldDeep}`,
                      color: V.goldDeep,
                      borderRadius: 999,
                      padding: '3px 12px',
                      fontSize: 21,
                      fontWeight: 700,
                    }}
                  >
                    {r.tag}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
        {/* 幕2：模板详情（三分线 + 剪影 + 参数 pill） */}
        <div style={{position: 'absolute', inset: 0, opacity: o2}}>
          <svg viewBox="0 0 360 760" width="100%" height="100%" style={{position: 'absolute', inset: 0}}>
            {[120, 240].map((x, i) => (
              <InkPath key={'v' + i} d={`M${x} 20 V740`} frame={frame} start={748 + i * 4} duration={14} width={2.5} color={V.gray} dash="0.03 0.04" />
            ))}
            {[253, 506].map((y, i) => (
              <InkPath key={'h' + i} d={`M20 ${y} H340`} frame={frame} start={752 + i * 4} duration={14} width={2.5} color={V.gray} dash="0.03 0.04" />
            ))}
            <circle cx="248" cy="330" r="34" fill="none" stroke={V.ink} strokeWidth={5} opacity={interpolate(frame, [760, 770], [0, 1], clamp)} />
            <InkPath d="M248 366 C 240 440, 238 500, 242 580" frame={frame} start={762} duration={16} width={5.5} />
            <InkPath d="M242 580 L224 716 M242 580 L268 712" frame={frame} start={770} duration={12} width={5} />
            <InkPath d="M247 400 C 226 440, 220 470, 228 494" frame={frame} start={772} duration={10} width={5} />
            <circle cx="248" cy="506" r={10 + Math.sin(frame * 0.15) * 4} fill={V.gold} opacity={0.7} />
          </svg>
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              bottom: 26,
              display: 'flex',
              justifyContent: 'center',
              gap: 10,
              flexWrap: 'wrap',
              padding: '0 16px',
            }}
          >
            {pills.map((p, i) => {
              const ps = spring({frame: Math.max(0, frame - 780 - i * 8), fps, config: {damping: 13, stiffness: 220}});
              return (
                <div
                  key={p}
                  style={{
                    background: V.white,
                    border: `3px solid ${V.goldDeep}`,
                    borderRadius: 999,
                    padding: '7px 16px',
                    fontSize: 24,
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
        {/* 幕3：擦除对比 */}
        <div style={{position: 'absolute', inset: 0, opacity: o3}}>
          <BeforeAfter frame={frame} start={830} fps={fps} />
        </div>
      </div>
    </div>
  );
};

/* ================================ 音效清单 ================================ */

const SFX: {f: number; src: string; v: number}[] = [
  {f: 40, src: 'sfx/shutter.wav', v: 0.5},
  {f: 100, src: 'sfx/pop.wav', v: 0.32},
  {f: 150, src: 'sfx/pop.wav', v: 0.32},
  {f: 200, src: 'sfx/pop.wav', v: 0.32},
  {f: 250, src: 'sfx/riser.wav', v: 0.45},
  {f: 300, src: 'sfx/ding.wav', v: 0.45},
  {f: 370, src: 'sfx/pop.wav', v: 0.3},
  {f: 470, src: 'sfx/pop.wav', v: 0.3},
  {f: 570, src: 'sfx/pop.wav', v: 0.3},
  {f: 660, src: 'sfx/shutter.wav', v: 0.5},
  {f: 680, src: 'sfx/pop.wav', v: 0.3},
  {f: 740, src: 'sfx/pop.wav', v: 0.3},
  {f: 830, src: 'sfx/pop.wav', v: 0.3},
  {f: 910, src: 'sfx/pop.wav', v: 0.28},
  {f: 940, src: 'sfx/pop.wav', v: 0.28},
  {f: 955, src: 'sfx/pop.wav', v: 0.28},
  {f: 970, src: 'sfx/pop.wav', v: 0.28},
  {f: 1010, src: 'sfx/whoosh.wav', v: 0.4},
];

/* ================================== 正片 ================================== */

export const AtmoE01: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  /* ---- P0 钩子（0-90）：怼脸翻车自拍急推 + 抖动 ---- */
  const p0Zoom = interpolate(frame, [10, 55], [1, 1.6], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const p0Shake = Math.sin(frame * 1.7) * 3;
  const p0Out = interpolate(frame, [58, 70], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{backgroundColor: V.paper, fontFamily: FONT2}}>
      <Paper>
        {/* ============ P0 钩子：翻车自拍 + 红章（0-90） ============ */}
        {frame < 90 && (
          <>
            <div
              style={{
                position: 'absolute',
                left: '50%',
                top: 300,
                opacity: p0Out,
              }}
            >
              <div style={{transform: `translateX(-50%) scale(${p0Zoom})`, transformOrigin: '50% 45%'}}>
                <div style={{transform: `translateX(${p0Shake}px)`}}>
                  <VPolaroid frame={frame} fps={fps} start={-999} w={880} rotate={-2}>
                    <Img
                      src={staticFile('atmo/bad-closeup.jpg')}
                      style={{width: '100%', height: '100%', objectFit: 'cover'}}
                    />
                  </VPolaroid>
                </div>
              </div>
            </div>
            <div
              style={{
                position: 'absolute',
                left: 0,
                right: 0,
                top: 1230,
                display: 'flex',
                justifyContent: 'center',
                opacity: p0Out,
              }}
            >
              <Stamp text="脸不好看" frame={frame} fps={fps} start={34} size={110} color={V.red} border rotate={-4} />
            </div>
          </>
        )}

        {/* ============ P1 共鸣：三张废片卡甩入（90-240） ============ */}
        {frame >= 90 && frame < 240 && (() => {
          const fadeAll = interpolate(frame, [228, 240], [1, 0], clamp);
          const cards = [
            {f: 100, rotate: 1.6, node: <ShotTilted frame={frame} start={104} />},
            {f: 150, rotate: -1.6, node: <ShotClosedEyes frame={frame} start={154} />},
            {f: 200, rotate: 1.6, node: <ShotStiff frame={frame} start={204} />},
          ];
          const cur = [...cards].reverse().find((c) => frame >= c.f);
          if (!cur) return null;
          return (
            <div
              key={cur.f}
              style={{
                position: 'absolute',
                left: '50%',
                top: 470,
                transform: 'translateX(-50%)',
                opacity: fadeAll,
              }}
            >
              <VPolaroid frame={frame} fps={fps} start={cur.f} w={700} rotate={cur.rotate}>
                {cur.node}
              </VPolaroid>
            </div>
          );
        })()}

        {/* ============ P2 转折：白闪 → 暗场金光爆发 + 星尘 + 竖排大字（240-360） ============ */}
        {frame >= 240 && frame < 360 && (() => {
          const stage =
            interpolate(frame, [240, 252], [0, 1], clamp) * interpolate(frame, [336, 358], [1, 0], clamp);
          const flash = interpolate(frame, [238, 244], [0, 0.9], clamp) * interpolate(frame, [246, 258], [1, 0], clamp);
          const glow =
            interpolate(frame, [240, 262], [0, 1], clamp) * interpolate(frame, [300, 342], [1, 0.7], clamp);
          const exit = interpolate(frame, [330, 355], [0, 1], clamp);
          const s1 = spring({frame: Math.max(0, frame - 260), fps, config: {damping: 12, stiffness: 170}});
          const s2 = spring({frame: Math.max(0, frame - 280), fps, config: {damping: 12, stiffness: 170}});
          return (
            <>
              <AbsoluteFill style={{opacity: stage}}>
                {/* 暗场基底：给金光一个「夜」作依托 */}
                <AbsoluteFill
                  style={{
                    background: 'radial-gradient(circle at 50% 54%, #4E3617 0%, #33240F 46%, #170F06 100%)',
                  }}
                />
                {/* 金光爆发（外圈琥珀 + 内核米金） */}
                <AbsoluteFill
                  style={{
                    background: `radial-gradient(circle at 50% 55%, rgba(255,180,91,${glow * 0.95}) 0%, rgba(255,160,60,${glow * 0.55}) 30%, transparent 62%)`,
                  }}
                />
                <AbsoluteFill
                  style={{
                    background: `radial-gradient(circle at 50% 55%, rgba(255,246,224,${glow}) 0%, transparent 34%)`,
                  }}
                />
                <SparkleBurst frame={frame} start={252} cx={540} cy={990} />
                {/* 边缘深暗角：把视线钉在中心 */}
                <AbsoluteFill
                  style={{
                    background: 'radial-gradient(ellipse at center, transparent 36%, rgba(8,5,2,0.78) 100%)',
                  }}
                />
                {/* 竖排大字：辉光层 + 锐利金属层 */}
                <div
                  style={{
                    position: 'absolute',
                    inset: 0,
                    display: 'flex',
                    justifyContent: 'center',
                    alignItems: 'center',
                    gap: 70,
                    opacity: 1 - exit,
                    transform: `translateY(${-50 * exit}px)`,
                  }}
                >
                  <AtmoWord text="拍氛围" s={s2} />
                  <AtmoWord text="别拍脸" s={s1} />
                </div>
              </AbsoluteFill>
              <AbsoluteFill style={{backgroundColor: '#FDFBF7', opacity: flash, pointerEvents: 'none'}} />
            </>
          );
        })()}

        {/* ============ P3 三招：藏 / 光 / 远（360-660） ============ */}
        {frame >= 350 && frame < 660 && (() => {
          const tips = [
            {enter: 360, img: 'atmo/tip-hide.jpg', label: '藏', anno: <TipHideAnno frame={frame} start={360} />},
            {enter: 460, img: 'atmo/tip-light.jpg', label: '光', anno: <TipLightAnno frame={frame} start={460} />},
            {enter: 560, img: 'atmo/tip-far.jpg', label: '远', anno: <TipFarAnno frame={frame} start={560} />},
          ];
          let idx = -1;
          for (let i = 0; i < tips.length; i++) if (frame >= tips[i].enter) idx = i;
          if (idx < 0) return null;
          const cur = tips[idx];
          const prev = idx > 0 ? tips[idx - 1] : null;
          const prevOut = prev ? interpolate(frame, [cur.enter, cur.enter + 10], [1, 0], clamp) : 0;
          return (
            <>
              {prev && (
                <div
                  style={{
                    position: 'absolute',
                    left: '50%',
                    top: 430,
                    transform: 'translateX(-50%)',
                    opacity: prevOut,
                  }}
                >
                  <VPolaroid frame={frame} fps={fps} start={-999} w={860} rotate={1.2}>
                    <Img src={staticFile(prev.img)} style={{width: '100%', height: '100%', objectFit: 'cover'}} />
                  </VPolaroid>
                </div>
              )}
              <TipCard frame={frame} fps={fps} start={cur.enter} img={cur.img} label={cur.label} anno={cur.anno} />
            </>
          );
        })()}

        {/* ============ P4 产品演示：手机三幕（660-900） ============ */}
        {frame >= 656 && frame < 906 && (() => {
          const leave = interpolate(frame, [888, 904], [1, 0], clamp);
          return (
            <div style={{position: 'absolute', inset: 0, opacity: leave}}>
              <DemoPhone frame={frame} start={660} fps={fps} />
            </div>
          );
        })()}

        {/* ============ 转折后全片暖调罩（240 起持续） ============ */}
        <AbsoluteFill
          style={{
            background: `rgba(201,169,110,${interpolate(frame, [240, 262], [0, 0.16], clamp)})`,
            pointerEvents: 'none',
          }}
        />

        {/* ============ 字幕 ============ */}
        <Cap text="脸不好看，怎么出片？" frame={frame} fps={fps} start={34} duration={66} highlight={['脸不好看']} />
        <Cap text="每次拍照都翻车？" frame={frame} fps={fps} start={104} duration={124} rotate={1} highlight={['翻车']} />
        <Cap text="侧身藏进光影里" frame={frame} fps={fps} start={376} duration={74} rotate={1} highlight={['藏']} />
        <Cap text="让光替你说话" frame={frame} fps={fps} start={476} duration={74} highlight={['光']} />
        <Cap text="退远，环境讲故事" frame={frame} fps={fps} start={576} duration={74} rotate={-1} highlight={['环境']} />
        <Cap text="不用学，跟着模板拍就行" frame={frame} fps={fps} start={676} duration={210} highlight={['模板']} />

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
