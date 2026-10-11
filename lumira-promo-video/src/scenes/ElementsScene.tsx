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

const CARD_W = 470;
const CARD_H = 560;
const CARD_Y = 330;

/** 光线：放射太阳 + 呼吸光晕 */
const LightIcon: React.FC<{frame: number}> = ({frame}) => {
  const pulse = 1 + 0.08 * Math.sin(frame / 20);
  const rot = frame * 0.35;
  return (
    <svg width={220} height={190} viewBox="0 0 220 190">
      <circle cx={110} cy={95} r={58 * pulse} fill="rgba(255,180,91,0.14)" />
      <circle cx={110} cy={95} r={40 * pulse} fill="rgba(255,180,91,0.18)" />
      {Array.from({length: 8}, (_, i) => {
        const a = (i * Math.PI) / 4 + (rot * Math.PI) / 180;
        const r1 = 46;
        const r2 = 70 + 8 * Math.sin(frame / 15 + i);
        return (
          <line
            key={i}
            x1={110 + Math.cos(a) * r1}
            y1={95 + Math.sin(a) * r1}
            x2={110 + Math.cos(a) * r2}
            y2={95 + Math.sin(a) * r2}
            stroke={C.goldBright}
            strokeWidth={5}
            strokeLinecap="round"
          />
        );
      })}
      <circle cx={110} cy={95} r={26} fill={C.gold} />
      <circle cx={101} cy={86} r={8} fill="rgba(255,255,255,0.65)" />
    </svg>
  );
};

