import React from 'react';
import {AbsoluteFill, Img, interpolate, spring, staticFile} from 'remotion';
import {V, FONT2} from './theme';

/* ---------------------------------- 纸张背景 --------------------------------- */

/** 纸张底 + 纤维噪点 + 暗角。每个场景必用 */
export const Paper: React.FC<{children?: React.ReactNode}> = ({children}) => {
  return (
    <AbsoluteFill style={{backgroundColor: V.paper, fontFamily: FONT2}}>
      {/* 纸张纤维噪点（静态，保证渲染确定性） */}
      <AbsoluteFill>
        <svg width="100%" height="100%" style={{opacity: 0.5}}>
          <filter id="paper-fiber">
            <feTurbulence
              type="fractalNoise"
              baseFrequency="0.9"
              numOctaves={2}
              seed={7}
            />
            <feColorMatrix
              values="0 0 0 0 0.72  0 0 0 0 0.68  0 0 0 0 0.62  0 0 0 0.06 0"
            />
          </filter>
          <rect width="100%" height="100%" filter="url(#paper-fiber)" />
        </svg>
      </AbsoluteFill>
      {children}
      {/* 暗角 */}
      <AbsoluteFill
        style={{
          background:
            'radial-gradient(ellipse at center, transparent 55%, rgba(74,70,64,0.16) 100%)',
          pointerEvents: 'none',
        }}
      />
    </AbsoluteFill>
  );
};

/* --------------------------------- 墨线生长组件 -------------------------------- */

/** 墨线：pathLength 归一化，从 start 帧开始"画"出来 */
export const InkPath: React.FC<{
  d: string;
  frame: number;
  start: number;
  duration?: number;
  width?: number;
  color?: string;
  opacity?: number;
  dash?: string;
  strokeLinecap?: 'round' | 'butt';
}> = ({
  d,
  frame,
  start,
  duration = 20,
  width = 5,
  color = V.ink,
  opacity = 1,
  dash,
  strokeLinecap = 'round',
}) => {
  const p = interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <path
      d={d}
      fill="none"
      stroke={color}
      strokeWidth={width}
      strokeLinecap={strokeLinecap}
      strokeLinejoin="round"
      pathLength={1}
      strokeDasharray={dash ?? '1'}
      strokeDashoffset={1 - p}
      opacity={opacity}
    />
  );
};

/** 墨点：弹性缩放入场 */
export const InkDot: React.FC<{
  cx: number;
  cy: number;
  r: number;
  frame: number;
  start: number;
  fps: number;
  color?: string;
}> = ({cx, cy, r, frame, start, fps, color = V.ink}) => {
  const s = spring({frame: Math.max(0, frame - start), fps, config: {damping: 12, stiffness: 200}});
  return <circle cx={cx} cy={cy} r={r * s} fill={color} opacity={s} />;
};

/* ---------------------------------- 盖章文字 ---------------------------------- */

/** 盖章大字：快速砸下 + 微旋转 + 墨点飞溅感 */
export const Stamp: React.FC<{
  text: string;
  frame: number;
  fps: number;
  start: number;
  size: number;
  color?: string;
  rotate?: number;
  border?: boolean;
}> = ({text, frame, fps, start, size, color = V.red, rotate = -3, border}) => {
  const s = spring({
    frame: Math.max(0, frame - start),
    fps,
    config: {damping: 11, stiffness: 260, mass: 0.9},
  });
  const punch = interpolate(s, [0, 1], [2.6, 1]);
  return (
    <div
      style={{
        display: 'inline-block',
        transform: `scale(${punch}) rotate(${rotate * s}deg)`,
        opacity: s,
        padding: border ? '10px 34px 14px' : 0,
        border: border ? `6px solid ${color}` : undefined,
        borderRadius: 14,
      }}
    >
      <span
        style={{
          fontSize: size,
          fontWeight: 900,
          color,
          letterSpacing: 4,
          textShadow: `0 0 1px ${color}`,
        }}
      >
        {text}
      </span>
    </div>
  );
};

/* --------------------------------- 贴纸字幕条 --------------------------------- */

