import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {V, FONT2} from '../v2/theme';
import {Paper, Stamp, StickyCap, InkPath, DrawOnImage} from '../v2/ink';

/* ===================== 变形人脸（参数化 SVG，核心吸睛件） ===================== */

/** s: 1.0 = 自然，1.35 = 30cm 近距畸变（鼻大脸宽嘴横张） */
const DistortFace: React.FC<{s: number; frame: number; start?: number; ink?: string}> = ({
  s,
  frame,
  start = -999,
  ink = V.ink,
}) => {
  const k = Math.max(0, (s - 1) / 0.35); // 0..1
  const cx = 150;
  const cy = 158;
  const rx = 84 + 26 * k;
  const ry = 112;
  const noseTipY = 182 + 16 * k;
  const noseW = 15 + 13 * k;
  const mouthW = 25 + 20 * k;
  const eyeDX = 44 + 8 * k;
  const eyeY = 136;
  const hairTop = cy - ry - 6;
  return (
    <svg viewBox="0 0 300 340" width="100%" height="100%">
      {/* 头发弧 */}
      <InkPath
        d={`M${cx - rx - 4} ${cy - 18} C ${cx - rx - 10} ${hairTop - 26}, ${cx + rx + 10} ${hairTop - 26}, ${cx + rx + 4} ${cy - 18}`}
        frame={frame}
        start={start}
        duration={14}
        width={5}
        color={ink}
      />
      <InkPath
        d={`M${cx - rx + 26} ${hairTop + 8} Q ${cx} ${hairTop - 12}, ${cx + rx - 30} ${hairTop + 14}`}
        frame={frame}
        start={start + 4}
        duration={10}
        width={4}
        color={ink}
      />
      {/* 脸轮廓 */}
      <InkPath
        d={`M${cx - rx} ${cy} a ${rx} ${ry} 0 1 0 ${rx * 2} 0 a ${rx} ${ry} 0 1 0 ${-rx * 2} 0`}
        frame={frame}
        start={start + 2}
        duration={16}
        width={5}
        color={ink}
      />
      {/* 耳朵 */}
      <InkPath
        d={`M${cx - rx + 2} ${cy - 8} q -16 10 0 26 M${cx + rx - 2} ${cy - 8} q 16 10 0 26`}
        frame={frame}
        start={start + 8}
        duration={8}
        width={4.5}
        color={ink}
      />
      {/* 眉眼（闭眼笑） */}
      <InkPath
        d={`M${cx - eyeDX - 13} ${eyeY - 20} q 13 -8 26 0 M${cx + eyeDX - 13} ${eyeY - 20} q 13 -8 26 0`}
        frame={frame}
        start={start + 10}
        duration={8}
        width={4.5}
        color={ink}
      />
      <InkPath
        d={`M${cx - eyeDX - 12} ${eyeY + 2} q 12 10 24 0 M${cx + eyeDX - 12} ${eyeY + 2} q 12 10 24 0`}
        frame={frame}
        start={start + 12}
        duration={8}
        width={4.5}
        color={ink}
      />
      {/* 鼻（随畸变增大）：桥→鼻尖→小回钩 */}
      <InkPath
        d={`M${cx} ${noseTipY - 44} q ${noseW} ${26 + 8 * k} 0 44 q ${-noseW * 0.25} 6 ${-noseW * 0.7} 4`}
        frame={frame}
        start={start + 14}
        duration={10}
        width={4.5}
        color={ink}
      />
      {/* 鼻头圆点 */}
      <circle cx={cx} cy={noseTipY} r={3.5} fill={ink} opacity={0.85} />
      {/* 嘴（越近越横张） */}
      <InkPath
        d={`M${cx - mouthW} ${noseTipY + 26} q ${mouthW} ${14 - 6 * k} ${mouthW * 2} 0`}
        frame={frame}
        start={start + 16}
        duration={10}
        width={4.5}
        color={ink}
      />
    </svg>
  );
};

/* ============================ 距离徽章（进度条式） ============================ */

