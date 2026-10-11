import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from 'remotion';
import {C, FONT, MONO} from '../theme';
import {Background} from '../components/Background';
import {Captions, cap} from '../components/Caption';
import {SectionTag} from '../components/SectionTag';

const CODE_LINES = [
  {text: 'const template = await lumira.create({', color: '#c9b8ff'},
  {text: '  pose: "银杏大道 · 扶额侧望",', color: '#ffd9a0'},
  {text: '  composition: "rule-of-thirds",', color: '#a0e8ff'},
  {text: '  params: { ev: +0.3, wb: 5200 },', color: '#ffb3d9'},
  {text: '});', color: '#c9b8ff'},
  {text: '  // 光线 · 构图 · 情绪 → 一键驾驭', color: '#7be0a3'},
];

export const BuildScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const cardIn = spring({frame: Math.max(0, frame - 15), fps, config: {damping: 200}});
  const iconIn = spring({frame: Math.max(0, frame - 155), fps, config: {damping: 13, stiffness: 120}});
  const glowPulse = 30 + 18 * Math.sin(frame / 20);
  const caretOp = Math.abs(Math.sin(frame / 8)) > 0.4 ? 1 : 0;

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={25} glowY={30} />
      <div style={{position: 'absolute', top: 100, left: 0, right: 0, display: 'flex', justifyContent: 'center'}}>
        <SectionTag text="VIBE CODING" />
      </div>

      {/* 代码卡片 */}
      <div
        style={{
          position: 'absolute',
          left: 150,
          top: 240,
          width: 900,
          borderRadius: 24,
          background: '#120d22',
          border: `1.5px solid ${C.cardBorder}`,
          boxShadow: '0 40px 90px rgba(0,0,0,0.6)',
          opacity: cardIn,
          translate: `${interpolate(cardIn, [0, 1], [-70, 0])}px 0px`,
          overflow: 'hidden',
        }}
      >
        <div style={{display: 'flex', gap: 12, padding: '22px 28px', borderBottom: `1px solid ${C.cardBorder}`}}>
          {['#ff5f57', '#febc2e', '#28c840'].map((c) => (
            <div key={c} style={{width: 20, height: 20, borderRadius: 999, background: c}} />
          ))}
          <div style={{marginLeft: 20, color: C.dim, fontSize: 24, fontFamily: MONO}}>template.ts</div>
        </div>
        <div style={{padding: '36px 40px', fontFamily: MONO, fontSize: 33, lineHeight: 2.05}}>
          {CODE_LINES.map((line, i) => {
            const op = interpolate(frame, [40 + i * 32, 52 + i * 32], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            });
            const isLast = i === CODE_LINES.length - 1;
            return (
              <div key={i} style={{opacity: op, color: line.color, whiteSpace: 'pre'}}>
                {line.text}
                {isLast && frame > 52 + i * 32 ? (
                  <span style={{opacity: caretOp, color: C.gold}}>▌</span>
                ) : null}
              </div>
            );
          })}
        </div>
      </div>

      {/* 编译成的 App 图标 */}
      <div
        style={{
          position: 'absolute',
          left: 1260,
          top: 360,
          width: 380,
          height: 380,
          borderRadius: '50%',
          background: `radial-gradient(circle at 35% 30%, #3a2a5e, #1c1332)`,
          border: '3px solid rgba(232,192,122,0.65)',
          boxShadow: `0 0 ${glowPulse}px rgba(255,180,91,0.55), 0 30px 70px rgba(0,0,0,0.6)`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          opacity: iconIn,
          scale: interpolate(iconIn, [0, 1], [0.4, 1], {output: 'perceptual-scale'}),
        }}
      >
        <svg width={170} height={170} viewBox="0 0 24 24" fill="none" stroke={C.gold} strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round">
          <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
          <circle cx={12} cy={13} r={4} />
        </svg>
      </div>
      {/* 环绕光点 */}
      {frame > 160
        ? Array.from({length: 6}, (_, i) => {
            const a = frame / 28 + (i * Math.PI) / 3;
            return (
              <div
                key={i}
                style={{
                  position: 'absolute',
                  left: 1450 + Math.cos(a) * 250,
                  top: 550 + Math.sin(a) * 250,
                  width: 10,
                  height: 10,
                  borderRadius: 999,
                  background: i % 2 ? C.pink : C.goldBright,
                  opacity: 0.85,
                  boxShadow: '0 0 12px rgba(255,180,91,0.8)',
                }}
              />
            );
          })
        : null}

      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 830,
          textAlign: 'center',
          fontSize: 54,
          fontWeight: 800,
          color: C.text,
          letterSpacing: 5,
          opacity: interpolate(frame, [180, 215], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}),
        }}
      >
        我用 <span style={{color: C.gold}}>Vibe Coding</span> 把它做了出来
      </div>

      <Captions
        items={[
          {start: 20, duration: 125, segs: cap('不懂晦涩的摄影理论？没关系，代码会替我们记住', ['代码会替我们记住'])},
          {start: 165, duration: 125, segs: cap('我用 Vibe Coding，把「模板化拍摄」做成了一个 App', ['Vibe Coding', '模板化拍摄'])},
        ]}
      />
    </AbsoluteFill>
  );
};
