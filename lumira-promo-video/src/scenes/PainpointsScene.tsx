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

const PAINS = [
  '面对镜头，手脚不知道往哪放',
  '取景框里，构图总是差点意思',
  '参数页面，密密麻麻看不懂',
];

const CrossIcon: React.FC = () => (
  <div
    style={{
      width: 58,
      height: 58,
      borderRadius: 999,
      border: `2.5px solid ${C.red}`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      position: 'relative',
      flexShrink: 0,
    }}
  >
    <div style={{position: 'absolute', width: 26, height: 3.5, background: C.red, borderRadius: 2, rotate: '45deg'}} />
    <div style={{position: 'absolute', width: 26, height: 3.5, background: C.red, borderRadius: 2, rotate: '-45deg'}} />
  </div>
);

export const PainpointsScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const head = spring({frame: Math.max(0, frame - 10), fps, config: {damping: 200}});
  const sol = spring({frame: Math.max(0, frame - 320), fps, config: {damping: 15, stiffness: 120}});

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={50} glowY={8} />
      <div
        style={{
          position: 'absolute',
          top: 130,
          left: 0,
          right: 0,
          textAlign: 'center',
          opacity: head,
        }}
      >
        <div style={{fontSize: 78, fontWeight: 800, color: C.text, letterSpacing: 6}}>
          拍照时的三个<span style={{color: C.red}}>「不会」</span>
        </div>
      </div>

      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 320,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 62,
        }}
      >
        {PAINS.map((p, i) => {
          const s = spring({
            frame: Math.max(0, frame - (60 + i * 100)),
            fps,
            config: {damping: 17, stiffness: 150},
          });
          return (
            <div
              key={i}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 34,
                padding: '30px 56px',
                borderRadius: 24,
                background: 'rgba(255,107,129,0.06)',
                border: '1.5px solid rgba(255,107,129,0.25)',
                opacity: s,
                translate: `${interpolate(s, [0, 1], [-90, 0])}px 0px`,
              }}
            >
              <CrossIcon />
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
          top: 830,
          display: 'flex',
          justifyContent: 'center',
          opacity: sol,
        }}
      >
        <div
          style={{
            padding: '30px 70px',
            borderRadius: 999,
            background: 'linear-gradient(120deg, rgba(232,192,122,0.2), rgba(255,122,217,0.14))',
            border: '2px solid rgba(232,192,122,0.65)',
            boxShadow: '0 0 50px rgba(232,192,122,0.22)',
            fontSize: 52,
            fontWeight: 800,
            color: C.gold,
            letterSpacing: 5,
            scale: interpolate(sol, [0, 1], [0.75, 1], {output: 'perceptual-scale'}),
          }}
        >
          如画：把「不会」，变成「跟着做」
        </div>
      </div>

      <Captions
        items={[
          {start: 45, duration: 105, segs: cap('面对镜头不会摆，是最普遍的拍照焦虑', ['不会摆'])},
          {start: 165, duration: 90, segs: cap('构图凭感觉，参数靠运气', ['凭感觉', '靠运气'])},
          {start: 305, duration: 105, segs: cap('如画要做的，就是把这三件事全部「模板化」', ['模板化'])},
        ]}
      />
    </AbsoluteFill>
  );
};
