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

const ELEMENTS = [
  {name: '光线', y: 330},
  {name: '构图', y: 530},
  {name: '情绪', y: 730},
];

export const LinkScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const cardIn = spring({frame: Math.max(0, frame - 120), fps, config: {damping: 14, stiffness: 110}});
  const textIn = spring({frame: Math.max(0, frame - 190), fps, config: {damping: 200}});
  const glow = 20 + 14 * Math.sin(frame / 16);

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={70} glowY={50} />

      {/* 三个要素 chip 飞向模板卡 */}
      {ELEMENTS.map((el, i) => {
        const fly = interpolate(frame, [40 + i * 25, 115 + i * 25], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
          easing: (t) => 1 - Math.pow(1 - t, 3),
        });
        const fade = interpolate(frame, [105 + i * 25, 125 + i * 25], [1, 0.0], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        });
        const startX = 300;
        const endX = 1180;
        const x = startX + (endX - startX) * fly;
        const y = el.y + (545 - el.y) * fly;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              padding: '22px 46px',
              borderRadius: 999,
              background: 'rgba(181,123,255,0.12)',
              border: '2px solid rgba(181,123,255,0.55)',
              fontSize: 42,
              fontWeight: 800,
              color: C.text,
              letterSpacing: 5,
              opacity: fade,
              scale: interpolate(fly, [0, 1], [1, 0.55], {output: 'perceptual-scale'}),
              translate: '-50% -50%',
            }}
          >
            {el.name}
          </div>
        );
      })}

      {/* 模板卡 */}
      <div
        style={{
          position: 'absolute',
          left: 980,
          top: 380,
          width: 400,
          height: 330,
          borderRadius: 28,
          background: 'linear-gradient(160deg, #33204d, #241838)',
          border: '2.5px solid rgba(232,192,122,0.7)',
          boxShadow: `0 0 ${glow}px rgba(232,192,122,0.4), 0 30px 70px rgba(0,0,0,0.55)`,
          opacity: cardIn,
          scale: interpolate(cardIn, [0, 1], [0.5, 1], {output: 'perceptual-scale'}),
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 20,
        }}
      >
        <StickFigure color={C.gold} variant="elegant" width={96} />
        <div style={{fontSize: 44, fontWeight: 800, color: C.gold, letterSpacing: 6}}>拍摄模板</div>
        <div style={{fontSize: 26, color: C.muted, letterSpacing: 2}}>光线 · 构图 · 情绪</div>
      </div>

      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 820,
          textAlign: 'center',
          opacity: textIn,
          fontSize: 64,
          fontWeight: 800,
          color: C.text,
          letterSpacing: 5,
        }}
      >
        两百年的方法，浓缩成<span style={{color: C.gold}}>一个模板</span>
      </div>

      <Captions
        items={[
          {start: 20, duration: 130, segs: cap('还记得摄影史教会我们的三件事吗？', ['三件事'])},
          {start: 160, duration: 130, segs: cap('光线、构图、情绪——如今它们的掌控方法，都住在模板里', ['光线、构图、情绪', '模板'])},
        ]}
      />
    </AbsoluteFill>
  );
};
