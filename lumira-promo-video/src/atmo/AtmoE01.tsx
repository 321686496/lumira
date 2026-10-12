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
