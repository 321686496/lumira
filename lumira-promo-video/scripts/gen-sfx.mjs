// 程序化生成音效 WAV（16-bit 立体声 44.1kHz）
import {writeFileSync, mkdirSync} from 'node:fs';

const SR = 44100;
mkdirSync('public/sfx', {recursive: true});

const writeWav = (name, samples) => {
  const n = samples.length;
  const buf = Buffer.alloc(44 + n * 4);
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + n * 4, 4);
  buf.write('WAVE', 8);
  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(2, 22);
  buf.writeUInt32LE(SR, 24);
  buf.writeUInt32LE(SR * 4, 28);
  buf.writeUInt16LE(4, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
    buf.writeInt16LE(Math.round(v * 32767), 46 + i * 2);
  }
  writeFileSync(`public/sfx/${name}.wav`, buf);
  console.log(`${name}.wav`, n / SR, 's');
};

// 伪随机噪声
const noise = () => Math.random() * 2 - 1;

// riser：1.4s 上升音，用于开场
{
  const T = 1.4;
  const n = Math.floor(SR * T);
  const out = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const f = 180 * Math.pow(2, (t / T) * 2.6);
    phase += (2 * Math.PI * f) / SR;
    const env = Math.pow(t / T, 1.4) * (1 - Math.pow(Math.max(0, (t - (T - 0.15)) / 0.15), 2) * (t > T - 0.15 ? 1 : 0));
    out[i] = Math.sin(phase) * env * 0.5 + noise() * env * 0.06;
  }
  writeWav('riser', out);
}

// whoosh：0.45s 转场扫掠
{
  const T = 0.45;
  const n = Math.floor(SR * T);
  const out = new Float32Array(n);
  let lp = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const p = t / T;
    const env = Math.sin(Math.PI * p) ** 1.5;
    // 低通系数随包络打开
    const a = 0.02 + 0.35 * env;
    lp += a * (noise() - lp);
    out[i] = lp * env * 1.6;
  }
  writeWav('whoosh', out);
}

// pop：0.14s 弹性入场
{
  const T = 0.14;
  const n = Math.floor(SR * T);
  const out = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const f = 480 + 2600 * t;
    phase += (2 * Math.PI * f) / SR;
    out[i] = Math.sin(phase) * Math.exp(-26 * t) * 0.8;
  }
  writeWav('pop', out);
}

// ding：0.9s 金句强调
{
  const T = 0.9;
  const n = Math.floor(SR * T);
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    out[i] =
      (Math.sin(2 * Math.PI * 880 * t) + 0.5 * Math.sin(2 * Math.PI * 1318.5 * t) + 0.25 * Math.sin(2 * Math.PI * 1760 * t)) *
      Math.exp(-4.2 * t) *
      0.45;
  }
  writeWav('ding', out);
}

// shutter：0.28s 相机快门双咔哒
{
  const T = 0.28;
  const n = Math.floor(SR * T);
  const out = new Float32Array(n);
  const burst = (t, t0) => (t > t0 && t < t0 + 0.05 ? noise() * Math.exp(-110 * (t - t0)) : 0);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    out[i] = (burst(t, 0) + burst(t, 0.11)) * 0.9;
  }
  writeWav('shutter', out);
}
