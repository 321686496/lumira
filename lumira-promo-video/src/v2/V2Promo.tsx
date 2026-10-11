import {AbsoluteFill, Sequence, staticFile, useVideoConfig} from 'remotion';
import {Audio} from '@remotion/media';
import {TransitionSeries, linearTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {slide} from '@remotion/transitions/slide';
import {wipe} from '@remotion/transitions/wipe';
import {flip} from '@remotion/transitions/flip';
import {V} from './theme';
import {V2HookScene, V2FailDiaryScene} from './scenes-a';
import {V2AlbumScene, V2ThreeThingsScene} from './scenes-b';
import {V2GapScene, V2MakeScene, V2RevealScene, V2EndScene} from './scenes-c';

const T = () => linearTiming({durationInFrames: 15});

// 音效锚点（全局帧）
const SFX: {frame: number; src: string; volume: number}[] = [
  {frame: 0, src: 'sfx/riser.wav', volume: 0.5}, // 钩子画线
  {frame: 46, src: 'sfx/pop.wav', volume: 0.4}, // 线稿画完
  {frame: 56, src: 'sfx/shutter.wav', volume: 0.5}, // 盖章 37 次
  {frame: 75, src: 'sfx/whoosh.wav', volume: 0.4}, // → 翻车日记
  {frame: 105, src: 'sfx/pop.wav', volume: 0.3}, // 摄影者小人
  {frame: 185, src: 'sfx/pop.wav', volume: 0.35}, // 废片1
  {frame: 280, src: 'sfx/pop.wav', volume: 0.35}, // 废片2
  {frame: 375, src: 'sfx/pop.wav', volume: 0.35}, // 废片3
  {frame: 390, src: 'sfx/whoosh.wav', volume: 0.45}, // → 翻相册
  {frame: 520, src: 'sfx/pop.wav', volume: 0.35}, // 1839
  {frame: 640, src: 'sfx/pop.wav', volume: 0.35}, // 1900
  {frame: 700, src: 'sfx/pop.wav', volume: 0.35}, // 1950s
  {frame: 795, src: 'sfx/whoosh.wav', volume: 0.4}, // → 三件事
  {frame: 855, src: 'sfx/pop.wav', volume: 0.3}, // 画光线
  {frame: 1005, src: 'sfx/pop.wav', volume: 0.3}, // 画构图
  {frame: 1155, src: 'sfx/pop.wav', volume: 0.3}, // 画情绪
  {frame: 1260, src: 'sfx/whoosh.wav', volume: 0.4}, // → 鸿沟
  {frame: 1400, src: 'sfx/ding.wav', volume: 0.4}, // 提前替我算好
  {frame: 1515, src: 'sfx/whoosh.wav', volume: 0.45}, // → 造模板
  {frame: 1685, src: 'sfx/pop.wav', volume: 0.35}, // 盖章：装进手机
  {frame: 1860, src: 'sfx/whoosh.wav', volume: 0.4}, // → 一遍过
  {frame: 2050, src: 'sfx/shutter.wav', volume: 0.55}, // 按快门
  {frame: 2100, src: 'sfx/ding.wav', volume: 0.4}, // 一遍过
  {frame: 2175, src: 'sfx/whoosh.wav', volume: 0.4}, // → 署名
  {frame: 2380, src: 'sfx/ding.wav', volume: 0.45}, // logo 落定
];

export const V2Promo: React.FC = () => {
  const {fps} = useVideoConfig();
  return (
    <AbsoluteFill style={{backgroundColor: V.paper}}>
      <TransitionSeries>
        <TransitionSeries.Sequence name="V2钩子" durationInFrames={90} premountFor={fps}>
          <V2HookScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={T()} />
        <TransitionSeries.Sequence name="V2翻车日记" durationInFrames={330} premountFor={fps}>
          <V2FailDiaryScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={wipe({direction: 'from-right'})} timing={T()} />
        <TransitionSeries.Sequence name="V2翻相册" durationInFrames={420} premountFor={fps}>
          <V2AlbumScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={slide({direction: 'from-bottom'})} timing={T()} />
        <TransitionSeries.Sequence name="V2三件事" durationInFrames={480} premountFor={fps}>
          <V2ThreeThingsScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={T()} />
        <TransitionSeries.Sequence name="V2鸿沟" durationInFrames={270} premountFor={fps}>
          <V2GapScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={flip({direction: 'from-left'})} timing={T()} />
        <TransitionSeries.Sequence name="V2造模板" durationInFrames={360} premountFor={fps}>
          <V2MakeScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={wipe({direction: 'from-left'})} timing={T()} />
        <TransitionSeries.Sequence name="V2一遍过" durationInFrames={330} premountFor={fps}>
          <V2RevealScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={T()} />
        <TransitionSeries.Sequence name="V2署名" durationInFrames={300} premountFor={fps}>
          <V2EndScene />
        </TransitionSeries.Sequence>
      </TransitionSeries>

      {/* 音效层 */}
      {SFX.map((s, i) => (
        <Sequence key={i} from={s.frame} durationInFrames={60}>
          <Audio src={staticFile(s.src)} volume={s.volume} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
