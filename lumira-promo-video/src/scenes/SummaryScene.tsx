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

const POINTS = [
  '好看的人像 = 光线 × 构图 × 情绪',
  '方法可以学习，更可以被「模板化」',
  '如画 Lumira，让普通人直出大片',
];

const CheckIcon: React.FC = () => (
  <div
    style={{
      width: 62,
      height: 62,
      borderRadius: 999,
      background: 'rgba(232,192,122,0.14)',
      border: `2.5px solid ${C.gold}`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0,
    }}
  >
    <svg width={30} height={30} viewBox="0 0 24 24" fill="none" stroke={C.gold} strokeWidth={3.2} strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 12.5l5 5L20 6.5" />
    </svg>
  </div>
);

export const SummaryScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const head = spring({frame: Math.max(0, frame - 8), fps, config: {damping: 200}});
  const tail = spring({frame: Math.max(0, frame - 300), fps, config: {damping: 200}});

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={50} glowY={15} />
      <div
        style={{
          position: 'absolute',
          top: 140,
          left: 0,
          right: 0,
          textAlign: 'center',
          opacity: head,
        }}
      >
        <div style={{fontSize: 40, color: C.gold, letterSpacing: 12, fontWeight: 700, marginBottom: 16}}>
          SUMMARY
        </div>
        <div style={{fontSize: 84, fontWeight: 800, color: C.text, letterSpacing: 8}}>
          写在最后
        </div>
      </div>

      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 360,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 58,
        }}
      >
        {POINTS.map((p, i) => {
          const s = spring({
            frame: Math.max(0, frame - (50 + i * 100)),
            fps,
            config: {damping: 16, stiffness: 140},
          });
          return (
            <div
              key={i}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 30,
                padding: '30px 60px',
                borderRadius: 26,
                background: 'rgba(255,255,255,0.04)',
                border: `1.5px solid ${C.cardBorder}`,
                opacity: s,
                translate: `0px ${interpolate(s, [0, 1], [60, 0])}px`,
              }}
            >
              <CheckIcon />
              <div style={{fontSize: 50, fontWeight: 700, color: C.text, letterSpacing: 3}}>
                {p}
              </div>
            </div>
          );
        })}
      </div>

      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 880,
          textAlign: 'center',
          opacity: tail,
          fontSize: 38,
          color: C.gold,
          fontWeight: 600,
          letterSpacing: 8,
        }}
      >
        每一帧，都是心动
      </div>

      <Captions
        items={[
          {start: 25, duration: 105, segs: cap('回顾这一路：设备在变，方法的价值不变', ['方法的价值不变'])},
          {start: 145, duration: 100, segs: cap('光线、构图、情绪——好照片的三块拼图', ['三块拼图'])},
          {start: 265, duration: 90, segs: cap('现在，它们都在你的口袋里', ['口袋里'])},
        ]}
      />
    </AbsoluteFill>
  );
};
