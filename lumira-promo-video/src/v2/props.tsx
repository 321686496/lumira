import React from 'react';
import {spring} from 'remotion';
import {V} from './theme';
import {InkPath, InkDot} from './ink';

/* ------------------------------ 挂相机的摄影者 ------------------------------ */
/** 第一人称"我"，viewBox 0 0 400 400，面朝右微笑 */
export const CameraGuy: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%">
      {/* 头 */}
      <InkPath d="M140 110 a48 48 0 1 1 96 0 a48 48 0 1 1 -96 0" frame={frame} start={d(0)} duration={20} width={6} />
      {/* 呆毛 */}
      <InkPath d="M186 64 Q196 46 210 44" frame={frame} start={d(8)} duration={8} width={4.5} />
      {/* 眯眯笑眼 ×2 */}
      <InkPath d="M158 108 Q166 100 174 107" frame={frame} start={d(10)} duration={8} width={4.5} />
      <InkPath d="M196 106 Q204 98 212 105" frame={frame} start={d(12)} duration={8} width={4.5} />
      {/* 笑嘴 */}
      <InkPath d="M172 132 Q184 144 200 130" frame={frame} start={d(14)} duration={8} width={4.5} />
      {/* 腮红 */}
      <InkDot cx={152} cy={126} r={5} frame={frame} start={d(16)} fps={30} color={V.gold} />
      {/* 躯干 */}
      <InkPath d="M152 158 Q138 220 118 300" frame={frame} start={d(18)} duration={16} width={6} />
      <InkPath d="M224 156 Q238 220 256 300" frame={frame} start={d(20)} duration={16} width={6} />
      {/* 相机挂绳 */}
      <InkPath d="M156 164 Q170 210 168 236" frame={frame} start={d(22)} duration={10} width={3.5} dash="0.04 0.03" />
      <InkPath d="M220 162 Q212 208 210 236" frame={frame} start={d(24)} duration={10} width={3.5} dash="0.04 0.03" />
      {/* 相机机身 */}
      <InkPath d="M160 236 h100 a10 10 0 0 1 10 10 v44 a10 10 0 0 1 -10 10 h-100 a10 10 0 0 1 -10 -10 v-44 a10 10 0 0 1 10 -10 Z" frame={frame} start={d(26)} duration={18} width={5.5} />
      {/* 镜头 */}
      <InkPath d="M198 252 a18 18 0 1 1 0 36 a18 18 0 1 1 0 -36" frame={frame} start={d(30)} duration={12} width={5} />
      <InkDot cx={207} cy={261} r={4} frame={frame} start={d(34)} fps={30} color={V.gold} />
      {/* 取景器 */}
      <InkPath d="M162 244 h20" frame={frame} start={d(32)} duration={6} width={4} />
      {/* 手臂托机 */}
      <InkPath d="M148 190 Q152 240 168 252" frame={frame} start={d(34)} duration={12} width={5.5} />
      <InkPath d="M232 188 Q232 238 214 254" frame={frame} start={d(36)} duration={12} width={5.5} />
      {/* 腿脚 */}
      <InkPath d="M160 300 Q156 336 154 362" frame={frame} start={d(38)} duration={12} width={6} />
      <InkPath d="M212 300 Q220 336 224 362" frame={frame} start={d(40)} duration={12} width={6} />
      <InkPath d="M154 362 q-14 4 -16 10 M224 362 q16 2 20 8" frame={frame} start={d(42)} duration={8} width={5} />
    </svg>
  );
};

