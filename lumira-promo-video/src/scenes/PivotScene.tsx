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

export const PivotScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const l1 = spring({frame: Math.max(0, frame - 20), fps, config: {damping: 200}});
  const l2 = spring({frame: Math.max(0, frame - 55), fps, config: {damping: 12, stiffness: 110}});

  const sparks = Array.from({length: 14}, (_, i) => {
    const angle = (i / 14) * Math.PI * 2;
    const r = interpolate(frame, [60, 120], [0, 330 + (i % 4) * 60], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    const op = interpolate(frame, [60, 90, 140], [0, 1, 0], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    return {
      x: Math.cos(angle) * r,
      y: Math.sin(angle) * r * 0.6,
      op,
      size: 5 + (i % 3) * 4,
    };
  });

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background />
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 40}}>
        <div
          style={{
            fontSize: 58,
            color: C.muted,
            fontWeight: 600,
            letterSpacing: 6,
            opacity: l1,
            translate: `0px ${interpolate(l1, [0, 1], [30, 0])}px`,
          }}
        >
          如果把这两百年的「方法」
        </div>
        <div
          style={{
            fontSize: 128,
            fontWeight: 800,
            letterSpacing: 10,
            opacity: l2,
            scale: interpolate(l2, [0, 1], [0.6, 1], {output: 'perceptual-scale'}),
            ...goldText,
            textShadow: 'none',
          }}
        >
          装进一个模板里呢？
        </div>
      </AbsoluteFill>
      {sparks.map((s, i) => (
        <div
          key={i}
          style={{
            position: 'absolute',
            left: '50%',
            top: '56%',
            width: s.size,
            height: s.size,
            borderRadius: 999,
            background: i % 2 === 0 ? C.goldBright : C.pink,
            opacity: s.op,
            translate: `${s.x}px ${s.y}px`,
            boxShadow: '0 0 14px rgba(255,180,91,0.8)',
          }}
        />
      ))}
      <Captions
        items={[
          {start: 15, duration: 155, segs: cap('一个大胆的想法：把光线、构图、情绪的掌控方法，做成可以直接套用的模板', ['光线、构图、情绪', '模板'])},
        ]}
      />
    </AbsoluteFill>
  );
};
