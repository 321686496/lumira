import React from 'react';
import {interpolate} from 'remotion';
import {V} from './theme';
import {InkPath, InkDot} from './ink';

/* --------------------------------- 光：灯照侧脸 -------------------------------- */
export const LightIllust: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  // 灯光呼吸
  const glow = interpolate(Math.sin(frame * 0.08), [-1, 1], [0.55, 1]);
  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%">
      {/* 吊灯 */}
      <InkPath d="M200 20 V64" frame={frame} start={d(0)} duration={8} width={4.5} />
      <InkPath d="M142 96 Q142 64 200 64 Q258 64 258 96 Z" frame={frame} start={d(2)} duration={12} width={5.5} />
      <circle cx={200} cy={112} r={20 + glow * 5} fill={V.gold} opacity={0.25 + glow * 0.3} />
      <InkDot cx={200} cy={112} r={13} frame={frame} start={d(8)} fps={30} color={V.gold} />
      {/* 光线放射 */}
      <InkPath d="M164 140 L148 164 M200 150 V178 M236 140 L252 164" frame={frame} start={d(10)} duration={10} width={4} color={V.goldDeep} dash="0.05 0.03" />
      {/* 下方侧脸简笔（受光面） */}
      <InkPath d="M188 208 Q172 220 170 240 Q169 250 165 257 Q160 264 165 268 Q162 275 166 280 Q170 290 178 296 Q190 304 204 302" frame={frame} start={d(14)} duration={22} width={5.5} />
      <InkPath d="M188 208 Q212 202 224 222 Q232 240 228 262 Q224 284 212 298 Q204 304 204 302" frame={frame} start={d(18)} duration={18} width={4.5} opacity={0.85} />
      <InkPath d="M182 244 q7 -6 14 -2" frame={frame} start={d(24)} duration={8} width={4} />
      <g style={{transform: `translate(190px, 252px) scaleY(${glow}) translate(-190px, -252px)`}}>
        <InkPath d="M184 252 q6 -5 12 0" frame={frame} start={d(26)} duration={8} width={3.5} />
      </g>
      <InkPath d="M178 276 q8 6 16 2" frame={frame} start={d(28)} duration={8} width={4} />
      {/* 受光侧金弧 */}
      <InkPath d="M236 220 Q248 254 240 284" frame={frame} start={d(30)} duration={12} width={5} color={V.gold} opacity={0.5 + glow * 0.4} />
      {/* 影子侧排线 */}
      <InkPath d="M160 226 l-12 8 M158 244 l-14 8 M160 262 l-14 8 M166 280 l-12 8" frame={frame} start={d(32)} duration={12} width={3} color={V.gray} opacity={0.7} />
      {/* 肩 */}
      <InkPath d="M212 302 Q196 318 168 326 M212 302 Q238 314 260 320" frame={frame} start={d(34)} duration={12} width={4.5} />
    </svg>
  );
};

/* -------------------------------- 构：三分取景框 ------------------------------- */
export const GridIllust: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%">
      {/* 取景框 */}
      <InkPath d="M70 100 h260 a14 14 0 0 1 14 14 v180 a14 14 0 0 1 -14 14 h-260 a14 14 0 0 1 -14 -14 v-180 a14 14 0 0 1 14 -14 Z" frame={frame} start={d(0)} duration={24} width={6} />
      {/* 三分线（虚线生长） */}
      <InkPath d="M129 100 V308" frame={frame} start={d(8)} duration={16} width={3.5} color={V.gray} dash="0.04 0.03" />
      <InkPath d="M283 100 V308" frame={frame} start={d(10)} duration={16} width={3.5} color={V.gray} dash="0.04 0.03" />
      <InkPath d="M56 169 H344" frame={frame} start={d(12)} duration={16} width={3.5} color={V.gray} dash="0.04 0.03" />
      <InkPath d="M56 239 H344" frame={frame} start={d(14)} duration={16} width={3.5} color={V.gray} dash="0.04 0.03" />
      {/* 右下落点金圈脉动 */}
      <g style={{transformOrigin: '283px 239px', transform: `scale(${1 + Math.sin(frame * 0.09) * 0.12})`}}>
        <circle cx={283} cy={239} r={22} fill={V.gold} opacity={0.22} />
        <InkPath d="M272 239 a11 11 0 1 1 22 0 a11 11 0 1 1 -22 0" frame={frame} start={d(18)} duration={10} width={4.5} color={V.goldDeep} />
      </g>
      {/* 框内简笔人（落在三分点） */}
      <InkPath d="M272 226 a9 9 0 1 1 22 0 a9 9 0 1 1 -22 0" frame={frame} start={d(20)} duration={10} width={4} />
      <InkPath d="M283 235 q-2 26 0 42 M283 252 l-18 20 M283 252 l18 18" frame={frame} start={d(22)} duration={12} width={4} />
      {/* 框外地平线 */}
      <InkPath d="M40 340 Q200 328 360 340" frame={frame} start={d(26)} duration={12} width={3.5} color={V.gray} opacity={0.7} />
    </svg>
  );
};

