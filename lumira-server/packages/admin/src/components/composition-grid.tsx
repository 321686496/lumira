'use client';

/**
 * 构图叠加网格 —— 精确移植 Flutter CompositionOverlay（composition_overlay.dart）：
 * - rule_of_thirds: 1/3、2/3 线 + 4 个交点圆点
 * - golden_ratio:  0.382/0.618 线 + 4 个交点圆点
 * - diagonal:      两条对角线
 * - grid:          1/3、2/3 线（无圆点）
 * - leading_lines: 四角 → 中心汇聚线
 * - center:        中心十字 + 居中半尺寸小方框
 * - none:          不绘制
 * 线宽 1px（按屏宽 393pt 折算），颜色白色，透明度 = opacity。
 */

interface CompositionGridProps {
  type: string;
  opacity: number;
}

const LINE_COLOR = 'rgba(255,255,255,';
const DOT_COLOR = 'rgba(255,255,255,';

function Line({ style, color }: { style: React.CSSProperties; color: string }) {
  return <div className="absolute bg-white" style={{ ...style, backgroundColor: color }} />;
}

function Dot({ x, y, color }: { x: number; y: number; color: string }) {
  return (
    <div
      className="absolute rounded-full"
      style={{
        left: `${x * 100}%`,
        top: `${y * 100}%`,
        width: '2%',
        aspectRatio: '1/1',
        transform: 'translate(-50%, -50%)',
        backgroundColor: color,
      }}
    />
  );
}

export default function CompositionGrid({ type, opacity }: CompositionGridProps) {
  if (!type || type === 'none' || opacity <= 0) return null;
  const color = `${LINE_COLOR}${opacity})`;
  const dotColor = `${DOT_COLOR}${opacity})`;

  const horizontalLines = (ratios: number[]) =>
    ratios.map((r) => (
      <Line
        key={`h-${r}`}
        color={color}
        style={{ left: 0, right: 0, top: `${r * 100}%`, height: 1, transform: 'translateY(-50%)' }}
      />
    ));

  const verticalLines = (ratios: number[]) =>
    ratios.map((r) => (
      <Line
        key={`v-${r}`}
        color={color}
        style={{ top: 0, bottom: 0, left: `${r * 100}%`, width: 1, transform: 'translateX(-50%)' }}
      />
    ));

  const dots = (ratios: [number, number][]) =>
    ratios.map(([x, y]) => <Dot key={`${x}-${y}`} x={x} y={y} color={dotColor} />);

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      {type === 'rule_of_thirds' && (
        <>
          {horizontalLines([1 / 3, 2 / 3])}
          {verticalLines([1 / 3, 2 / 3])}
          {dots([
            [1 / 3, 1 / 3],
            [2 / 3, 1 / 3],
            [1 / 3, 2 / 3],
            [2 / 3, 2 / 3],
          ])}
        </>
      )}
      {type === 'golden_ratio' && (
        <>
          {horizontalLines([0.382, 0.618])}
          {verticalLines([0.382, 0.618])}
          {dots([
            [0.382, 0.382],
            [0.618, 0.382],
            [0.382, 0.618],
            [0.618, 0.618],
          ])}
        </>
      )}
      {type === 'diagonal' && (
        <svg className="absolute inset-0 h-full w-full" preserveAspectRatio="none" viewBox="0 0 100 100">
          <line x1="0" y1="0" x2="100" y2="100" stroke={`rgba(255,255,255,${opacity})`} strokeWidth="1" />
          <line x1="100" y1="0" x2="0" y2="100" stroke={`rgba(255,255,255,${opacity})`} strokeWidth="1" />
        </svg>
      )}
      {type === 'grid' && (
        <>
          {horizontalLines([1 / 3, 2 / 3])}
          {verticalLines([1 / 3, 2 / 3])}
        </>
      )}
      {type === 'leading_lines' && (
        <svg className="absolute inset-0 h-full w-full" preserveAspectRatio="none" viewBox="0 0 100 100">
          <line x1="0" y1="0" x2="50" y2="50" stroke={`rgba(255,255,255,${opacity})`} strokeWidth="1" />
          <line x1="100" y1="0" x2="50" y2="50" stroke={`rgba(255,255,255,${opacity})`} strokeWidth="1" />
          <line x1="0" y1="100" x2="50" y2="50" stroke={`rgba(255,255,255,${opacity})`} strokeWidth="1" />
          <line x1="100" y1="100" x2="50" y2="50" stroke={`rgba(255,255,255,${opacity})`} strokeWidth="1" />
        </svg>
      )}
      {type === 'center' && (
        <>
          <Line color={color} style={{ left: '50%', top: 0, bottom: 0, width: 1, transform: 'translateX(-50%)' }} />
          <Line color={color} style={{ top: '50%', left: 0, right: 0, height: 1, transform: 'translateY(-50%)' }} />
          <div
            className="absolute border border-white"
            style={{
              left: '50%',
              top: '50%',
              width: '8%',
              height: '8%',
              transform: 'translate(-50%, -50%)',
              borderColor: `rgba(255,255,255,${opacity})`,
            }}
          />
        </>
      )}
    </div>
  );
}