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
import {Paper, Stamp, StickyCap, InkPath} from '../v2/ink';

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

        {/* ============ 字幕 ============ */}
        <Cap text="脸不好看，怎么出片？" frame={frame} fps={fps} start={34} duration={66} highlight={['脸不好看']} />

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