/* -------------------------------- 情：大笑脸 ---------------------------------- */
export const EmotionIllust: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  const pulse = 1 + Math.sin(frame * 0.07) * 0.04;
  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%" style={{transform: `scale(${pulse})`}}>
      {/* 脸 */}
      <InkPath d="M136 180 a64 64 0 1 1 128 0 a64 64 0 1 1 -128 0" frame={frame} start={d(0)} duration={22} width={6} />
      {/* 弯弯笑眼 */}
      <InkPath d="M158 168 q10 -12 22 0 M220 168 q10 -12 22 0" frame={frame} start={d(8)} duration={10} width={5} />
      {/* 大笑嘴 */}
      <InkPath d="M164 202 q36 40 72 0 q-36 18 -72 0 Z" frame={frame} start={d(12)} duration={14} width={5} />
      {/* 腮红金点 */}
      <InkDot cx={148} cy={196} r={9} frame={frame} start={d(16)} fps={30} color={V.gold} />
      <InkDot cx={252} cy={196} r={9} frame={frame} start={d(17)} fps={30} color={V.gold} />
      {/* 周围情绪放射线 */}
      <InkPath d="M200 96 v-26 M120 118 l-18 -18 M280 118 l18 -18 M96 180 h-26 M304 180 h26" frame={frame} start={d(20)} duration={14} width={4.5} color={V.goldDeep} />
      {/* 心形一颗（金） */}
      <InkPath
        d="M312 118 c-8 -14 -30 -8 -26 10 c3 12 16 18 26 26 c10 -8 23 -14 26 -26 c4 -18 -18 -24 -26 -10 Z"
        frame={frame}
        start={d(26)}
        duration={14}
        width={4.5}
        color={V.goldDeep}
      />
    </svg>
  );
};

/* ------------------------------ 抱书的迷糊小人 ------------------------------- */
export const BookGuy: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  const wob = Math.sin(frame * 0.06) * 3;
  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%" style={{transform: `translateY(${wob}px)`}}>
      {/* 头 */}
      <InkPath d="M152 96 a44 44 0 1 1 88 0 a44 44 0 1 1 -88 0" frame={frame} start={d(0)} duration={18} width={5.5} />
      {/* 蚊香眼 */}
      <InkPath d="M172 92 a7 7 0 1 1 6 8" frame={frame} start={d(6)} duration={8} width={3.5} />
      <InkPath d="M212 90 a7 7 0 1 1 6 8" frame={frame} start={d(7)} duration={8} width={3.5} />
      {/* 波浪嘴 */}
      <InkPath d="M180 118 q8 6 16 0 q8 6 16 0" frame={frame} start={d(8)} duration={8} width={4} />
      {/* 厚书 */}
      <InkPath d="M132 208 h136 a10 10 0 0 1 10 10 v54 a10 10 0 0 1 -10 10 h-136 a10 10 0 0 1 -10 -10 v-54 a10 10 0 0 1 10 -10 Z" frame={frame} start={d(10)} duration={18} width={5.5} />
      <InkPath d="M200 208 v74" frame={frame} start={d(14)} duration={8} width={4} />
      <InkPath d="M146 228 h40 M146 244 h40 M216 228 h40 M216 244 h40" frame={frame} start={d(16)} duration={10} width={3.5} color={V.gray} />
      {/* 书名「摄影大全」 */}
      <InkPath d="M168 190 h64" frame={frame} start={d(18)} duration={8} width={4} color={V.goldDeep} />
      {/* 抱书的手 */}
      <InkPath d="M148 172 Q136 200 134 236 M252 170 Q264 200 266 236" frame={frame} start={d(20)} duration={12} width={5} />
      {/* 腿 */}
      <InkPath d="M172 282 q-4 44 -8 66 M228 282 q6 44 10 66" frame={frame} start={d(22)} duration={12} width={5.5} />
      {/* 头顶问号 ×3（金，错落浮动） */}
      {[0, 1, 2].map((i) => (
        <text
          key={i}
          x={190 + i * 34}
          y={70 - i * 18}
          fontSize={i === 1 ? 44 : 34}
          fontWeight={900}
          fill={V.goldDeep}
          opacity={0.55 + i * 0.15}
          style={{transform: `translateY(${Math.sin(frame * 0.09 + i * 2) * 5}px)`}}
        >
          ?
        </text>
      ))}
    </svg>
  );
};