/* ------------------------------- 拍立得废片框 ------------------------------- */
/** Polaroid 相框，children 为内部 300x260 的简笔内容 */
export const Polaroid: React.FC<{
  frame: number;
  start: number;
  fps: number;
  rotate?: number;
  children?: React.ReactNode;
}> = ({frame, start, fps, rotate = 0, children}) => {
  const s = spring({frame: Math.max(0, frame - start), fps, config: {damping: 13, stiffness: 150}});
  return (
    <div
      style={{
        width: 340,
        height: 400,
        background: V.white,
        border: `4px solid ${V.ink}`,
        borderRadius: 10,
        boxShadow: '10px 12px 0 rgba(26,26,26,0.12)',
        transform: `rotate(${rotate}deg) scale(${s}) translateY(${(1 - s) * 60}px)`,
        opacity: s,
        padding: '22px 22px 0',
      }}
    >
      <div
        style={{
          width: '100%',
          height: 300,
          border: `3px solid ${V.ink}`,
          borderRadius: 6,
          overflow: 'hidden',
          background: V.paper,
          position: 'relative',
        }}
      >
        {children}
      </div>
      <div style={{height: 76, display: 'flex', alignItems: 'center', paddingLeft: 10}}>
        <svg width={60} height={40} viewBox="0 0 60 40">
          <InkPath d="M6 34 Q18 8 30 22 Q40 32 52 10" frame={frame} start={start + 14} duration={12} width={3.5} color={V.gray} />
        </svg>
      </div>
    </div>
  );
};

/** 废片1：闭眼瞬间 */
export const ShotClosedEyes: React.FC<{frame: number; start: number}> = ({frame, start}) => (
  <svg viewBox="0 0 300 260" width="100%" height="100%">
    <InkPath d="M150 60 a42 42 0 1 1 0 84 a42 42 0 1 1 0 -84" frame={frame} start={start} duration={14} width={4.5} />
    <InkPath d="M126 96 q8 6 16 0 M158 96 q8 6 16 0" frame={frame} start={start + 6} duration={8} width={4} />
    <InkPath d="M136 122 q14 8 28 0" frame={frame} start={start + 8} duration={6} width={4} />
    <InkPath d="M150 144 q0 40 -14 66 M186 130 q22 40 26 84" frame={frame} start={start + 10} duration={12} width={4} />
    <InkPath d="M120 200 q30 -18 62 -6" frame={frame} start={start + 12} duration={8} width={4} />
    {/* Zzz */}
    <InkPath d="M212 70 h26 l-26 22 h26" frame={frame} start={start + 14} duration={10} width={4} color={V.gray} />
  </svg>
);

/** 废片2：歪构图（水平线歪斜，人被切头） */
export const ShotTilted: React.FC<{frame: number; start: number}> = ({frame, start}) => (
  <svg viewBox="0 0 300 260" width="100%" height="100%">
    {/* 歪的水平线 */}
    <InkPath d="M14 150 L286 108" frame={frame} start={start} duration={14} width={4} color={V.gray} dash="0.06 0.04" />
    {/* 人被切掉一半头 */}
    <InkPath d="M120 260 q0 -70 24 -88 q22 -14 44 0 q24 20 24 88" frame={frame} start={start + 4} duration={16} width={4.5} />
    <InkPath d="M138 214 q8 -10 18 -2 M176 210 q9 -8 17 0" frame={frame} start={start + 10} duration={8} width={3.5} />
    {/* 裁切警示角 */}
    <InkPath d="M40 40 h26 M40 40 v26 M260 220 h-26 M260 220 v-26" frame={frame} start={start + 14} duration={10} width={4.5} color={V.goldDeep} />
  </svg>
);

/** 废片3：表情僵硬（笔直站立 + 汗滴） */
export const ShotStiff: React.FC<{frame: number; start: number}> = ({frame, start}) => (
  <svg viewBox="0 0 300 260" width="100%" height="100%">
    {/* 笔直如尺的身体 */}
    <InkPath d="M150 78 v112" frame={frame} start={start} duration={10} width={4.5} />
    <InkPath d="M150 78 a20 20 0 1 1 0.1 0" frame={frame} start={start + 4} duration={10} width={4.5} />
    {/* 僵硬的方嘴 + 点点眼 */}
    <InkPath d="M138 118 h24" frame={frame} start={start + 8} duration={6} width={4} />
    <InkDot cx={140} cy={100} r={3.5} frame={frame} start={start + 8} fps={30} />
    <InkDot cx={160} cy={100} r={3.5} frame={frame} start={start + 9} fps={30} />
    {/* 手臂紧贴 */}
    <InkPath d="M150 96 q-20 40 -22 78 M150 96 q20 40 22 78" frame={frame} start={start + 10} duration={10} width={4} />
    <InkPath d="M150 190 l-16 54 M150 190 l16 54" frame={frame} start={start + 12} duration={10} width={4.5} />
    {/* 汗滴 */}
    <InkPath d="M196 74 q8 12 0 18 q-8 -6 0 -18" frame={frame} start={start + 14} duration={8} width={3.5} color={V.goldDeep} />
    <InkPath d="M102 84 q7 10 0 16 q-7 -6 0 -16" frame={frame} start={start + 16} duration={8} width={3.5} color={V.goldDeep} />
  </svg>
);

