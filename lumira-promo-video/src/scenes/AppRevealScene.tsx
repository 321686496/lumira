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

export const AppRevealScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const tag = spring({frame: Math.max(0, frame - 10), fps, config: {damping: 200}});
  const name = spring({frame: Math.max(0, frame - 30), fps, config: {damping: 14, stiffness: 110}});
  const sub = spring({frame: Math.max(0, frame - 60), fps, config: {damping: 200}});
  const phoneIn = spring({frame: Math.max(0, frame - 45), fps, config: {damping: 18, stiffness: 120}});

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={75} glowY={40} />
      <div
        style={{
          position: 'absolute',
          left: 170,
          top: 0,
          bottom: 0,
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          gap: 26,
        }}
      >
        <div style={{fontSize: 30, color: C.gold, letterSpacing: 14, fontWeight: 700, opacity: tag}}>
          INTRODUCING
        </div>
        <div
          style={{
            fontSize: 210,
            fontWeight: 800,
            letterSpacing: 20,
            lineHeight: 1.05,
            opacity: name,
            scale: interpolate(name, [0, 1], [0.75, 1], {output: 'perceptual-scale'}),
            ...goldText,
          }}
        >
          如画
        </div>
        <div
          style={{
            fontSize: 92,
            fontWeight: 300,
            color: C.text,
            letterSpacing: 26,
            opacity: name,
          }}
        >
          Lumira
        </div>
        <div
          style={{
            marginTop: 18,
            width: interpolate(sub, [0, 1], [0, 460]),
            height: 3,
            background: `linear-gradient(90deg, ${C.gold}, transparent)`,
          }}
        />
        <div style={{fontSize: 42, color: C.muted, fontWeight: 500, letterSpacing: 3, opacity: sub, lineHeight: 1.7}}>
          把大师经验，做成可以
          <br />
          直接套用的拍摄模板
        </div>
      </div>

      {/* 后景手机 */}
      <PhoneFrame
        src="shots/home2.png"
        width={250}
        glow={false}
        style={{
          position: 'absolute',
          left: 1210,
          top: 300,
          rotate: '-9deg',
          opacity: 0.45 * phoneIn,
        }}
      />
      {/* 主手机 */}
      <PhoneFrame
        src="shots/home.png"
        width={315}
        glow
        style={{
          position: 'absolute',
          left: 1400,
          top: 165,
          rotate: '-3deg',
          opacity: phoneIn,
        }}
      />

      <Captions
        items={[
          {start: 25, duration: 200, segs: cap('它叫「如画 Lumira」——打开模板，跟着拍，直出好看的人像', ['如画 Lumira', '跟着拍'])},
        ]}
      />
    </AbsoluteFill>
  );
};