const DistanceBadge: React.FC<{cm: number; label: string; color: string}> = ({cm, label, color}) => (
  <div
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: 16,
      background: V.white,
      border: `4px solid ${V.ink}`,
      borderRadius: 999,
      padding: '14px 34px',
      boxShadow: '8px 8px 0 rgba(26,26,26,0.1)',
    }}
  >
    <span style={{fontSize: 44, fontWeight: 900, color, fontFamily: FONT2}}>
      {cm}cm
    </span>
    <span
      style={{
        fontSize: 34,
        fontWeight: 800,
        color: V.inkSoft,
        borderLeft: `3px solid ${V.gray}`,
        paddingLeft: 16,
        fontFamily: FONT2,
      }}
    >
      {label}
    </span>
  </div>
);

/* ================================ 解法行 ================================ */

const TipRow: React.FC<{
  frame: number;
  fps: number;
  start: number;
  n: number;
  title: string;
  sub: string;
}> = ({frame, fps, start, n, title, sub}) => {
  const s = spring({frame: Math.max(0, frame - start), fps, config: {damping: 13, stiffness: 200}});
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 26,
        background: V.white,
        border: `4px solid ${V.ink}`,
        borderRadius: 20,
        padding: '22px 30px',
        width: 900,
        boxShadow: '9px 9px 0 rgba(26,26,26,0.1)',
        transform: `translateX(${(1 - s) * -70}px)`,
        opacity: s,
      }}
    >
      <div
        style={{
          minWidth: 74,
          height: 74,
          borderRadius: '50%',
          border: `4px solid ${V.goldDeep}`,
          color: V.goldDeep,
          fontSize: 40,
          fontWeight: 900,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          transform: 'rotate(-4deg)',
        }}
      >
        {n}
      </div>
      <div style={{textAlign: 'left'}}>
        <div style={{fontSize: 42, fontWeight: 900, color: V.ink, fontFamily: FONT2}}>{title}</div>
        <div style={{fontSize: 30, fontWeight: 600, color: V.inkSoft, marginTop: 4, fontFamily: FONT2}}>{sub}</div>
      </div>
    </div>
  );
};

/* ============================== 字幕包装（竖屏） ============================== */

const Cap: React.FC<{text: string; frame: number; fps: number; start: number; duration: number; rotate?: number; highlight?: string[]}> = (p) => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      transform: 'scale(0.88)',
      transformOrigin: '50% calc(100% - 60px)',
    }}
  >
    <StickyCap {...p} />
  </div>
);

/* ================================= 音效 ================================= */

const SFX: {f: number; src: string; v: number}[] = [
  {f: 6, src: 'sfx/pop.wav', v: 0.3},
  {f: 40, src: 'sfx/pop.wav', v: 0.38},
  {f: 92, src: 'sfx/pop.wav', v: 0.3},
  {f: 132, src: 'sfx/pop.wav', v: 0.3},
  {f: 188, src: 'sfx/pop.wav', v: 0.3},
  {f: 244, src: 'sfx/pop.wav', v: 0.32},
  {f: 268, src: 'sfx/whoosh.wav', v: 0.35},
  {f: 405, src: 'sfx/ding.wav', v: 0.45},
  {f: 460, src: 'sfx/pop.wav', v: 0.32},
  {f: 512, src: 'sfx/pop.wav', v: 0.32},
  {f: 564, src: 'sfx/pop.wav', v: 0.32},
  {f: 646, src: 'sfx/shutter.wav', v: 0.4},
  {f: 706, src: 'sfx/ding.wav', v: 0.42},
];

/* ================================= 正片 ================================= */

