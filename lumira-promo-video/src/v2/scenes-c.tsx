import React from 'react';
import {AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {V} from './theme';
import {Paper, StickyCap, Stamp, breathe, DrawOnImage} from './ink';
import {BookGuy, KeyboardCam} from './elements';
import {CameraGuy} from './props';
import {InkSparkles} from './portrait';

/* ========================== S5 鸿沟（270帧 = 9s） ========================== */
export const V2GapScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  // 满屏术语飞过
  const terms = ['光圈 f/1.8', '快门 1/250s', 'ISO 400', '色温 5600K', '三分法', '黄金分割', '伦勃朗光', '对角线构图'];
  return (
    <AbsoluteFill>
      <Paper>
        {/* 术语雨 */}
        {terms.map((t, i) => {
          const y0 = 140 + (i % 4) * 190;
          const x0 = 90 + (i % 3) * 640 + (i > 5 ? 120 : 0);
          const s = spring({frame: Math.max(0, frame - 20 - i * 12), fps, config: {damping: 200}});
          return (
            <div
              key={i}
              style={{
                position: 'absolute',
                left: x0,
                top: y0,
                transform: `translateY(${(1 - s) * -60}px) rotate(${(i % 2 === 0 ? -1 : 1) * (2 + i)}deg)`,
                opacity: s * 0.55,
                fontSize: 38,
                fontWeight: 700,
                color: V.inkSoft,
                border: `2.5px solid ${V.gray}`,
                borderRadius: 999,
                padding: '8px 26px',
                background: V.white,
              }}
            >
              {t}
            </div>
          );
        })}
        {/* 抱书小人 */}
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: 390,
            width: 440,
            height: 440,
            transform: 'translateX(-50%)',
          }}
        >
          <BookGuy frame={frame} start={70} speed={0.8} />
        </div>
        <div style={{position: 'absolute', left: '50%', top: 780, transform: 'translateX(-50%)'}}>
          <Stamp text="道理都懂，一拍还是废" frame={frame} fps={fps} start={120} size={66} color={V.ink} />
        </div>
        <StickyCap text="真到按快门那一刻：参数、位置、表情……根本顾不过来" frame={frame} fps={fps} start={20} duration={105} highlight={['顾不过来']} />
        <StickyCap text="直到我烦了：这些凭什么不能提前替我算好？" frame={frame} fps={fps} start={140} duration={128} rotate={1} highlight={['提前替我算好']} />
      </Paper>
    </AbsoluteFill>
  );
};

/* ========================== S6 造模板（360帧 = 12s） ========================== */
export const V2MakeScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const codeLines = [
    {t: 'template = {', at: 60},
    {t: '  pose:  ["手插兜", "侧身回眸"],   // 情绪', at: 84},
    {t: '  grid:  "三分线·右下落点",      // 构图', at: 104},
    {t: '  light: "EV-0.3 · 暖调 4800K",   // 光线', at: 124},
    {t: '}', at: 144},
  ];
  return (
    <AbsoluteFill>
      <Paper>
        {/* 左：键盘长出相机 */}
        <div
          style={{
            position: 'absolute',
            left: 120,
            top: 260,
            width: 560,
            height: 560,
            transform: `translateY(${breathe(frame, 6, 0.03)}px)`,
          }}
        >
          <KeyboardCam frame={frame} start={10} speed={0.8} />
        </div>
        {/* 右：代码卡片（打字机逐行） */}
        <div
          style={{
            position: 'absolute',
            right: 140,
            top: 230,
            width: 820,
            background: V.white,
            border: `4px solid ${V.ink}`,
            borderRadius: 18,
            boxShadow: '12px 14px 0 rgba(26,26,26,0.12)',
            transform: `rotate(1.2deg) translateY(${breathe(frame, 5, 0.028, 40)}px)`,
            padding: '38px 48px',
            opacity: interpolate(frame, [40, 56], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}),
          }}
        >
          <div style={{display: 'flex', gap: 12, marginBottom: 22}}>
            {[0, 1, 2].map((i) => (
              <span key={i} style={{width: 18, height: 18, borderRadius: 9, border: `3px solid ${V.ink}`}} />
            ))}
            <span style={{marginLeft: 14, color: V.gray, fontSize: 26, fontWeight: 700}}>template.ts</span>
          </div>
          {codeLines.map((l, i) => {
            const s = spring({frame: Math.max(0, frame - l.at), fps, config: {damping: 200}});
            const chars = Math.round(interpolate(s, [0, 1], [0, l.t.length]));
            return (
              <div
                key={i}
                style={{
                  fontFamily: 'Consolas, monospace',
                  fontSize: 38,
                  lineHeight: 1.65,
                  color: V.ink,
                  whiteSpace: 'pre',
                  fontWeight: 600,
                }}
              >
                <span style={{color: l.t.includes('//') ? V.goldDeep : V.ink}}>
                  {l.t.slice(0, chars)}
                </span>
                {s > 0 && s < 1 && (
                  <span style={{display: 'inline-block', width: 3, height: 36, background: V.gold, marginLeft: 2}} />
                )}
              </div>
            );
          })}
        </div>
        <div style={{position: 'absolute', left: '50%', top: 60, transform: 'translateX(-50%)'}}>
          <Stamp text="把方法做成模板，装进手机" frame={frame} fps={fps} start={170} size={72} color={V.goldDeep} />
        </div>
        <StickyCap text="于是，我把这三件事，一条条写进了模板" frame={frame} fps={fps} start={30} duration={145} highlight={['写进了模板']} />
        <StickyCap text="姿势怎么摆、人站哪里、参数怎么调——全替你写好" frame={frame} fps={fps} start={190} duration={168} rotate={1} highlight={['全替你写好']} />
      </Paper>
    </AbsoluteFill>
  );
};

