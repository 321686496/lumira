import {
  Sequence,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from 'remotion';
import {C, FONT} from '../theme';

export type CapSeg = {t: string; hl?: boolean};
export type CapItem = {start: number; duration: number; segs: CapSeg[]};

const CaptionLine: React.FC<{segs: CapSeg[]; duration: number}> = ({
  segs,
  duration,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({frame: Math.max(0, frame), fps, config: {damping: 200}});
  const out = interpolate(frame, [duration - 10, duration], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        bottom: 64,
        display: 'flex',
        justifyContent: 'center',
        opacity: out,
        translate: `0px ${interpolate(enter, [0, 1], [36, 0])}px`,
        scale: interpolate(enter, [0, 1], [0.92, 1], {
          output: 'perceptual-scale',
        }),
        pointerEvents: 'none',
      }}
    >
      <div
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 4,
          padding: '18px 42px',
          borderRadius: 999,
          background: 'rgba(11,8,22,0.68)',
          border: `1px solid rgba(232,192,122,0.35)`,
          boxShadow: '0 16px 50px rgba(0,0,0,0.45)',
          backdropFilter: 'blur(10px)',
          fontFamily: FONT,
          fontSize: 38,
          fontWeight: 500,
          color: C.text,
          letterSpacing: 1.5,
          whiteSpace: 'nowrap',
        }}
      >
        {segs.map((s, i) => (
          <span
            key={i}
            style={
              s.hl
                ? {color: C.goldBright, fontWeight: 700}
                : undefined
            }
          >
            {s.t}
          </span>
        ))}
      </div>
    </div>
  );
};

export const Captions: React.FC<{items: CapItem[]}> = ({items}) => {
  const {fps} = useVideoConfig();
  return (
    <>
      {items.map((item, i) => (
        <Sequence
          key={i}
          name={`字幕 ${i + 1}`}
          from={item.start}
          durationInFrames={item.duration}
          premountFor={fps}
        >
          <CaptionLine segs={item.segs} duration={item.duration} />
        </Sequence>
      ))}
    </>
  );
};

export const cap = (text: string, hlWords: string[] = []): CapSeg[] => {
  let rest = text;
  const segs: CapSeg[] = [];
  while (rest.length > 0) {
    let earliest = -1;
    let word = '';
    for (const w of hlWords) {
      const idx = rest.indexOf(w);
      if (idx >= 0 && (earliest < 0 || idx < earliest)) {
        earliest = idx;
        word = w;
      }
    }
    if (earliest < 0) {
      segs.push({t: rest});
      break;
    }
    if (earliest > 0) segs.push({t: rest.slice(0, earliest)});
    segs.push({t: word, hl: true});
    rest = rest.slice(earliest + word.length);
  }
  return segs;
};
