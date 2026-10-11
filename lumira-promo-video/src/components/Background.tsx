import {AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {C} from '../theme';

const rand = (seed: number) => {
  const x = Math.sin(seed * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};

const PARTICLES = Array.from({length: 42}, (_, i) => ({
  x: rand(i + 1) * 100,
  y: rand(i + 101) * 100,
  size: 2 + rand(i + 201) * 5,
  speed: 0.25 + rand(i + 301) * 0.6,
  phase: rand(i + 401) * 100,
  warm: rand(i + 501) > 0.45,
}));

export const Background: React.FC<{glowX?: number; glowY?: number}> = ({
  glowX = 78,
  glowY = 18,
}) => {
  const frame = useCurrentFrame();
  const {height} = useVideoConfig();
  const breathe = 0.55 + 0.15 * Math.sin(frame / 90);
  return (
    <AbsoluteFill style={{overflow: 'hidden'}}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(1200px 800px at ${glowX}% ${glowY}%, rgba(181,123,255,${0.16 * breathe}), transparent 60%), radial-gradient(1000px 700px at 15% 85%, rgba(255,180,91,${0.1 * breathe}), transparent 60%), linear-gradient(160deg, ${C.bg1}, ${C.bg0} 70%)`,
        }}
      />
      {PARTICLES.map((p, i) => {
        const drift = (frame * p.speed + p.phase * 20) % (height + 120);
        const twinkle = 0.18 + 0.5 * Math.abs(Math.sin((frame + p.phase * 60) / 45));
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: `${p.x}%`,
              top: p.y * 10 - drift,
              width: p.size,
              height: p.size,
              borderRadius: 999,
              background: p.warm ? C.goldBright : C.purple,
              opacity: twinkle,
              filter: 'blur(0.5px)',
            }}
          />
        );
      })}
      {/* 大 bokeh 光斑漂移 */}
      {Array.from({length: 5}, (_, i) => {
        const bx = 10 + ((i * 37 + frame * (0.06 + i * 0.02)) % 85);
        const by = 12 + i * 17 + Math.sin(frame / 90 + i * 2) * 8;
        const sz = 180 + (i % 3) * 120;
        const warm = i % 2 === 0;
        return (
          <div
            key={`bokeh-${i}`}
            style={{
              position: 'absolute',
              left: `${bx}%`,
              top: `${by}%`,
              width: sz,
              height: sz,
              borderRadius: '50%',
              background: warm
                ? 'radial-gradient(circle, rgba(255,180,91,0.14), transparent 65%)'
                : 'radial-gradient(circle, rgba(181,123,255,0.14), transparent 65%)',
              filter: 'blur(50px)',
              opacity: 0.5 + 0.3 * Math.sin(frame / 70 + i),
            }}
          />
        );
      })}
      {/* 周期性斜向扫光 */}
      {(() => {
        const sweepP = ((frame % 300) + 300) % 300;
        const x = interpolate(sweepP, [0, 300], [-40, 140], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        });
        const op = interpolate(sweepP, [0, 30, 240, 300], [0, 1, 1, 0], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        });
        return (
          <div
            style={{
              position: 'absolute',
              left: `${x}%`,
              top: '-20%',
              width: 260,
              height: '140%',
              background:
                'linear-gradient(100deg, transparent, rgba(255,235,200,0.055) 45%, rgba(255,235,200,0.09) 50%, rgba(255,235,200,0.055) 55%, transparent)',
              opacity: op,
              rotate: '12deg',
              filter: 'blur(6px)',
            }}
          />
        );
      })()}
      <AbsoluteFill
        style={{
          boxShadow: 'inset 0 0 320px 60px rgba(5,3,12,0.85)',
        }}
      />
    </AbsoluteFill>
  );
};