/** 构图：三分线 + 视觉落点 */
const GridIcon: React.FC<{frame: number}> = ({frame}) => {
  const draw = interpolate(frame, [0, 45], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const dot = spring({frame: Math.max(0, frame - 50), fps: 30, config: {damping: 10}});
  return (
    <svg width={230} height={170} viewBox="0 0 230 170">
      <rect x={5} y={5} width={220} height={160} rx={10} stroke={C.gold} strokeWidth={3} fill="none" opacity={0.9} />
      {[1, 2].map((i) => (
        <line key={`v${i}`} x1={5 + (220 / 3) * i} y1={5} x2={5 + (220 / 3) * i} y2={165} stroke={C.gold} strokeWidth={2.5} pathLength={1} strokeDasharray={1} strokeDashoffset={1 - draw} opacity={0.75} />
      ))}
      {[1, 2].map((i) => (
        <line key={`h${i}`} x1={5} y1={5 + (160 / 3) * i} x2={225} y2={5 + (160 / 3) * i} stroke={C.gold} strokeWidth={2.5} pathLength={1} strokeDasharray={1} strokeDashoffset={1 - draw} opacity={0.75} />
      ))}
      <circle cx={5 + 220 / 3} cy={5 + 160 / 3} r={10 * dot} fill={C.pink} opacity={0.95} />
      <circle cx={5 + 220 / 3} cy={5 + 160 / 3} r={20 * dot} stroke={C.pink} strokeWidth={2} fill="none" opacity={0.5} />
    </svg>
  );
};

/** 情绪：人物剪影 + 光晕环绕 */
const EmotionIcon: React.FC<{frame: number}> = ({frame}) => {
  const breathe = 1 + 0.06 * Math.sin(frame / 24);
  const haloOp = 0.4 + 0.3 * Math.sin(frame / 28);
  return (
    <div style={{position: 'relative', width: 160, height: 200}}>
      <svg width={160} height={200} viewBox="0 0 160 200" style={{position: 'absolute', inset: 0}}>
        <ellipse
          cx={80}
          cy={100}
          rx={74 * breathe}
          ry={90 * breathe}
          fill="none"
          stroke={C.pink}
          strokeWidth={2.5}
          strokeDasharray="6 10"
          opacity={haloOp}
        />
      </svg>
      <div style={{position: 'absolute', left: 15, top: -22, scale: `${breathe}`}}>
        <StickFigure color={C.pink} variant="elegant" width={130} />
      </div>
      {/* 眼神光点 */}
      <div
        style={{
          position: 'absolute',
          left: 84,
          top: 12,
          width: 8,
          height: 8,
          borderRadius: 999,
          background: C.goldBright,
          boxShadow: '0 0 12px rgba(255,180,91,1)',
          opacity: haloOp + 0.4,
        }}
      />
    </div>
  );
};

const CARDS = [
  {no: '01', name: '光线', en: 'LIGHT', desc: '决定影调与氛围', Icon: LightIcon},
  {no: '02', name: '构图', en: 'COMPOSITION', desc: '引导视线，框定叙事', Icon: GridIcon},
  {no: '03', name: '情绪', en: 'EMOTION', desc: '照片的灵魂所在', Icon: EmotionIcon},
];

export const ElementsScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const focus = interpolate(frame, [275, 300, 515, 540], [0, 1, 1, 2], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const headOp = spring({frame: Math.max(0, frame - 5), fps, config: {damping: 200}});

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={50} glowY={10} />
      <div
        style={{
          position: 'absolute',
          top: 110,
          left: 0,
          right: 0,
          textAlign: 'center',
          opacity: headOp,
        }}
      >
        <div style={{fontSize: 40, color: C.muted, letterSpacing: 10, marginBottom: 18}}>
          百年人像史给出的答案
        </div>
        <div style={{fontSize: 80, fontWeight: 800, color: C.text, letterSpacing: 6}}>
          好看的人像，由
          <span style={{color: C.gold}}>三个要素</span>
          决定
        </div>
      </div>

      {CARDS.map((card, i) => {
        const enter = spring({
          frame: Math.max(0, frame - (50 + i * 240)),
          fps,
          config: {damping: 18, stiffness: 140},
        });
        const activeness = 1 - Math.min(1, Math.abs(focus - i));
        const x = 215 + i * (CARD_W + 40);
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: CARD_Y,
              width: CARD_W,
              height: CARD_H,
              borderRadius: 32,
              background: `linear-gradient(165deg, rgba(255,255,255,0.055), rgba(255,255,255,0.015)), ${C.card}`,
              border: `1.5px solid ${activeness > 0.7 ? 'rgba(232,192,122,0.55)' : C.cardBorder}`,
              boxShadow:
                activeness > 0.7
                  ? '0 0 55px rgba(232,192,122,0.18), 0 30px 70px rgba(0,0,0,0.5)'
                  : '0 30px 70px rgba(0,0,0,0.5)',
              opacity: enter * (0.42 + 0.58 * activeness),
              scale: interpolate(enter, [0, 1], [0.7, 0.97 + 0.03 * activeness], {
                output: 'perceptual-scale',
              }),
              translate: `0px ${interpolate(enter, [0, 1], [90, 0])}px`,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              padding: '52px 30px',
              gap: 26,
            }}
          >
            <div style={{fontSize: 26, color: C.dim, fontWeight: 700, letterSpacing: 4}}>
              {card.no}
            </div>
            <div style={{height: 200, display: 'flex', alignItems: 'center'}}>
              <card.Icon frame={Math.max(0, frame - (50 + i * 240))} />
            </div>
            <div style={{fontSize: 62, fontWeight: 800, color: C.text, letterSpacing: 8}}>
              {card.name}
            </div>
            <div style={{fontSize: 22, color: C.gold, letterSpacing: 5, fontWeight: 600}}>
              {card.en}
            </div>
            <div style={{fontSize: 32, color: C.muted, fontWeight: 500}}>{card.desc}</div>
          </div>
        );
      })}

      <Captions
        items={[
          {start: 20, duration: 65, segs: cap('一张人像好不好看，核心取决于三件事')},
          {start: 90, duration: 175, segs: cap('第一，光线——影调与氛围，全部由光决定', ['光线', '由光决定'])},
          {start: 315, duration: 175, segs: cap('第二，构图——人在画面里的位置，就是叙事本身', ['构图', '叙事'])},
          {start: 555, duration: 185, segs: cap('第三，情绪——姿势与神态里，藏着照片的灵魂', ['情绪', '灵魂'])},
        ]}
      />
    </AbsoluteFill>
  );
};
