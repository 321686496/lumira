import type {CSSProperties} from 'react';

export const C = {
  bg0: '#0f0c1a',
  bg1: '#1a1230',
  card: '#171029',
  cardBorder: 'rgba(255,255,255,0.08)',
  gold: '#e8c07a',
  goldBright: '#ffb45b',
  purple: '#b57bff',
  pink: '#ff7ad9',
  text: '#f4efff',
  muted: '#a89cc9',
  dim: '#6f6494',
  red: '#ff6b81',
  green: '#7be0a3',
};

export const FONT = '"Microsoft YaHei","PingFang SC","Noto Sans SC",sans-serif';
export const MONO = 'Consolas,"Courier New",monospace';

export const goldText: CSSProperties = {
  backgroundImage: 'linear-gradient(120deg,#f6d9a8,#ffb45b 55%,#ff7ad9)',
  WebkitBackgroundClip: 'text',
  backgroundClip: 'text',
  color: 'transparent',
};
