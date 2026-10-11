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

/* ============================ 太阳（呼吸金圆） ============================ */

const Sun: React.FC<{frame: number; cx: number; cy: number; r: number}> = ({frame, cx, cy, r}) => {
  const pulse = 1 + Math.sin(frame * 0.09) * 0.05;
  const R = r * pulse;
  return (
    <svg
      width={R * 3.2}
      height={R * 3.2}
      viewBox={`${-R * 1.6} ${-R * 1.6} ${R * 3.2} ${R * 3.2}`}
      style={{position: 'absolute', left: cx - R * 1.6, top: cy - R * 1.6}}
    >
      <circle r={R * 1.5} fill="rgba(201,169,110,0.16)" />
      <circle r={R * 1.15} fill="rgba(201,169,110,0.3)" />
      <circle r={R} fill={V.gold} opacity={0.9} />
      {[0, 45, 90, 135, 180, 225, 270, 315].map((deg) => {
        const rad = (deg * Math.PI) / 180;
        return (
          <line
            key={deg}
            x1={Math.cos(rad) * (R + 14)}
            y1={Math.sin(rad) * (R + 14)}
            x2={Math.cos(rad) * (R + 40)}
            y2={Math.sin(rad) * (R + 40)}
            stroke={V.goldDeep}
            strokeWidth={5}
            strokeLinecap="round"
            opacity={0.75}
          />
        );
      })}
    </svg>
  );
};

/* ================== 逆光女生（剪影⇄亮态双图层交叉淡化） ================== */

const BacklitGirl: React.FC<{lit: number; frame: number; start?: number}> = ({lit, frame, start = -999}) => {
  const dark = 1 - lit;
  return (
    <svg viewBox="0 0 300 420" width="100%" height="100%">
      {/* 剪影层（逆光未点亮） */}
      <g opacity={dark * 0.92}>
        <circle cx={150} cy={92} r={36} fill={V.ink} />
        <path d="M128 118 q22 16 44 0 l8 12 q-30 20 -60 0 z" fill={V.ink} />
        <path d="M136 128 L118 250 L128 400 M164 128 L182 250 L172 400 L150 400 L128 400" stroke={V.ink} strokeWidth={22} strokeLinecap="round" fill="none" />
        <path d="M150 150 L108 210 M150 150 L192 210" stroke={V.ink} strokeWidth={16} strokeLinecap="round" />
        <path d="M112 214 L150 158 L188 214 Z" fill={V.ink} />
      </g>
      {/* 线稿层（点亮后） */}
      <g opacity={Math.max(0.12, lit)}>
        <circle cx={150} cy={92} r={36} fill={V.white} stroke={V.ink} strokeWidth={4.5} />
        <InkPath d="M138 88 q6 5 12 0 M156 88 q6 5 12 0" frame={frame} start={start} duration={8} width={4} />
        <InkPath d="M144 104 q6 4 12 0" frame={frame} start={start + 2} duration={6} width={4} />
        {/* 头发 */}
        <InkPath d="M116 80 q10 -34 40 -32 q28 2 32 34 M120 96 q-6 30 2 52 M180 98 q8 28 2 50" frame={frame} start={start + 2} duration={12} width={4.5} />
        {/* 身体：连衣裙 + 手臂 + 腿 */}
        <InkPath d="M132 126 L112 252 L188 252 L168 126" frame={frame} start={start + 4} duration={14} width={4.5} />
        <InkPath d="M132 132 L102 196 M168 132 L198 196" frame={frame} start={start + 8} duration={10} width={4.5} />
        <InkPath d="M124 252 L120 396 M176 252 L180 396" frame={frame} start={start + 10} duration={12} width={4.5} />
        <InkPath d="M106 400 h30 M164 400 h30" frame={frame} start={start + 12} duration={8} width={4.5} />
        <InkPath d="M112 252 q38 12 76 0" frame={frame} start={start + 12} duration={8} width={4} color={V.gray} />
      </g>
      {/* 发丝金边（点亮后出现） */}
      <g opacity={lit * 0.95}>
        <path d="M114 82 q12 -36 42 -34" stroke={V.gold} strokeWidth={7} strokeLinecap="round" fill="none" opacity={0.9} />
        <path d="M186 86 q-4 30 -14 52" stroke={V.gold} strokeWidth={6} strokeLinecap="round" fill="none" opacity={0.75} />
        <path d="M110 150 q-16 26 -8 60" stroke={V.gold} strokeWidth={5} strokeLinecap="round" fill="none" opacity={0.5} />
        <path d="M190 152 q14 26 8 58" stroke={V.gold} strokeWidth={5} strokeLinecap="round" fill="none" opacity={0.5} />
      </g>
    </svg>
  );
};

