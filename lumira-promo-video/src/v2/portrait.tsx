import React from 'react';
import {interpolate} from 'remotion';
import {V} from './theme';
import {InkPath, InkDot} from './ink';

/**
 * 侧脸少女（黑白墨线插画）
 * viewBox 0 0 400 400，面朝左。
 * - colored=false：纯墨线（钩子/线稿版）
 * - colored=true ：金色水彩晕染 + 上色（全片唯一上色时刻）
 * - blinkAt：眨眼帧数组
 */
export const PortraitGirl: React.FC<{
  frame: number;
  start?: number;
  colored?: boolean;
  blinkAt?: number[];
  speed?: number; // 墨线生长速度倍率（越小越快）
}> = ({frame, start = 0, colored = false, blinkAt = [], speed = 1}) => {
  const d = (n: number) => start + n * speed;
  const ink = colored ? V.ink : V.ink;

  // 眨眼脉冲：在 blinkAt 各时刻 0.15s 内合眼
  let eyeOpen = 1;
  for (const b of blinkAt) {
    const pulse =
      1 -
      interpolate(frame, [b - 3, b, b + 3], [0, 1, 0], {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      });
    eyeOpen = Math.min(eyeOpen, 1 - pulse);
  }

  // 金色水彩晕染的呼吸
  const glow = colored ? interpolate(Math.sin(frame * 0.05), [-1, 1], [0.75, 1]) : 0;

  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%">
      {/* ---------- 上色版：背景水彩 + 皮肤/唇/发填充 ---------- */}
      {colored && (
        <>
          <circle cx={210} cy={195} r={150} fill={V.gold} opacity={0.16 * glow} />
          <circle cx={200} cy={185} r={120} fill={V.gold} opacity={0.22 * glow} />
          <circle cx={225} cy={175} r={90} fill={V.gold} opacity={0.3 * glow} />
          {/* 头发填充 */}
          <path
            d="M200 78 Q262 66 292 122 Q310 172 294 232 Q288 274 268 304 Q252 296 246 258 Q258 200 240 150 Q228 108 200 78 Z"
            fill={V.gold}
            opacity={0.4}
          />
          {/* 腮红 */}
          <circle cx={216} cy={196} r={13} fill={V.gold} opacity={0.5} />
        </>
      )}

      {/* ---------- 轮廓（墨线生长） ---------- */}
      {/* 额头→眉骨→鼻梁→鼻尖→鼻底→唇→下巴→颌线→耳下 */}
      <InkPath
        d="M201 79 Q176 96 173 124 Q172 136 167 146 Q157 162 159 172 Q160 178 170 180 Q166 190 165 199 Q164 208 173 211 Q180 213 180 220 Q181 232 190 241 Q203 253 221 252 Q232 256 240 259"
        frame={frame}
        start={d(0)}
        duration={Math.round(42 * speed)}
        width={6}
        color={ink}
      />
      {/* 下颌→颈→肩 */}
      <InkPath
        d="M240 259 Q236 262 238 274 Q240 290 234 302 Q228 318 206 336 Q186 352 168 362"
        frame={frame}
        start={d(26)}
        duration={Math.round(26 * speed)}
        width={6}
        color={ink}
      />
      <InkPath
        d="M234 300 Q258 316 292 330 Q316 338 334 348"
        frame={frame}
        start={d(34)}
        duration={Math.round(20 * speed)}
        width={6}
        color={ink}
      />
      {/* 后脑勺→后颈 */}
      <InkPath
        d="M201 79 Q238 70 260 96 Q278 118 280 148 Q282 176 274 206 Q268 240 258 268 Q252 288 246 300"
        frame={frame}
        start={d(8)}
        duration={Math.round(30 * speed)}
        width={5}
        color={ink}
        opacity={0.95}
      />

      {/* ---------- 头发（三笔波浪） ---------- */}
      <InkPath
        d="M204 84 Q266 76 288 130 Q302 176 290 224 Q284 262 268 292"
        frame={frame}
        start={d(14)}
        duration={Math.round(30 * speed)}
        width={7}
        color={ink}
      />
      <InkPath
        d="M212 96 Q258 96 276 142 Q288 182 278 226"
        frame={frame}
        start={d(22)}
        duration={Math.round(24 * speed)}
        width={4}
        color={ink}
        opacity={0.75}
      />
      <InkPath
        d="M236 120 Q264 150 262 200 Q260 236 250 264"
        frame={frame}
        start={d(28)}
        duration={Math.round(20 * speed)}
        width={3.5}
        color={ink}
        opacity={0.6}
      />
      {/* 刘海两笔 */}
      <InkPath
        d="M200 86 Q184 102 180 122 Q178 132 181 140"
        frame={frame}
        start={d(18)}
        duration={Math.round(14 * speed)}
        width={5}
        color={ink}
      />
      <InkPath
        d="M212 92 Q200 110 198 128"
        frame={frame}
        start={d(24)}
        duration={Math.round(10 * speed)}
        width={4}
        color={ink}
        opacity={0.8}
      />

      {/* ---------- 眉 / 眼（可眨） / 睫毛 ---------- */}
      <InkPath
        d="M182 132 Q196 124 212 129"
        frame={frame}
        start={d(30)}
        duration={Math.round(10 * speed)}
        width={5}
        color={ink}
      />
      {/* 眼：以 (196,158) 为中心，eyeOpen 控制开合 */}
      <g
        style={{
          transform: `translate(196px, 158px) scaleY(${eyeOpen}) translate(-196px, -158px)`,
        }}
      >
        <InkPath
          d="M182 158 Q192 148 206 155"
          frame={frame}
          start={d(33)}
          duration={Math.round(8 * speed)}
          width={4.5}
          color={ink}
        />
        <InkPath
          d="M184 162 Q193 168 204 163"
          frame={frame}
          start={d(35)}
          duration={Math.round(8 * speed)}
          width={3.5}
          color={ink}
        />
        {colored ? (
          <circle cx={195} cy={158} r={4.5} fill={V.ink} />
        ) : (
          <InkDot cx={195} cy={158} r={4.5} frame={frame} start={d(36)} fps={30} color={ink} />
        )}
      </g>
      {/* 睫毛 */}
      <InkPath
        d="M206 152 Q212 149 217 151"
        frame={frame}
        start={d(37)}
        duration={Math.round(6 * speed)}
        width={3}
        color={ink}
        opacity={0.85}
      />

      {/* ---------- 鼻已含在轮廓 / 唇缝 ---------- */}
      <InkPath
        d="M168 226 Q176 231 186 229"
        frame={frame}
        start={d(38)}
        duration={Math.round(8 * speed)}
        width={4.5}
        color={ink}
      />
      {colored && (
        <path
          d="M167 212 Q176 208 184 213 Q180 222 170 221 Q165 217 167 212 Z"
          fill={V.goldDeep}
          opacity={0.75}
        />
      )}

      {/* ---------- 耳朵 + 耳饰 ---------- */}
      <InkPath
        d="M243 190 Q256 182 258 198 Q259 214 246 216"
        frame={frame}
        start={d(32)}
        duration={Math.round(10 * speed)}
        width={4.5}
        color={ink}
      />
      <InkDot cx={252} cy={226} r={3} frame={frame} start={d(40)} fps={30} color={colored ? V.goldDeep : ink} />

      {/* 锁口小弧（衣领） */}
      <InkPath
        d="M206 336 Q224 348 246 352"
        frame={frame}
        start={d(42)}
        duration={Math.round(12 * speed)}
        width={4}
        color={ink}
        opacity={0.7}
      />
    </svg>
  );
};

/** 悬浮的墨点星尘（金色，点缀用） */
export const InkSparkles: React.FC<{
  frame: number;
  fps: number;
  points: [number, number, number][]; // [x, y, r]
  start: number;
  svgWidth: number;
  svgHeight: number;
}> = ({frame, fps, points, start, svgWidth, svgHeight}) => (
  <svg
    viewBox={`0 0 ${svgWidth} ${svgHeight}`}
    width="100%"
    height="100%"
    style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}
  >
    {points.map(([x, y, r], i) => (
      <InkDot
        key={i}
        cx={x}
        cy={y + Math.sin(frame * 0.06 + i * 1.7) * 6}
        r={r}
        frame={frame}
        start={start + i * 4}
        fps={fps}
        color={V.gold}
      />
    ))}
  </svg>
);
