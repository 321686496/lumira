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
import {StickFigure} from '../components/StickFigure';

const Tag: React.FC<{text: string; bad?: boolean; delay: number}> = ({text, bad, delay}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: Math.max(0, frame - delay), fps, config: {damping: 14, stiffness: 180}});
  return (
    <div
      style={{
        display: 'inline-block',
        padding: '9px 24px',
        borderRadius: 999,
        fontSize: 26,
        fontWeight: 700,
        fontFamily: FONT,
        color: bad ? C.red : C.gold,
        border: `1.5px solid ${bad ? 'rgba(255,107,129,0.55)' : 'rgba(232,192,122,0.6)'}`,
        background: bad ? 'rgba(255,107,129,0.1)' : 'rgba(232,192,122,0.12)',
        opacity: s,
        scale: interpolate(s, [0, 1], [0.5, 1], {output: 'perceptual-scale'}),
      }}
    >
      {text}
    </div>
  );
};

const PANEL_W = 640;
const PANEL_H = 660;
const PANEL_Y = 230;

export const WhyScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const leftIn = spring({frame: Math.max(0, frame - 40), fps, config: {damping: 200}});
  const rightIn = spring({frame: Math.max(0, frame - 210), fps, config: {damping: 200}});
  const arrowP = interpolate(frame, [265, 310], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const punch = spring({frame: Math.max(0, frame - 395), fps, config: {damping: 13, stiffness: 130}});

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={50} glowY={90} />
      <div
        style={{
          position: 'absolute',
          top: 92,
          left: 0,
          right: 0,
          textAlign: 'center',
          fontSize: 64,
          fontWeight: 800,
          color: C.text,
          letterSpacing: 5,
        }}
      >
        为什么需要这三个要素？
      </div>

      {/* 左：随手拍 */}
      <div
        style={{
          position: 'absolute',
          left: 190,
          top: PANEL_Y,
          width: PANEL_W,
          height: PANEL_H,
          borderRadius: 30,
          background: '#141020',
          border: '2px solid rgba(255,255,255,0.07)',
          opacity: leftIn,
          translate: `${interpolate(leftIn, [0, 1], [-80, 0])}px 0px`,
          overflow: 'hidden',
        }}
      >
        <div style={{position: 'absolute', top: 26, left: 0, right: 0, textAlign: 'center', fontSize: 36, fontWeight: 800, color: C.dim, letterSpacing: 6}}>
          随手拍
        </div>
        <div style={{position: 'absolute', left: 0, right: 0, top: 110, display: 'flex', justifyContent: 'center'}}>
          <StickFigure color="#5d5478" variant="stiff" width={190} />
        </div>
        <div style={{position: 'absolute', bottom: 110, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 16}}>
          <Tag text="光线平淡" bad delay={125} />
          <Tag text="主体居中" bad delay={145} />
          <Tag text="情绪僵硬" bad delay={165} />
        </div>
        <div style={{position: 'absolute', bottom: 34, left: 0, right: 0, textAlign: 'center', fontSize: 26, color: C.dim}}>
          同一个场景，同一个人
        </div>
      </div>

      {/* 中间箭头 */}
      <svg
        width={220}
        height={80}
        viewBox="0 0 220 80"
        style={{position: 'absolute', left: 850, top: PANEL_Y + PANEL_H / 2 - 40}}
      >
        <path
          d="M10 40 L185 40 M160 15 L190 40 L160 65"
          stroke={C.gold}
          strokeWidth={7}
          strokeLinecap="round"
          strokeLinejoin="round"
          fill="none"
          pathLength={1}
          strokeDasharray={1}
          strokeDashoffset={1 - arrowP}
          style={{filter: 'drop-shadow(0 0 12px rgba(255,180,91,0.7))'}}
        />
      </svg>

      {/* 右：有方法 */}
      <div
        style={{
          position: 'absolute',
          left: 1090,
          top: PANEL_Y,
          width: PANEL_W,
          height: PANEL_H,
          borderRadius: 30,
          background: 'linear-gradient(160deg, #33204d, #4a2b45)',
          border: '2px solid rgba(232,192,122,0.5)',
          boxShadow: '0 0 60px rgba(232,192,122,0.15), 0 30px 70px rgba(0,0,0,0.5)',
          opacity: rightIn,
          translate: `${interpolate(rightIn, [0, 1], [80, 0])}px 0px`,
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: 'radial-gradient(360px 300px at 72% 18%, rgba(255,214,150,0.28), transparent 70%)',
          }}
        />
        {/* 三分网格 */}
        <svg width={PANEL_W} height={PANEL_H} style={{position: 'absolute', inset: 0}}>
          {[1, 2].map((i) => (
            <line key={`v${i}`} x1={(PANEL_W / 3) * i} y1={0} x2={(PANEL_W / 3) * i} y2={PANEL_H} stroke="rgba(232,192,122,0.28)" strokeWidth={2} strokeDasharray="8 10" opacity={rightIn} />
          ))}
          {[1, 2].map((i) => (
            <line key={`h${i}`} x1={0} y1={(PANEL_H / 3) * i} x2={PANEL_W} y2={(PANEL_H / 3) * i} stroke="rgba(232,192,122,0.28)" strokeWidth={2} strokeDasharray="8 10" opacity={rightIn} />
          ))}
        </svg>
        <div style={{position: 'absolute', top: 26, left: 0, right: 0, textAlign: 'center', fontSize: 36, fontWeight: 800, color: C.gold, letterSpacing: 6}}>
          有方法
        </div>
        {/* 人物放在左三分线上 */}
        <div style={{position: 'absolute', left: PANEL_W / 3 - 95, top: 110}}>
          <StickFigure color={C.gold} variant="elegant" width={190} />
        </div>
        <div style={{position: 'absolute', bottom: 110, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 16}}>
          <Tag text="光影氛围" delay={300} />
          <Tag text="三分构图" delay={320} />
          <Tag text="情绪到位" delay={340} />
        </div>
        <div style={{position: 'absolute', bottom: 34, left: 0, right: 0, textAlign: 'center', fontSize: 26, color: C.muted}}>
          只是多了三样东西
        </div>
      </div>

      {/* 结论 */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 940,
          textAlign: 'center',
          fontSize: 60,
          fontWeight: 800,
          color: C.text,
          letterSpacing: 5,
          opacity: punch,
          scale: interpolate(punch, [0, 1], [0.8, 1], {output: 'perceptual-scale'}),
        }}
      >
        差距不在设备，在<span style={{color: C.gold}}>「方法」</span>
      </div>

      <Captions
        items={[
          {start: 30, duration: 120, segs: cap('为什么同一个人、同一个场景，拍出来天差地别？', ['天差地别'])},
          {start: 175, duration: 120, segs: cap('随手拍：光线平淡、主体居中、情绪僵硬', ['光线平淡', '主体居中', '情绪僵硬'])},
          {start: 320, duration: 130, segs: cap('另一边只是多了：对的光线、对的构图、对的情绪', ['对的光线', '对的构图', '对的情绪'])},
          {start: 470, duration: 65, segs: cap('这就是三要素存在的意义', ['三要素'])},
        ]}
      />
    </AbsoluteFill>
  );
};