/* ============================== 测光框（滑动） ============================== */

const MeterBox: React.FC<{x: number; y: number; size: number; opacity?: number}> = ({x, y, size, opacity = 1}) => {
  const c = size / 2;
  const L = size * 0.32;
  return (
    <svg
      width={size + 8}
      height={size + 8}
      viewBox={`${-c - 4} ${-c - 4} ${size + 8} ${size + 8}`}
      style={{position: 'absolute', left: x - c - 4, top: y - c - 4, opacity}}
    >
      {[
        `M${-c} ${-c + L} V${-c} H${-c + L}`,
        `M${c - L} ${-c} H${c} V${-c + L}`,
        `M${c} ${c - L} V${c} H${c - L}`,
        `M${-c + L} ${c} H${-c} V${c - L}`,
      ].map((d, i) => (
        <path key={i} d={d} stroke={V.goldDeep} strokeWidth={7} fill="none" strokeLinecap="round" />
      ))}
      <circle r={5} fill={V.goldDeep} />
    </svg>
  );
};

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
  {f: 100, src: 'sfx/pop.wav', v: 0.32},
  {f: 190, src: 'sfx/pop.wav', v: 0.32},
  {f: 268, src: 'sfx/whoosh.wav', v: 0.4},
  {f: 336, src: 'sfx/pop.wav', v: 0.3},
  {f: 400, src: 'sfx/ding.wav', v: 0.45},
  {f: 436, src: 'sfx/pop.wav', v: 0.32},
  {f: 460, src: 'sfx/pop.wav', v: 0.3},
  {f: 512, src: 'sfx/pop.wav', v: 0.3},
  {f: 564, src: 'sfx/pop.wav', v: 0.3},
  {f: 646, src: 'sfx/shutter.wav', v: 0.4},
  {f: 706, src: 'sfx/ding.wav', v: 0.42},
];

/* ================================= 正片 ================================= */