/* -------------------------------- 翻开的相册 -------------------------------- */
export const OldAlbum: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  return (
    <svg viewBox="0 0 400 300" width="100%" height="100%">
      {/* 左右两页 */}
      <InkPath d="M200 70 Q140 48 66 60 L66 250 Q140 238 200 258 Z" frame={frame} start={d(0)} duration={20} width={5.5} />
      <InkPath d="M200 70 Q260 48 334 60 L334 250 Q260 238 200 258 Z" frame={frame} start={d(6)} duration={20} width={5.5} />
      {/* 中缝 */}
      <InkPath d="M200 70 V258" frame={frame} start={d(2)} duration={8} width={4} />
      {/* 左页照片：山与日 */}
      <InkPath d="M96 100 h80 v66 h-80 Z" frame={frame} start={d(10)} duration={12} width={4} />
      <InkPath d="M100 158 l26 -30 l18 20 l14 -16 l18 26" frame={frame} start={d(14)} duration={12} width={3.5} />
      <InkDot cx={160} cy={116} r={6} frame={frame} start={d(16)} fps={30} color={V.gold} />
      {/* 右页手写字 */}
      <InkPath d="M236 110 h72 M236 132 h72 M236 154 h48" frame={frame} start={d(14)} duration={12} width={3.5} color={V.gray} />
      {/* 右页照片角 */}
      <InkPath d="M250 190 l40 -8 l8 42 l-40 8 Z" frame={frame} start={d(18)} duration={10} width={4} />
      {/* 书签丝带 */}
      <InkPath d="M200 258 q-8 22 4 34" frame={frame} start={d(22)} duration={8} width={4} color={V.goldDeep} />
    </svg>
  );
};

/* ------------------------------ 1839 木箱相机 ------------------------------ */
export const Camera1839: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%">
      {/* 木箱 */}
      <InkPath d="M104 190 L296 190 L296 330 L104 330 Z" frame={frame} start={d(0)} duration={20} width={6} />
      {/* 木纹 */}
      <InkPath d="M118 224 h164 M118 258 h164 M118 292 h164" frame={frame} start={d(8)} duration={14} width={3} color={V.gray} opacity={0.7} />
      {/* 铆钉 */}
      <InkDot cx={122} cy={204} r={4} frame={frame} start={d(12)} fps={30} />
      <InkDot cx={278} cy={204} r={4} frame={frame} start={d(13)} fps={30} />
      {/* 顶部镜头管 */}
      <InkPath d="M176 132 h48 v58 h-48 Z" frame={frame} start={d(14)} duration={12} width={5.5} />
      <InkPath d="M168 122 h64 v12 h-64 Z" frame={frame} start={d(18)} duration={8} width={5} />
      {/* 镜头前端圆 */}
      <InkPath d="M178 190 a22 22 0 1 1 44 0" frame={frame} start={d(20)} duration={10} width={5} />
      <InkDot cx={200} cy={196} r={5} frame={frame} start={d(24)} fps={30} color={V.gold} />
      {/* 三脚架腿 */}
      <InkPath d="M140 330 L118 386 M260 330 L282 386 M200 330 V384" frame={frame} start={d(24)} duration={14} width={5.5} />
      {/* 黑布（摄影师罩布） */}
      <InkPath d="M104 190 Q64 150 40 210 Q30 260 56 300 Q80 330 104 330" frame={frame} start={d(28)} duration={16} width={5} />
      <InkPath d="M52 210 q-6 40 12 84" frame={frame} start={d(34)} duration={10} width={3.5} color={V.gray} opacity={0.7} />
    </svg>
  );
};

