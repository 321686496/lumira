'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';

/**
 * iPhone 15 Pro 手机框架
 * - 屏幕比例 393:852（19.5:9），与真机一致
 * - 钛金属中框 + 灵动岛 + 侧边按钮装饰
 * 用于手机预览与剪影预览，保证两者比例与大小完全一致。
 */
interface IphoneFrameProps {
  children: React.ReactNode;
  className?: string;
  /** 外壳宽度（px），默认 240。屏幕宽度 ≈ 240 - 边框 */
  width?: number;
}

export default function IphoneFrame({
  children,
  className,
  width = 240,
}: IphoneFrameProps) {
  return (
    <div className={cn('relative select-none', className)} style={{ width }}>
      {/* 侧边按钮（装饰） */}
      <div className="absolute -left-[2.5px] top-[16%] h-[26px] w-[3px] rounded-l-md bg-[#7c7f84]" />
      <div className="absolute -left-[2.5px] top-[24%] h-[48px] w-[3px] rounded-l-md bg-[#7c7f84]" />
      <div className="absolute -left-[2.5px] top-[33%] h-[48px] w-[3px] rounded-l-md bg-[#7c7f84]" />
      <div className="absolute -right-[2.5px] top-[22%] h-[64px] w-[3px] rounded-r-md bg-[#7c7f84]" />

      {/* 钛金属中框 */}
      <div className="rounded-[2.4rem] bg-gradient-to-b from-[#d9dbde] via-[#8b8e93] to-[#bcbfc3] p-[3px] shadow-[0_12px_32px_rgba(0,0,0,0.4)]">
        <div className="rounded-[2.2rem] bg-[#101114] p-[4px]">
          {/* 屏幕 */}
          <div className="relative aspect-[393/852] overflow-hidden rounded-[1.6rem] bg-black">
            {/* 灵动岛 */}
            <div className="absolute left-1/2 top-[10px] z-40 h-[24px] w-[80px] -translate-x-1/2 rounded-full bg-black shadow-[inset_0_0_0_1px_rgba(255,255,255,0.06)]" />
            {children}
          </div>
        </div>
      </div>
    </div>
  );
}