export const FactE02: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  /* ---- Act2：测光两态（100 天空 / 190 人脸） ---- */
  const st2 = frame >= 190 ? 1 : 0;

  /* ---- Act3：测光框滑到脸上 + 点亮（268-340） ---- */
  const slide = interpolate(frame, [268, 320], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const ease3 = 1 - Math.pow(1 - slide, 2);
  const lit = interpolate(frame, [290, 344], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const goldGlow = interpolate(frame, [300, 360], [0, 0.3], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  /* 各段可见性（防层叠残留） */
  const act1Out = interpolate(frame, [64, 76], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const act2Out = interpolate(frame, [252, 262], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const act3Out = interpolate(frame, [420, 432], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const signIn = interpolate(frame, [688, 706], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});

  return (
    <AbsoluteFill style={{backgroundColor: V.paper, fontFamily: FONT2}}>
      <Paper>
        {/* ============ Act1 钩子：逆光剪影（0-72） ============ */}
        <div style={{position: 'absolute', inset: 0, opacity: act1Out}}>
          <Sun frame={frame} cx={790} cy={300} r={105} />
          <div style={{position: 'absolute', left: '50%', top: 380, transform: 'translateX(-50%)', width: 640}}>
            <BacklitGirl lit={0} frame={frame} />
          </div>
          <div style={{position: 'absolute', left: 0, right: 0, top: 1250, display: 'flex', justifyContent: 'center'}}>
            <Stamp text="脸黑，不怪逆光" frame={frame} fps={fps} start={40} size={100} color={V.red} border rotate={-3} />
          </div>
        </div>

        {/* ============ Act2 原理：手机在替你选（72-260） ============ */}
        {frame >= 72 && (
          <div style={{position: 'absolute', inset: 0, opacity: act2Out}}>
            <div style={{position: 'absolute', left: '50%', top: 130, transform: 'translateX(-50%)'}}>
              <Stamp text="你的手机，在替你做选择" frame={frame} fps={fps} start={82} size={62} color={V.ink} rotate={-1.2} />
            </div>
            {/* 场景：太阳 + 女生 */}
            <div style={{position: 'relative', width: 1080, height: 900, marginTop: 300}}>
              <Sun frame={frame} cx={770} cy={220} r={70} />
              <div style={{position: 'absolute', left: 250, top: 60, width: 400}}>
                <BacklitGirl lit={st2 === 1 ? 1 : 0} frame={frame} start={st2 === 1 ? 194 : -999} />
              </div>
              {/* 测光框：先在太阳上，190 帧跳到脸上 */}
              <MeterBox x={st2 === 1 ? 450 : 770} y={st2 === 1 ? 190 : 220} size={st2 === 1 ? 150 : 170} />
              <div
                style={{
                  position: 'absolute',
                  left: 0,
                  right: 0,
                  top: 700,
                  display: 'flex',
                  justifyContent: 'center',
                }}
              >
                {st2 === 1 ? (
                  <Stamp key="b" text="测到脸：脸亮了" frame={frame} fps={fps} start={194} size={72} color={V.goldDeep} border rotate={1.5} />
                ) : (
                  <Stamp key="a" text="测到天空：脸被压黑" frame={frame} fps={fps} start={100} size={72} color={V.red} border rotate={-1.5} />
                )}
              </div>
            </div>
          </div>
        )}

        {/* ============ Act3 反转：测光点脸，点亮（262-430） ============ */}
        {frame >= 262 && (
          <div style={{position: 'absolute', inset: 0, opacity: act3Out}}>
            {/* 暖光氛围 */}
            <AbsoluteFill
              style={{
                background: `radial-gradient(circle at 50% 46%, rgba(201,169,110,${goldGlow}) 0%, transparent 60%)`,
              }}
            />
            <div style={{position: 'relative', width: 1080, height: 1160, marginTop: 120}}>
              <Sun frame={frame} cx={810} cy={190} r={88} />
              <div style={{position: 'absolute', left: 260, top: 60, width: 560}}>
                <BacklitGirl lit={lit} frame={frame} start={290} />
              </div>
              {/* 测光框从太阳滑到脸 */}
              <MeterBox
                x={interpolate(ease3, [0, 1], [810, 540])}
                y={interpolate(ease3, [0, 1], [190, 320])}
                size={interpolate(ease3, [0, 1], [170, 150])}
                opacity={frame < 352 ? 1 : interpolate(frame, [352, 366], [1, 0], {extrapolateRight: 'clamp'})}
              />
            </div>
            <div style={{position: 'absolute', left: 0, right: 0, top: 1300, display: 'flex', justifyContent: 'center'}}>
              <Stamp text="逆光是宝藏光" frame={frame} fps={fps} start={405} size={110} color={V.goldDeep} border rotate={-3} />
            </div>
          </div>
        )}

        {/* ============ Act4 三步解法（428-640） ============ */}
        {frame >= 428 && (
          <div style={{position: 'absolute', inset: 0, opacity: interpolate(frame, [610, 626], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}}>
            <div style={{position: 'absolute', left: 0, right: 0, top: 170, display: 'flex', justifyContent: 'center'}}>
              <Stamp text="逆光这样救" frame={frame} fps={fps} start={436} size={110} color={V.ink} rotate={-1.6} />
            </div>
            <div style={{position: 'absolute', left: '50%', top: 400, transform: 'translateX(-50%)', display: 'flex', flexDirection: 'column', gap: 34}}>
              <TipRow frame={frame} fps={fps} start={460} n={1} title="点一下人脸" sub="对焦框放在脸上，测光跟着走" />
              <TipRow frame={frame} fps={fps} start={512} n={2} title="下拉小太阳" sub="脸太亮就 -0.3，找回天空细节" />
              <TipRow frame={frame} fps={fps} start={564} n={3} title="侧逆光 45° 最美" sub="光从侧后来，发丝自带金边" />
            </div>
          </div>
        )}

        {/* ============ Act5 落款（636-750） ============ */}
        {frame >= 636 && (
          <div style={{position: 'absolute', inset: 0}}>
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
                  <DrawOnImage src="v2/girl-gold.png" frame={frame} start={646} duration={44} width={560} height={560} />
                </div>
              </div>
            </div>
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
        <Cap text="脸黑不是光的错" frame={frame} fps={fps} start={110} duration={64} rotate={-0.8} highlight={['不是光的错']} />
        <Cap text="点一下，光就听你的了" frame={frame} fps={fps} start={300} duration={72} rotate={0.8} highlight={['听你的']} />
        <Cap text="逆光人像，反而最出片" frame={frame} fps={fps} start={660} duration={78} rotate={-0.8} highlight={['最出片']} />

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
