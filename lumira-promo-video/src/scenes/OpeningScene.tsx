import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from 'remotion';
import {C, FONT, goldText} from '../theme';
import {Background} from '../components/Background';
import {Captions, cap} from '../components/Caption';

const CharTitle: React.FC<{
  text: string;
  frame: number;
  fps: number;
  start: number;
  stagger: number;
  fontSize: number;
  fontWeight: number;
  rise?: number;
  gold?: boolean;
  letterSpacing?: number;
}> = ({
  text,
  frame,
  fps,
  start,
  stagger,
  fontSize,
  fontWeight,
  rise = 60,
  gold,
  letterSpacing = 10,
}) => {
  return (
    <div style={{display: 'flex'}}>
      {text.split('').map((ch, i) => {
        const s = spring({
          frame: Math.max(0, frame - start - i * stagger),
          fps,
          config: {damping: 14, stiffness: 170},
        });
        return (
          <span
            key={i}
            style={{
              display: 'inline-block',
              fontSize,
              fontWeight,
              letterSpacing,
              opacity: s,
              transform: `translateY(${(1 - s) * rise}px) rotate(${(1 - s) * 10}deg)`,
              filter: `blur(${interpolate(s, [0, 1], [10, 0])}px)`,
              textShadow: gold
                ? '0 10px 60px rgba(255,180,91,0.4)'
                : '0 10px 50px rgba(0,0,0,0.6)',
              ...(gold ? goldText : {color: C.text}),
            }}
          >
            {ch === ' ' ? '\u00A0' : ch}
          </span>
        );
      })}
    </div>
  );
};

export const OpeningScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const lineW = interpolate(frame, [10, 50], [0, 160], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background />
      {/* 旋转光圈圆环 */}
      {[420, 640, 900].map((size, i) => (
        <div
          key={i}
          style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            width: size,
            height: size,
            marginLeft: -size / 2,
            marginTop: -size / 2,
            borderRadius: '50%',
            border: `1.5px dashed rgba(232,192,122,${0.14 - i * 0.03})`,
            rotate: `${frame * (0.12 + i * 0.06) * (i % 2 === 0 ? 1 : -1)}deg`,
          }}
        />
      ))}
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'column',
          gap: 34,
        }}
      >
        <div
          style={{
            width: lineW,
            height: 3,
            background: `linear-gradient(90deg, transparent, ${C.gold}, transparent)`,
          }}
        />
        <CharTitle
          text="一张好看的人像照片"
          frame={frame}
          fps={fps}
          start={15}
          stagger={3}
          fontSize={96}
          fontWeight={700}
        />
        <CharTitle
          text="到底靠什么？"
          frame={frame}
          fps={fps}
          start={55}
          stagger={4}
          fontSize={148}
          fontWeight={800}
          rise={90}
          letterSpacing={12}
          gold
        />
        <div
          style={{
            width: lineW,
            height: 3,
            background: `linear-gradient(90deg, transparent, ${C.gold}, transparent)`,
          }}
        />
      </AbsoluteFill>
      <Captions
        items={[
          {
            start: 70,
            duration: 105,
            segs: cap('人像摄影里，「好看」从来不是运气', ['「好看」', '运气']),
          },
        ]}
      />
    </AbsoluteFill>
  );
};
