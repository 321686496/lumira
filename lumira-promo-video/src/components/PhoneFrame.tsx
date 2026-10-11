import {Img, staticFile, useCurrentFrame} from 'remotion';
import type {CSSProperties, ReactNode} from 'react';

export const PhoneFrame: React.FC<{
  src?: string;
  width?: number;
  style?: CSSProperties;
  glow?: boolean;
  float?: boolean;
  children?: ReactNode;
}> = ({src, width = 330, style, glow, float = true, children}) => {
  const frame = useCurrentFrame();
  const bob = float ? Math.sin(frame / 55) * 7 : 0;
  return (
    <div
      style={{
        position: 'relative',
        width,
        borderRadius: 46,
        overflow: 'hidden',
        border: '5px solid #262040',
        background: '#000',
        boxShadow: glow
          ? '0 0 70px rgba(232,192,122,0.32), 0 44px 90px rgba(0,0,0,0.62)'
          : '0 44px 90px rgba(0,0,0,0.62)',
        translate: `0px ${bob}px`,
        ...style,
      }}
    >
      {src ? (
        <Img
          src={staticFile(src)}
          style={{width: '100%', display: 'block'}}
        />
      ) : null}
      {children}
    </div>
  );
};