/* ========================== S7 一遍过（330帧 = 11s） ========================== */
export const V2RevealScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return (
    <AbsoluteFill>
      <Paper>
        {/* 左：线稿（生图素材，快速手绘入场） */}
        <div style={{position: 'absolute', left: 170, top: 180, width: 620, height: 620}}>
          <div style={{position: 'absolute', inset: 0, opacity: interpolate(frame, [0, 12], [0, 1], {extrapolateRight: 'clamp'})}}>
            <DrawOnImage
              src="v2/girl-line.png"
              frame={frame}
              start={0}
              duration={34}
              width={620}
              height={620}
            />
          </div>
          <Stamp text="线稿" frame={frame} fps={fps} start={40} size={54} color={V.gray} rotate={-6} />
        </div>
        {/* 中间箭头 */}
        <svg width={200} height={120} viewBox="0 0 200 120" style={{position: 'absolute', left: 860, top: 430}}>
          <path
            d="M10 60 H150 M150 60 l-30 -22 M150 60 l-30 22"
            fill="none"
            stroke={V.goldDeep}
            strokeWidth={8}
            strokeLinecap="round"
            pathLength={1}
            strokeDasharray={1}
            strokeDashoffset={interpolate(frame, [130, 165], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}
          />
        </svg>
        {/* 右：上色成片（生图素材，显影式自上而下揭开） */}
        <div style={{position: 'absolute', left: 1110, top: 180, width: 620, height: 620}}>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              clipPath: `inset(0 0 ${interpolate(frame, [160, 205], [100, 0], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              })}% 0)`,
            }}
          >
            <Img
              src={staticFile('v2/girl-gold.png')}
              style={{
                width: '100%',
                height: '100%',
                objectFit: 'contain',
                mixBlendMode: 'multiply',
              }}
            />
          </div>
          <InkSparkles
            frame={frame}
            fps={fps}
            start={190}
            svgWidth={620}
            svgHeight={620}
            points={[[90, 110, 7], [520, 90, 6], [560, 420, 6], [80, 480, 5], [300, 60, 5]]}
          />
          <Stamp text="一遍过" frame={frame} fps={fps} start={205} size={54} color={V.goldDeep} rotate={-5} />
        </div>
        <StickyCap text="打开模板：她该站在哪、往哪看、什么情绪，取景框里直接标好" frame={frame} fps={fps} start={30} duration={155} highlight={['直接标好']} />
        <StickyCap text="我要做的，只剩按下快门" frame={frame} fps={fps} start={200} duration={128} rotate={1} highlight={['按下快门']} />
      </Paper>
    </AbsoluteFill>
  );
};

/* ========================== S8 署名（300帧 = 10s） ========================== */
export const V2EndScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return (
    <AbsoluteFill>
      <Paper>
        {/* 中间：上色少女（生图素材） */}
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: '46%',
            width: 640,
            height: 640,
            transform: `translate(-50%,-50%) translateY(${breathe(frame, 7)}px) scale(${interpolate(frame, [0, 30], [0.86, 1], {extrapolateRight: 'clamp'})})`,
            opacity: interpolate(frame, [0, 24], [0, 1], {extrapolateRight: 'clamp'}),
          }}
        >
          <Img
            src={staticFile('v2/girl-gold.png')}
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'contain',
              mixBlendMode: 'multiply',
            }}
          />
        </div>
        <InkSparkles
          frame={frame}
          fps={fps}
          start={60}
          svgWidth={1920}
          svgHeight={1080}
          points={[[480, 260, 6], [1440, 240, 7], [1560, 640, 5], [400, 700, 6], [960, 180, 5]]}
        />
        {/* 藏书票式落款 */}
        <div
          style={{
            position: 'absolute',
            right: 170,
            bottom: 150,
            border: `5px solid ${V.goldDeep}`,
            borderRadius: 16,
            padding: '26px 44px 30px',
            transform: 'rotate(2deg)',
            background: V.white,
            boxShadow: '10px 12px 0 rgba(26,26,26,0.1)',
          }}
        >
          <div
            style={{
              fontSize: 84,
              fontWeight: 900,
              letterSpacing: 6,
              color: V.ink,
            }}
          >
            如画 <span style={{color: V.goldDeep}}>Lumira</span>
          </div>
          <div style={{fontSize: 34, color: V.inkSoft, fontWeight: 600, marginTop: 12}}>
            把拍照的方法，装进模板里
          </div>
        </div>
        {/* 左下小相机人 */}
        <div style={{position: 'absolute', left: 130, bottom: 60, width: 330, height: 330}}>
          <CameraGuy frame={frame} start={40} speed={0.7} />
        </div>
        <StickyCap text="不用背参数，不用记构图——想拍的时候，打开就能拍" frame={frame} fps={fps} start={40} duration={205} highlight={['打开就能拍']} />
      </Paper>
    </AbsoluteFill>
  );
};
