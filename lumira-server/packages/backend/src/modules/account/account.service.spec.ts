import { sha256Hex, generateSecret, generateOtp } from './hash';

describe('account hash utils', () => {
  it('sha256Hex 稳定且为 64 位十六进制', () => {
    const h = sha256Hex('abc');
    expect(h).toHaveLength(64);
    expect(h).toBe(sha256Hex('abc'));
    expect(h).not.toBe(sha256Hex('abd'));
  });

  it('generateSecret 每次生成不同且非空', () => {
    const a = generateSecret();
    const b = generateSecret();
    expect(a).toBeTruthy();
    expect(a).not.toBe(b);
  });

  it('generateOtp 是 6 位数字', () => {
    const otp = generateOtp();
    expect(otp).toMatch(/^\d{6}$/);
  });

  it('哈希与明文不同 → 存储用哈希', () => {
    const otp = generateOtp();
    expect(sha256Hex(otp)).not.toBe(otp);
  });
});