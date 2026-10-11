import type {CSSProperties} from 'react';
import {C, FONT} from '../theme';

export const SectionTag: React.FC<{text: string; style?: CSSProperties}> = ({
  text,
  style,
}) => {
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        padding: '10px 26px',
        borderRadius: 999,
        border: `1.5px solid rgba(232,192,122,0.55)`,
        color: C.gold,
        fontFamily: FONT,
        fontSize: 26,
        fontWeight: 600,
        letterSpacing: 6,
        ...style,
      }}
    >
      {text}
    </div>
  );
};
