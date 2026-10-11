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

export const FeatureParamsScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const phoneIn = spring({frame: Math.max(0, frame - 10), fps, config: {damping: 200}});
  const drawerSlide = interpolate(frame, [100, 200], [380, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const headIn = spring({frame: Math.max(0, frame - 20), fps, config: {damping: 200}});

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={25} glowY={50} />
      <PhoneFrame
        width={330}
        glow
        style={{position: 'absolute', left: 210, top: 170, opacity: phoneIn}}
      >
        <Img src={staticFile('shots/camera-params.png')} style={{width: '100%', display: 'block'}} />
        {/* 滑杆标签动画 */}
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            translate: `0px ${drawerSlide}px`,
            padding: '22px 20px 80px',
            background: 'linear-gradient(to top, rgba(0,0,0,0.92) 55%, transparent)',
          }}
        >
          <div style={{fontSize: 28, color: C.gold, fontWeight: 700, letterSpacing: 3, marginBottom: 12}}>
            参数实时预览
          </div>
          <div style={{fontSize: 24, color: C.muted, lineHeight: 1.6}}>
            EV · 白平衡 · 对比度 · 饱和度
            <br />
            所见即所得，拍完不用修
          </div>
        </div>
      </PhoneFrame>

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
        <SectionTag text="03 · 参数调优" />
        <div style={{fontSize: 76, fontWeight: 800, color: C.text, letterSpacing: 4, lineHeight: 1.35}}>
          参数，
          <br />
          驾驭光线
        </div>
        <div style={{display: 'flex', flexDirection: 'column', gap: 34}}>
          <Bullet text="参数是光线的语言，模板替你写好" delay={60} />
          <Bullet text="EV、白平衡、对比度… 实时预览" delay={150} />
          <Bullet text="调好再按快门，拍完不用修" delay={245} gold />
        </div>
      </div>

      <Captions
        items={[
          {start: 30, duration: 125, segs: cap('三要素里的「光线」，交给参数来驾驭', ['光线', '参数'])},
          {start: 175, duration: 115, segs: cap('曝光、白平衡、对比度——模板按场景预置好', ['预置好'])},
          {start: 305, duration: 115, segs: cap('调好再按快门，所见即所得', ['所见即所得'])},
        ]}
      />
    </AbsoluteFill>
  );
};