/* ------------------------------ 1900 盒式相机 ------------------------------ */
export const Camera1900: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%">
      {/* 盒身 */}
      <InkPath d="M126 156 h148 a12 12 0 0 1 12 12 v130 a12 12 0 0 1 -12 12 h-148 a12 12 0 0 1 -12 -12 v-130 a12 12 0 0 1 12 -12 Z" frame={frame} start={d(0)} duration={20} width={6} />
      {/* 顶部提带 */}
      <InkPath d="M162 156 q38 -44 76 0" frame={frame} start={d(8)} duration={12} width={5} />
      <InkDot cx={200} cy={118} r={5} frame={frame} start={d(14)} fps={30} />
      {/* 前镜头 */}
      <InkPath d="M172 216 a28 28 0 1 1 56 0 a28 28 0 1 1 -56 0" frame={frame} start={d(12)} duration={14} width={5.5} />
      <InkPath d="M182 216 a18 18 0 1 1 36 0 a18 18 0 1 1 -36 0" frame={frame} start={d(16)} duration={10} width={4.5} />
      <InkDot cx={194} cy={210} r={4.5} frame={frame} start={d(20)} fps={30} color={V.gold} />
      {/* V 形取景窗 */}
      <InkPath d="M238 186 l16 14 l-16 14" frame={frame} start={d(20)} duration={8} width={4} />
      {/* 快门钮 */}
      <InkDot cx={132} cy={176} r={6} frame={frame} start={d(22)} fps={30} />
      {/* 「你只管按」箭头指向快门 */}
      <InkPath d="M92 128 Q108 152 124 168" frame={frame} start={d(24)} duration={10} width={4} dash="0.05 0.04" color={V.goldDeep} />
    </svg>
  );
};

/* ------------------------------ 1950s 时尚摄影 ----------------------------- */
export const Fashion1950: React.FC<{frame: number; start?: number; speed?: number}> = ({
  frame,
  start = 0,
  speed = 1,
}) => {
  const d = (n: number) => start + n * speed;
  return (
    <svg viewBox="0 0 400 400" width="100%" height="100%">
      {/* 反光伞 */}
      <InkPath d="M212 96 Q132 116 108 196 Q160 172 212 96 Q264 172 316 196 Q292 116 212 96 Z" frame={frame} start={d(0)} duration={22} width={5.5} />
      {/* 伞骨 */}
      <InkPath d="M212 96 L138 176 M212 96 L212 186 M212 96 L286 176" frame={frame} start={d(10)} duration={12} width={3.5} color={V.gray} opacity={0.8} />
      {/* 灯泡（金） */}
      <InkDot cx={212} cy={120} r={16} frame={frame} start={d(12)} fps={30} color={V.gold} />
      {/* 支架 */}
      <InkPath d="M212 196 V336 M188 336 h48 M196 386 q16 -30 32 0" frame={frame} start={d(16)} duration={14} width={5} />
      {/* 相机（左下） */}
      <InkPath d="M84 280 h96 a10 10 0 0 1 10 10 v54 a10 10 0 0 1 -10 10 h-96 a10 10 0 0 1 -10 -10 v-54 a10 10 0 0 1 10 -10 Z" frame={frame} start={d(20)} duration={16} width={5.5} />
      <InkPath d="M110 308 a22 22 0 1 1 44 0 a22 22 0 1 1 -44 0" frame={frame} start={d(26)} duration={12} width={5} />
      <InkDot cx={122} cy={300} r={4.5} frame={frame} start={d(30)} fps={30} color={V.gold} />
      {/* 快门线 */}
      <InkPath d="M120 348 Q150 380 190 372" frame={frame} start={d(30)} duration={12} width={3.5} color={V.gray} dash="0.05 0.04" />
      {/* 闪光 */}
      <InkPath d="M352 120 l-20 18 M352 120 l4 26 M352 120 l-26 6" frame={frame} start={d(32)} duration={10} width={4} color={V.goldDeep} />
    </svg>
  );
};
