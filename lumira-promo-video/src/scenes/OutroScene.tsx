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
import {PhoneFrame} from '../components/PhoneFrame';

export const OutroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const logoIn = spring({frame: Math.max(0, frame - 20), fps, config: {damping: 13, stiffness: 110}});
  const nameIn = spring({frame: Math.max(0, frame - 45), fps, config: {damping: 200}});
  const btnIn = spring({frame: Math.max(0, frame - 90), fps, config: {damping: 15, stiffness: 130}});
  const pulse = 1 + 0.04 * Math.sin(frame / 16);

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={50} glowY={40} />

      {/* 两侧装饰手机 */}
      <PhoneFrame
        src="shots/home2.png"
        width={250}
        style={{position: 'absolute', left: 130, top: 260, rotate: '-8deg', opacity: 0.5}}
      />
      <PhoneFrame
        src="shots/my-templates.png"
        width={250}
        style={{position: 'absolute', right: 130, top: 260, rotate: '8deg', opacity: 0.5}}
      />

      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 40}}>
        {/* Logo 图标 */}
        <div
          style={{
            width: 170,
            height: 170,
            borderRadius: '50%',
            background: 'radial-gradient(circle at 35% 30%, #3a2a5e, #1c1332)',
            border: '3px solid rgba(232,192,122,0.75)',
            boxShadow: '0 0 60px rgba(255,180,91,0.45), 0 24px 60px rgba(0,0,0,0.55)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            opacity: logoIn,
            scale: interpolate(logoIn, [0, 1], [0.4, 1], {output: 'perceptual-scale'}),
          }}
        >
          <svg width={84} height={84} viewBox="0 0 24 24" fill="none" stroke={C.gold} strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round">
            <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
            <circle cx={12} cy={13} r={4} />
          </svg>
        </div>
        <div
          style={{
            fontSize: 130,
            fontWeight: 800,
            letterSpacing: 16,
            opacity: nameIn,
            ...goldText,
          }}
        >
          如画 Lumira
        </div>
        <div style={{fontSize: 40, color: C.muted, letterSpacing: 6, fontWeight: 500, opacity: nameIn}}>
          打开模板 · 跟着拍 · 直出好看
        </div>

        {/* 下载按钮 */}
        <div
          style={{
            marginTop: 30,
            padding: '28px 76px',
            borderRadius: 999,
            background: 'linear-gradient(120deg, #f6d9a8, #ffb45b)',
            boxShadow: '0 0 55px rgba(255,180,91,0.4), 0 20px 50px rgba(0,0,0,0.5)',
            opacity: btnIn,
            scale: `${interpolate(btnIn, [0, 1], [0.7, 1], {output: 'perceptual-scale'}) * pulse}`,
          }}
        >
          <div style={{fontSize: 46, fontWeight: 800, color: '#241838', letterSpacing: 4}}>
            应用商店搜索「如画 Lumira」
          </div>
        </div>
        <div style={{fontSize: 32, color: C.gold, letterSpacing: 8, fontWeight: 600, opacity: btnIn}}>
          iOS · 鸿蒙 已上线
        </div>
      </AbsoluteFill>

      <Captions
        items={[
          {start: 40, duration: 240, segs: cap('如画 Lumira——打开模板，跟着拍，每一帧都是心动', ['如画 Lumira', '每一帧都是心动'])},
        ]}
      />
    </AbsoluteFill>
  );
};
