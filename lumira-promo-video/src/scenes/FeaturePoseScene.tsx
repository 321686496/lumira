import {
  AbsoluteFill,
  Img,
  staticFile,
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
        translate: `${interpolate(s, [0, 1], [70, 0])}px 0px`,
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

export const FeaturePoseScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const phoneIn = spring({frame: Math.max(0, frame - 10), fps, config: {damping: 200}});
  const resultOp = interpolate(frame, [190, 245], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const headIn = spring({frame: Math.max(0, frame - 20), fps, config: {damping: 200}});

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={25} glowY={50} />
      {/* 手机：剪影 → 成片 渐变 */}
      <PhoneFrame
        width={330}
        glow
        style={{position: 'absolute', left: 210, top: 170, opacity: phoneIn}}
      >
        <Img src={staticFile('shots/camera-silhouette.png')} style={{width: '100%', display: 'block'}} />
        <Img
          src={staticFile('shots/camera-result.png')}
          style={{position: 'absolute', left: 0, top: 0, width: '100%', opacity: resultOp}}
        />
        {/* 角标 */}
        <div
          style={{
            position: 'absolute',
            left: 14,
            top: 14,
            padding: '8px 20px',
            borderRadius: 999,
            background: 'rgba(0,0,0,0.55)',
            border: `1.5px solid ${resultOp > 0.5 ? 'rgba(232,192,122,0.8)' : 'rgba(255,255,255,0.3)'}`,
            color: resultOp > 0.5 ? C.gold : C.text,
            fontSize: 24,
            fontWeight: 700,
            letterSpacing: 3,
          }}
        >
          {resultOp > 0.5 ? '成片' : '剪影引导'}
        </div>
      </PhoneFrame>

      {/* 右侧文案 */}
      <div
        style={{
          position: 'absolute',
          left: 700,
          top: 230,
          display: 'flex',
          flexDirection: 'column',
          gap: 48,
          opacity: headIn,
        }}
      >
        <SectionTag text="01 · 姿势引导" />
        <div style={{fontSize: 76, fontWeight: 800, color: C.text, letterSpacing: 4, lineHeight: 1.35}}>
          姿势，
          <br />
          承载情绪
        </div>
        <div style={{display: 'flex', flexDirection: 'column', gap: 34}}>
          <Bullet text="情绪看不见摸不着？让它写在肢体里" delay={60} />
          <Bullet text="真人姿势剪影，直接叠在取景框上" delay={145} />
          <Bullet text="照着站，情绪自然来" delay={265} gold />
        </div>
      </div>

      <Captions
        items={[
          {start: 30, duration: 135, segs: cap('三要素里的「情绪」，由姿势来承载', ['情绪', '姿势'])},
          {start: 180, duration: 135, segs: cap('模板把姿势画成剪影，你只管照着站', ['剪影', '照着站'])},
          {start: 330, duration: 140, segs: cap('从剪影到成片，所见即所得', ['所见即所得'])},
        ]}
      />
    </AbsoluteFill>
  );
};
