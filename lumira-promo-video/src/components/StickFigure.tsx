export const StickFigure: React.FC<{
  color: string;
  variant: 'stiff' | 'elegant';
  width?: number;
  opacity?: number;
}> = ({color, variant, width = 200, opacity = 1}) => {
  const stroke = {
    stroke: color,
    strokeWidth: 7,
    strokeLinecap: 'round' as const,
    fill: 'none',
  };
  return (
    <svg
      width={width}
      height={width * 1.5}
      viewBox="0 0 200 300"
      style={{opacity, display: 'block'}}
    >
      <circle cx={100} cy={variant === 'elegant' ? 58 : 60} r={26} {...stroke} />
      {variant === 'stiff' ? (
        <>
          <path d="M100 92 L100 200" {...stroke} />
          <path d="M100 112 L72 182" {...stroke} />
          <path d="M100 112 L128 182" {...stroke} />
          <path d="M100 200 L80 282" {...stroke} />
          <path d="M100 200 L120 282" {...stroke} />
        </>
      ) : (
        <>
          <path d="M100 90 C 110 130, 90 162, 100 202" {...stroke} />
          <path d="M98 118 C 82 134, 84 108, 96 96" {...stroke} />
          <path d="M102 120 C 120 142, 118 168, 110 188" {...stroke} />
          <path d="M100 202 C 96 232, 92 258, 88 286" {...stroke} />
          <path d="M100 202 C 114 226, 120 252, 126 278" {...stroke} />
        </>
      )}
    </svg>
  );
};