/* ----------------------------- 键盘长出相机 ------------------------------ */
export const KeyboardCam: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%">
      {/* 键盘（斜放） */}
      <InkPath d="M84 300 L316 300 L348 368 L52 368 Z" frame={frame} start={d(0)} duration={20} width={5.5} />
      {/* 键位网格 */}
      {[0, 1, 2].map((row) =>
        [0, 1, 2, 3, 4, 5, 6, 7].map((col) => {
          const x = 100 + col * 25 + row * 3;
          const y = 314 + row * 15;
          return (
            <InkDot
              key={`${row}-${col}`}
              cx={x}
              cy={y}
              r={3}
              frame={frame}
              start={d(6 + row * 2 + col * 0.6)}
              fps={30}
              color={V.gray}
            />
          );
        }),
      )}
      {/* 空格键 */}
      <InkPath d="M160 352 h80" frame={frame} start={d(12)} duration={6} width={4} color={V.gray} />
      {/* 连接虚线（键盘→相机） */}
      <InkPath d="M200 296 Q200 240 200 212" frame={frame} start={d(14)} duration={14} width={4} dash="0.05 0.04" color={V.goldDeep} />
      {/* 相机从键盘升起 */}
      <InkPath d="M136 140 h128 a12 12 0 0 1 12 12 v56 a12 12 0 0 1 -12 12 h-128 a12 12 0 0 1 -12 -12 v-56 a12 12 0 0 1 12 -12 Z" frame={frame} start={d(16)} duration={20} width={5.5} />
      <InkPath d="M172 140 l10 -18 h36 l10 18" frame={frame} start={d(20)} duration={10} width={5} />
      <InkPath d="M172 172 a28 28 0 1 1 56 0 a28 28 0 1 1 -56 0" frame={frame} start={d(22)} duration={14} width={5} />
      <InkPath d="M184 172 a16 16 0 1 1 32 0 a16 16 0 1 1 -32 0" frame={frame} start={d(26)} duration={10} width={4.5} />
      <InkDot cx={192} cy={166} r={4.5} frame={frame} start={d(28)} fps={30} color={V.gold} />
      <InkPath d="M244 156 h18" frame={frame} start={d(28)} duration={6} width={4} />
      {/* 代码雨（金色字符点缀） */}
      {['{', '}', '01', '</>', ';'].map((s, i) => (
        <text
          key={i}
          x={60 + i * 72}
          y={104 - (i % 2) * 26}
          fontSize={26}
          fontFamily="monospace"
          fontWeight={700}
          fill={V.goldDeep}
          opacity={0.7}
          style={{transform: `translateY(${Math.sin(frame * 0.08 + i * 1.4) * 6}px)`}}
        >
          {s}
        </text>
      ))}
      {/* 火花 */}
      <InkPath d="M330 96 l6 16 M352 120 l-16 6 M70 76 l-6 16 M48 100 l16 6" frame={frame} start={d(30)} duration={12} width={4} color={V.goldDeep} />
    </svg>
  );
};
