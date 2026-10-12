import React from 'react';
import {AbsoluteFill, Img, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {V, FONT2, goldInk} from '../v2/theme';
import {Paper, Stamp} from '../v2/ink';

/** 封面小拍立得（300 宽）：轻弹入 */
const CoverPolaroid: React.FC<{
  frame: number;
  fps: number;
  start: number;
  img: string;
  rotate: number;
}> = ({frame, fps, start, img, rotate}) => {
  const s = spring({frame: Math.max(0, frame - start), fps, config: {damping: 13, stiffness: 150}});
  const pad = 16;
  const photo = 300 - pad * 2;
  return (
    <div
      style={{
        width: 300,
        background: V.white,
        border: `4px solid ${V.ink}`,
        borderRadius: 10,
        boxShadow: '9px 11px 0 rgba(26,26,26,0.12)',
        padding: `${pad}px ${pad}px 0`,
        transform: `rotate(${rotate}deg) scale(${s}) translateY(${(1 - s) * 40}px)`,
        opacity: s,
      }}
    >
      <div
        style={{
          width: photo,
          height: photo,
          border: `3px solid ${V.ink}`,
          borderRadius: 6,
          overflow: 'hidden',
          background: V.paper,
        }}
      >
        <Img src={staticFile(img)} style={{width: '100%', height: '100%', objectFit: 'cover'}} />
      </div>
      <div style={{height: 34}} />
    </div>
  );
};

/** 小红书封面（1080×1440，静帧设计）：氛围感三招 三联图 */
export const AtmoCover: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t1 = spring({frame: Math.max(0, frame - 0), fps, config: {damping: 12, stiffness: 170}});
  const t2 = spring({frame: Math.max(0, frame - 5), fps, config: {damping: 12, stiffness: 170}});
  const foot = spring({frame: Math.max(0, frame - 20), fps, config: {damping: 200}});
  const tips = [
    {img: 'atmo/tip-hide.jpg', label: '藏', rotate: -4, start: 6},
    {img: 'atmo/tip-light.jpg', label: '光', rotate: 2, start: 9},
    {img: 'atmo/tip-far.jpg', label: '远', rotate: -2, start: 12},
  ];
  return (
    <AbsoluteFill style={{backgroundColor: V.paper, fontFamily: FONT2}}>
      <Paper>
        {/* 标题两行 */}
        <div style={{position: 'absolute', left: 0, right: 0, top: 90, textAlign: 'center', lineHeight: 1.12}}>
          <div
            style={{
              ...goldInk,
              fontSize: 150,
              fontWeight: 900,
              letterSpacing: 10,
              opacity: t1,
              transform: `scale(${t1})`,
            }}
          >
            氛围感
          </div>
          <div
            style={{
              ...goldInk,
              fontSize: 190,
              fontWeight: 900,
              letterSpacing: 14,
              opacity: t2,
              transform: `scale(${t2})`,
            }}
          >
            三招
          </div>
        </div>
        {/* 三联拍立得 + 金章 */}
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: 545,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'flex-start',
            gap: 28,
          }}
        >
          {tips.map((t, i) => (
            <div key={t.label} style={{display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
              <CoverPolaroid frame={frame} fps={fps} start={t.start} img={t.img} rotate={t.rotate} />
              <div style={{marginTop: 18}}>
                <Stamp text={t.label} frame={frame} fps={fps} start={t.start + 8} size={80} color={V.goldDeep} rotate={i === 1 ? 3 : -3} />
              </div>
            </div>
          ))}
        </div>
        {/* 底部钩子小字 */}
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: 1075,
            textAlign: 'center',
            fontSize: 44,
            fontWeight: 700,
            color: V.inkSoft,
            letterSpacing: 8,
            opacity: foot,
            transform: `translateY(${(1 - foot) * 14}px)`,
          }}
        >
          脸不好看怎么出片
        </div>
      </Paper>
    </AbsoluteFill>
  );
};
