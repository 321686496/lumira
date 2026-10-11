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

const NODES = [
  {year: '1839', name: '银版照相法', desc: ['曝光好几分钟', '人像要靠铁架固定住']},
  {year: '1888', name: '胶片普及', desc: ['肖像馆兴起', '姿势第一次有了「范式」']},
  {year: '1935', name: '时尚人像', desc: ['光线、构图与情绪', '成为一门系统的学问']},
  {year: '2007', name: '手机时代', desc: ['人人都在拍', '「好看」却依然稀缺']},
];

const APPEAR = [70, 220, 370, 520];
const LINE_Y = 470;

export const HistoryScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const lineW = interpolate(frame, [20, 100], [0, 1560], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const headOp = spring({frame: Math.max(0, frame - 5), fps, config: {damping: 200}});
  const endOp = interpolate(frame, [645, 685], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background glowX={20} glowY={12} />
      <div style={{position: 'absolute', left: 120, top: 96, opacity: headOp}}>
        <SectionTag text="PORTRAIT HISTORY" />
        <div
          style={{
            marginTop: 22,
            fontSize: 76,
            fontWeight: 800,
            color: C.text,
            letterSpacing: 6,
          }}
        >
          人像摄影简史
          <span style={{color: C.gold, marginLeft: 26, fontSize: 44, fontWeight: 600}}>
            从银版到手机
          </span>
        </div>
      </div>

      {/* 时间轴主线 */}
      <div
        style={{
          position: 'absolute',
          left: 180,
          top: LINE_Y,
          width: lineW,
          height: 3,
          background: `linear-gradient(90deg, ${C.purple}, ${C.gold})`,
          boxShadow: '0 0 18px rgba(232,192,122,0.5)',
        }}
      />

      {NODES.map((n, i) => {
        const x = 300 + i * 440;
        const s = spring({
          frame: Math.max(0, frame - APPEAR[i]),
          fps,
          config: {damping: 16, stiffness: 160},
        });
        const pulse = 1 + 0.18 * Math.sin(frame / 18 + i);
        return (
          <div key={i} style={{position: 'absolute', left: x, top: 0, opacity: s}}>
            {/* 节点圆点 */}
            <div
              style={{
                position: 'absolute',
                left: -11,
                top: LINE_Y - 11,
                width: 22,
                height: 22,
                borderRadius: 999,
                background: C.gold,
                boxShadow: '0 0 24px rgba(255,180,91,0.9)',
                scale: `${pulse}`,
              }}
            />
            {/* 年份 + 名称（线上方） */}
            <div
              style={{
                position: 'absolute',
                left: -110,
                top: LINE_Y - 210,
                width: 240,
                textAlign: 'center',
                translate: `0px ${interpolate(s, [0, 1], [30, 0])}px`,
              }}
            >
              <div
                style={{
                  fontSize: 78,
                  fontWeight: 800,
                  color: C.gold,
                  letterSpacing: 2,
                  textShadow: '0 6px 30px rgba(255,180,91,0.35)',
                }}
              >
                {n.year}
              </div>
              <div style={{fontSize: 34, fontWeight: 700, color: C.text, marginTop: 8}}>
                {n.name}
              </div>
            </div>
            {/* 描述（线下方） */}
            <div
              style={{
                position: 'absolute',
                left: -160,
                top: LINE_Y + 42,
                width: 340,
                textAlign: 'center',
                color: C.muted,
                fontSize: 29,
                lineHeight: 1.7,
                fontWeight: 500,
              }}
            >
              {n.desc.map((d, j) => (
                <div key={j}>{d}</div>
              ))}
            </div>
          </div>
        );
      })}

      {/* 收尾金句 */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 830,
          textAlign: 'center',
          opacity: endOp,
          fontSize: 52,
          fontWeight: 700,
          color: C.text,
          letterSpacing: 4,
        }}
      >
        设备越来越便宜，
        <span style={{color: C.gold}}>「方法」</span>
        却始终稀缺
      </div>

      <Captions
        items={[
          {start: 30, duration: 130, segs: cap('1839 年，第一张人像照片需要被摄者几分钟一动不动', ['1839', '几分钟一动不动'])},
          {start: 185, duration: 125, segs: cap('胶片让摄影走进大众，肖像馆总结出第一套姿势范式', ['姿势范式'])},
          {start: 345, duration: 125, segs: cap('时尚摄影把光线、构图与情绪，变成可以学习的方法', ['光线、构图与情绪', '方法'])},
          {start: 500, duration: 125, segs: cap('手机让相机无处不在，但好照片仍属于少数懂方法的人', ['无处不在', '少数懂方法的人'])},
          {start: 655, duration: 115, segs: cap('两百年过去，设备平民化了，方法却没有', ['设备平民化', '方法'])},
        ]}
      />
    </AbsoluteFill>
  );
};
