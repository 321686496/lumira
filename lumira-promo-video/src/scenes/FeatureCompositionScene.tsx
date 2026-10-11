import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from 'remotion';
import {C, FONT} from '../theme';
import {Background} from '../components/Background';
import {Captions, cap} from '../components/Caption';
import {PhoneFrame} from '../components/PhoneFrame';
import {SectionTag} from '../components/SectionTag';

const Bullet: React.FC<{text: string; delay: number; gold?: boolean}> = ({text, delay, gold}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: Math.max(0, frame - delay), fps, config: {damping: 16, stiffness: 150}});
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 22,
        opacity: s,
        translate: `${interpolate(s, [0, 1], [-70, 0])}px 0px`,
      }}
    >
      <div
        style={{
          width: 14,
          height: 14,
          borderRadius: 999,
          background: gold ? C.gold : C.purple,
          boxShadow: `0 0 14px ${gold ? 'rgba(255,180,91,0.9)' : 'rgba(181,123,255,0.9)'}`,
          flexShrink: 0,
        }}
      />
      <div style={{fontSize: 40, fontWeight: gold ? 800 : 600, color: gold ? C.gold : C.text, letterSpacing: 2}}>
        {text}
      </div>
    </div>
  );
};

export const FeatureCompositionScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const phoneIn = spring({frame: Math.max(0, frame - 10), fps, config: {damping: 200}});
  const gridDraw = interpolate(frame, [60, 130], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const circlePulse = 1 + 0.15 * Math.sin(frame / 14);
  const headIn = spring({frame: Math.max(0, frame - 20), fps, config: {damping: 200}});

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={75} glowY={50} />
      {/* 左侧文案 */}
      <div
        style={{
          position: 'absolute',
          left: 170,
          top: 230,
          display: 'flex',
          flexDirection: 'column',
          gap: 48,
          opacity: headIn,
        }}
      >
        <SectionTag text="02 · 构图辅助" />
        <div style={{fontSize: 76, fontWeight: 800, color: C.text, letterSpacing: 4, lineHeight: 1.35}}>
          构图，
          <br />
          不再是玄学
        </div>
        <div style={{display: 'flex', flexDirection: 'column', gap: 34}}>
          <Bullet text="每个模板自带构图参考" delay={60} />
          <Bullet text="人站哪里、景取多少，直接标给你" delay={150} />
          <Bullet text="取景框里，所见即所得" delay={245} gold />
        </div>
      </div>

      {/* 手机：模板详情 + 三分网格叠加 */}
      <PhoneFrame
        src="shots/template-detail.png"
        width={330}
        glow
        style={{position: 'absolute', left: 1380, top: 170, opacity: phoneIn}}
      >
        <svg
          width={330}
          height={330 / 0.4603}
          viewBox="0 0 330 717"
          style={{position: 'absolute', left: 0, top: 0}}
        >
          {[1, 2].map((i) => (
            <line
              key={`v${i}`}
              x1={(330 / 3) * i}
              y1={120}
              x2={(330 / 3) * i}
              y2={560}
              stroke="rgba(255,255,255,0.85)"
              strokeWidth={2.5}
              pathLength={1}
              strokeDasharray={1}
              strokeDashoffset={1 - gridDraw}
            />
          ))}
          {[1, 2].map((i) => (
            <line
              key={`h${i}`}
              x1={0}
              y1={120 + (440 / 3) * i}
              x2={330}
              y2={120 + (440 / 3) * i}
              stroke="rgba(255,255,255,0.85)"
              strokeWidth={2.5}
              pathLength={1}
              strokeDasharray={1}
              strokeDashoffset={1 - gridDraw}
            />
          ))}
          <circle
            cx={330 / 3}
            cy={120 + 440 / 3}
            r={26 * circlePulse}
            stroke={C.goldBright}
            strokeWidth={4}
            fill="none"
            opacity={gridDraw}
          />
        </svg>
        <div
          style={{
            position: 'absolute',
            right: 14,
            top: 14,
            padding: '8px 20px',
            borderRadius: 999,
            background: 'rgba(0,0,0,0.55)',
            border: '1.5px solid rgba(232,192,122,0.8)',
            color: C.gold,
            fontSize: 24,
            fontWeight: 700,
            letterSpacing: 3,
            opacity: gridDraw,
          }}
        >
          三分构图
        </div>
      </PhoneFrame>

      <Captions
        items={[
          {start: 30, duration: 130, segs: cap('三要素里的「构图」，模板直接标给你看', ['构图', '标给你看'])},
          {start: 175, duration: 120, segs: cap('人在画面里站哪里、留多少天、背景怎么取', ['站哪里', '留多少', '怎么取'])},
          {start: 310, duration: 100, segs: cap('取景框里，所见即所得', ['所见即所得'])},
        ]}
      />
    </AbsoluteFill>
  );
};
