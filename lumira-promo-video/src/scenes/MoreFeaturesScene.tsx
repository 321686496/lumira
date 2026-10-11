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
import {SectionTag} from '../components/SectionTag';

const CARDS = [
  {title: '探店足迹', en: 'SHOP CHECK-IN', desc: '打卡氛围感，模板一键生成朋友圈海报', icon: 'M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0z M12 10a2 2 0 1 0 0-4 2 2 0 0 0 0 4z'},
  {title: '每日挑战', en: 'DAILY CHALLENGE', desc: '每天一张主题任务，拍出你的进阶感', icon: 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z'},
  {title: '精选集', en: 'COLLECTIONS', desc: '按场景收集模板，旅行、探店、人像各归其位', icon: 'M4 4h16v16H4z M8 8h8v8H8z'},
];

export const MoreFeaturesScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const headIn = spring({frame: Math.max(0, frame - 5), fps, config: {damping: 200}});

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={50} glowY={12} />
      <div
        style={{
          position: 'absolute',
          top: 110,
          left: 0,
          right: 0,
          textAlign: 'center',
          opacity: headIn,
        }}
      >
        <SectionTag text="MORE FEATURES" />
        <div style={{marginTop: 18, fontSize: 72, fontWeight: 800, color: C.text, letterSpacing: 6}}>
          不止人像，还有更多场景
        </div>
      </div>

      <div style={{position: 'absolute', left: 0, right: 0, top: 340, display: 'flex', justifyContent: 'center', gap: 46}}>
        {CARDS.map((c, i) => {
          const s = spring({
            frame: Math.max(0, frame - (40 + i * 120)),
            fps,
            config: {damping: 18, stiffness: 130},
          });
          return (
            <div
              key={i}
              style={{
                width: 480,
                height: 560,
                borderRadius: 30,
                background: `linear-gradient(165deg, rgba(255,255,255,0.055), rgba(255,255,255,0.015)), ${C.card}`,
                border: `1.5px solid ${C.cardBorder}`,
                boxShadow: '0 30px 70px rgba(0,0,0,0.5)',
                opacity: s,
                scale: interpolate(s, [0, 1], [0.75, 1], {output: 'perceptual-scale'}),
                translate: `0px ${interpolate(s, [0, 1], [60, 0])}px`,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                padding: '46px 36px',
                gap: 22,
              }}
            >
              <svg width={72} height={72} viewBox="0 0 24 24" fill="none" stroke={C.gold} strokeWidth={1.4} strokeLinecap="round" strokeLinejoin="round">
                <path d={c.icon} />
              </svg>
              <div style={{fontSize: 42, fontWeight: 800, color: C.text, marginTop: 6, letterSpacing: 5}}>{c.title}</div>
              <div style={{fontSize: 22, color: C.gold, letterSpacing: 4, fontWeight: 600}}>{c.en}</div>
              <div style={{fontSize: 32, color: C.muted, fontWeight: 500, textAlign: 'center', lineHeight: 1.65, marginTop: 8}}>
                {c.desc}
              </div>
            </div>
          );
        })}
      </div>

      <Captions
        items={[
          {start: 35, duration: 130, segs: cap('如画不止拍人：探店足迹、每日挑战、精选集，覆盖你的全部场景', ['探店足迹', '每日挑战', '精选集'])},
        ]}
      />
    </AbsoluteFill>
  );
};