export const FactE01: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  /* ---- Act1：脸被前置广角慢慢拉宽（0-72） ---- */
  const inflate = interpolate(frame, [8, 34], [1.0, 1.35], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  /* ---- Act2：三档距离对比（72-260，换脸节奏 132/188/244） ---- */
  const LADDER = [
    {f: 84, cm: 30, s: 1.35, label: '挤变形', color: V.red},
    {f: 140, cm: 80, s: 1.15, label: '好多了', color: V.ink},
    {f: 196, cm: 150, s: 1.0, label: '自然', color: V.goldDeep},
  ];
  const cur = [...LADDER].reverse().find((l) => frame >= l.f) ?? LADDER[0];

  /* ---- Act3：连续复原（268-405） ---- */
  const morphT = interpolate(frame, [268, 400], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const ease = 1 - Math.pow(1 - morphT, 2.2);
  const morphS = 1.35 - 0.35 * ease;
  const morphCm = Math.round(interpolate(ease, [0, 1], [30, 150]));
  const goldRing = interpolate(frame, [402, 408, 424], [0, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  /* ---- Act4：三步解法（430-640） ---- */

  /* ---- Act5：落款（640-750） ---- */
  const signIn = interpolate(frame, [688, 706], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  /* 各段可见性（防层叠残留） */
  const act1Out = interpolate(frame, [64, 76], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const act2Out = interpolate(frame, [252, 262], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const act3Out = interpolate(frame, [420, 432], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});

  return (
    <AbsoluteFill style={{backgroundColor: V.paper, fontFamily: FONT2}}>
      <Paper>
        {/* ============ Act1 钩子：脸被拉宽（0-72） ============ */}
        <div style={{position: 'absolute', inset: 0, opacity: act1Out}}>
          <div style={{position: 'absolute', left: '50%', top: 130, transform: 'translateX(-50%)'}}>
            <DistanceBadge cm={30} label="前置摄像头" color={V.red} />
          </div>
          <div style={{position: 'absolute', left: '50%', top: 330, transform: 'translateX(-50%)', width: 620}}>
            <DistortFace s={inflate} frame={frame} />
          </div>
          <div style={{position: 'absolute', left: 0, right: 0, top: 1170, display: 'flex', justifyContent: 'center'}}>
            <Stamp text="自拍显脸大？不怪你" frame={frame} fps={fps} start={40} size={96} color={V.red} border rotate={-3} />
          </div>
        </div>

        {/* ============ Act2 原理：广角 + 三档距离（72-260） ============ */}
        {frame >= 72 && (
          <div style={{position: 'absolute', inset: 0, opacity: act2Out}}>
            {/* 广角说明条 */}
            <div
              style={{
                position: 'absolute',
                left: '50%',
                top: 150,
                transform: 'translateX(-50%)',
                display: 'flex',
                alignItems: 'center',
                gap: 18,
              }}
            >
              <svg width={92} height={72} viewBox="0 0 92 72">
                <InkPath d="M14 26 h50 l14 10 -14 10 h-50 z" frame={frame} start={76} duration={10} width={4} color={V.ink} />
                <circle cx={72} cy={36} r={7} fill="none" stroke={V.ink} strokeWidth={4} />
              </svg>
              <span style={{fontSize: 40, fontWeight: 800, color: V.inkSoft}}>前摄 = 广角镜 · 等效 24mm</span>
            </div>
            <div style={{position: 'absolute', left: 0, right: 0, top: 260, display: 'flex', justifyContent: 'center'}}>
              <Stamp text="越近，中间越凸" frame={frame} fps={fps} start={92} size={100} color={V.ink} rotate={-1.6} />
            </div>
            {/* 当前距离脸 */}
            <div key={cur.cm} style={{position: 'absolute', left: '50%', top: 480, transform: 'translateX(-50%)', width: 560}}>
              <DistortFace s={cur.s} frame={frame} start={cur.f} />
            </div>
            <div style={{position: 'absolute', left: '50%', top: 1260, transform: 'translateX(-50%)'}}>
              <div key={'b' + cur.cm}>
                <DistanceBadge cm={cur.cm} label={cur.label} color={cur.color} />
              </div>
            </div>
          </div>
        )}

        {/* ============ Act3 连续复原（268-430） ============ */}
        {frame >= 262 && (
          <div style={{position: 'absolute', inset: 0, opacity: act3Out}}>
            {/* 金色复原光环 */}
            <AbsoluteFill
              style={{
                background: `radial-gradient(circle at 50% 52%, rgba(201,169,110,${0.32 * goldRing}) 0%, transparent 58%)`,
              }}
            />
            {/* 距离进度条 */}
            <div style={{position: 'absolute', left: '50%', top: 190, transform: 'translateX(-50%)', width: 820}}>
              <div style={{height: 16, border: `3px solid ${V.ink}`, borderRadius: 999, background: V.white, overflow: 'hidden'}}>
                <div
                  style={{
                    width: `${ease * 100}%`,
                    height: '100%',
                    background: V.gold,
                    borderRadius: 999,
                  }}
                />
              </div>
              <div style={{display: 'flex', justifyContent: 'space-between', marginTop: 10, fontSize: 30, fontWeight: 700, color: V.inkSoft}}>
                <span>30cm</span>
                <span style={{color: V.goldDeep, fontWeight: 900, fontSize: 36}}>{morphCm}cm</span>
                <span>150cm</span>
              </div>
            </div>
            {/* 变形中的脸 */}
            <div style={{position: 'absolute', left: '50%', top: 430, transform: 'translateX(-50%)', width: 600}}>
              <DistortFace s={morphS} frame={frame} />
            </div>
            {goldRing > 0 && (
              <div style={{position: 'absolute', left: 0, right: 0, top: 1300, display: 'flex', justifyContent: 'center'}}>
                <Stamp text="自然" frame={frame} fps={fps} start={408} size={130} color={V.goldDeep} border rotate={-3} />
              </div>
            )}
          </div>
        )}

        {/* ============ Act4 三步解法（430-640） ============ */}
        {frame >= 428 && (
          <div style={{position: 'absolute', inset: 0, opacity: interpolate(frame, [610, 626], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}}>
            <div style={{position: 'absolute', left: 0, right: 0, top: 170, display: 'flex', justifyContent: 'center'}}>
              <Stamp text="记住这三步" frame={frame} fps={fps} start={436} size={110} color={V.ink} rotate={-1.6} />
            </div>
            <div style={{position: 'absolute', left: '50%', top: 400, transform: 'translateX(-50%)', display: 'flex', flexDirection: 'column', gap: 34}}>
              <TipRow frame={frame} fps={fps} start={460} n={1} title="退后一步半" sub="人脸离镜头 ≥ 1 米，畸变减大半" />
              <TipRow frame={frame} fps={fps} start={512} n={2} title="镜头与眼睛齐平" sub="不俯拍不仰拍，比例最自然" />
              <TipRow frame={frame} fps={fps} start={564} n={3} title="用 2x 焦段拍人" sub="视角变窄，广角畸变直接减半" />
            </div>
          </div>
        )}

        {/* ============ Act5 落款（640-750） ============ */}
        {frame >= 636 && (
          <div style={{position: 'absolute', inset: 0}}>
            {/* 显影少女（品牌 IP 形象） */}
            <div style={{position: 'absolute', left: '50%', top: 330, transform: 'translateX(-50%)', width: 620}}>
              <div
                style={{
                  background: V.white,
                  border: `5px solid ${V.ink}`,
                  borderRadius: 12,
                  padding: 30,
                  boxShadow: '24px 26px 0 rgba(26,26,26,0.1)',
                }}
              >
                <div style={{width: 560, height: 560, border: `4px solid ${V.ink}`, borderRadius: 8, overflow: 'hidden', background: V.paper}}>
                  <DrawOnImage src="v2/girl-line.png" frame={frame} start={646} duration={44} width={560} height={560} />
                </div>
              </div>
            </div>
            {/* 落款 */}
            <div
              style={{
                position: 'absolute',
                left: '50%',
                top: 1300,
                transform: 'translateX(-50%)',
                textAlign: 'center',
                opacity: signIn,
              }}
            >
              <div style={{fontSize: 64, fontWeight: 900, fontFamily: FONT2}}>
                <span style={{color: V.ink}}>如画 </span>
                <span style={{color: V.goldDeep}}>Lumira</span>
              </div>
              <div style={{fontSize: 34, fontWeight: 700, color: V.inkSoft, marginTop: 14, letterSpacing: 4}}>
                拍照这件事，是可以学会的
              </div>
            </div>
          </div>
        )}

        {/* ============ 字幕（3 条短句） ============ */}
        <Cap text="同一张脸，只换了距离" frame={frame} fps={fps} start={150} duration={70} rotate={-0.8} highlight={['距离']} />
        <Cap text="镜头没变，变的只是距离" frame={frame} fps={fps} start={300} duration={76} rotate={0.8} highlight={['距离']} />
        <Cap text="下次拍照，先退两步" frame={frame} fps={fps} start={660} duration={78} rotate={-0.8} highlight={['退两步']} />

        {/* ============ 音效 ============ */}
        {SFX.map((s, i) => (
          <Sequence key={i} from={s.f} durationInFrames={60}>
            <Audio src={staticFile(s.src)} volume={s.v} />
          </Sequence>
        ))}
      </Paper>
    </AbsoluteFill>
  );
};