/** 手账贴纸风字幕：白底 + 墨边 + 微旋转 + 逐字弹出 + 到时自动退场 */
export const StickyCap: React.FC<{
  text: string;
  frame: number;
  fps: number;
  start: number;
  duration?: number;
  rotate?: number;
  highlight?: string[];
}> = ({text, frame, fps, start, duration, rotate = -1.2, highlight = []}) => {
  const box = spring({
    frame: Math.max(0, frame - start),
    fps,
    config: {damping: 14, stiffness: 160},
  });
  // 退场：淡出 + 下滑（默认常驻，传入 duration 才退场）
  const exit = duration
    ? interpolate(frame, [start + duration, start + duration + 12], [0, 1], {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      })
    : 0;
  const boxOpacity = box * (1 - exit);
  // 高亮词切分
  let segs: {t: string; hl: boolean}[] = [];
  let rest = text;
  while (rest.length) {
    let hit = '';
    for (const h of highlight) {
      if (rest.startsWith(h) && h.length > hit.length) hit = h;
    }
    if (hit) {
      segs.push({t: hit, hl: true});
      rest = rest.slice(hit.length);
    } else {
      const nextHl = highlight
        .map((h) => rest.indexOf(h))
        .filter((i) => i > 0)
        .sort((a, b) => a - b)[0];
      const chunk = nextHl ? rest.slice(0, nextHl) : rest;
      segs.push({t: chunk, hl: false});
      rest = rest.slice(chunk.length);
    }
  }
  let charIdx = 0;
  return (
    <div
      style={{
        position: 'absolute',
        left: '50%',
        bottom: 64,
        transform: `translateX(-50%) translateY(${(1 - box) * 40 + exit * 26}px) rotate(${rotate}deg)`,
        opacity: boxOpacity,
        background: V.white,
        border: `3px solid ${V.ink}`,
        borderRadius: 16,
        boxShadow: `6px 6px 0 rgba(26,26,26,0.14)`,
        padding: '16px 36px',
        maxWidth: 1400,
      }}
    >
      {segs.map((seg, i) => (
        <span
          key={i}
          style={{
            fontSize: 40,
            fontWeight: 700,
            color: seg.hl ? V.goldDeep : V.ink,
            display: 'inline-block',
            whiteSpace: 'pre',
          }}
        >
          {seg.t.split('').map((ch, j) => {
            const cs = spring({
              frame: Math.max(0, frame - start - 4 - charIdx++ * 1.2),
              fps,
              config: {damping: 200},
            });
            return (
              <span
                key={j}
                style={{
                  display: 'inline-block',
                  opacity: cs,
                  transform: `translateY(${(1 - cs) * 8}px)`,
                }}
              >
                {ch}
              </span>
            );
          })}
        </span>
      ))}
    </div>
  );
};

/* --------------------------------- 呼吸/漂浮 --------------------------------- */

/** 万物呼吸：返回一个随帧缓慢起伏的偏移 */
export const breathe = (frame: number, amp = 6, speed = 0.03, phase = 0) =>
  Math.sin((frame + phase) * speed) * amp;

/* ----------------------------- 位图"手绘"模拟 ----------------------------- */

/**
 * 生图素材的手绘入场：自上而下 clipPath 显影 + 笔尖墨点跟随显影边
 * 模拟钢笔在纸上画出的过程（位图无法逐笔生长，用此近似）
 */
export const DrawOnImage: React.FC<{
  src: string;
  frame: number;
  start: number;
  duration?: number;
  width: number;
  height: number;
  imgStyle?: React.CSSProperties;
}> = ({src, frame, start, duration = 40, width, height, imgStyle}) => {
  const progress = interpolate(frame, [start, start + duration], [0, 100], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const drawing = progress > 0 && progress < 100;
  // 笔尖：跟随显影边，横向带手抖正弦
  const tipY = (progress / 100) * height;
  const tipX = width / 2 + Math.sin(frame * 0.9) * width * 0.16;
  return (
    <div style={{position: 'relative', width, height}}>
      <Img
        src={staticFile(src)}
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'contain',
          mixBlendMode: 'multiply',
          clipPath: `inset(0 0 ${100 - progress}% 0)`,
          ...imgStyle,
        }}
      />
      {drawing && (
        <svg
          width={width}
          height={height}
          style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}
        >
          {/* 笔尖墨点 + 短拖尾 */}
          <circle cx={tipX} cy={tipY} r={7} fill="#1A1A1A" />
          <line
            x1={tipX}
            y1={tipY}
            x2={tipX + 26}
            y2={tipY - 40}
            stroke="#1A1A1A"
            strokeWidth={5}
            strokeLinecap="round"
            opacity={0.85}
          />
          <line
            x1={tipX + 26}
            y1={tipY - 40}
            x2={tipX + 40}
            y2={tipY - 66}
            stroke="#4A4640"
            strokeWidth={9}
            strokeLinecap="round"
            opacity={0.55}
          />
        </svg>
      )}
    </div>
  );
};
