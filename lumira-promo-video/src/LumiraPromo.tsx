import {
  AbsoluteFill,
  Sequence,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {Audio} from '@remotion/media';
import {TransitionSeries, linearTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {slide} from '@remotion/transitions/slide';
import {wipe} from '@remotion/transitions/wipe';
import {flip} from '@remotion/transitions/flip';
import {clockWipe} from '@remotion/transitions/clock-wipe';
import {C} from './theme';
import {OpeningScene} from './scenes/OpeningScene';
import {HistoryScene} from './scenes/HistoryScene';
import {ElementsScene} from './scenes/ElementsScene';
import {WhyScene} from './scenes/WhyScene';
import {PivotScene} from './scenes/PivotScene';
import {BuildScene} from './scenes/BuildScene';
import {AppRevealScene} from './scenes/AppRevealScene';
import {PainpointsScene} from './scenes/PainpointsScene';
import {FeaturePoseScene} from './scenes/FeaturePoseScene';
import {FeatureCompositionScene} from './scenes/FeatureCompositionScene';
import {FeatureParamsScene} from './scenes/FeatureParamsScene';
import {MoreFeaturesScene} from './scenes/MoreFeaturesScene';
import {LinkScene} from './scenes/LinkScene';
import {SummaryScene} from './scenes/SummaryScene';
import {OutroScene} from './scenes/OutroScene';

const T = () => linearTiming({durationInFrames: 15});

// 全局音效锚点（帧），对应各场景边界与关键节拍
const SFX: {frame: number; src: string; volume: number}[] = [
  {frame: 0, src: 'sfx/riser.wav', volume: 0.5}, // 开场上升
  {frame: 95, src: 'sfx/ding.wav', volume: 0.4}, // 金句落定
  {frame: 165, src: 'sfx/whoosh.wav', volume: 0.4}, // → 简史
  {frame: 930, src: 'sfx/whoosh.wav', volume: 0.4}, // → 三要素
  {frame: 1725, src: 'sfx/pop.wav', volume: 0.35}, // → 为什么
  {frame: 2250, src: 'sfx/whoosh.wav', volume: 0.45}, // → 转折
  {frame: 2415, src: 'sfx/pop.wav', volume: 0.35}, // → VibeCoding
  {frame: 2700, src: 'sfx/whoosh.wav', volume: 0.5}, // → App亮相
  {frame: 2780, src: 'sfx/ding.wav', volume: 0.45}, // 「如画」落定
  {frame: 2925, src: 'sfx/pop.wav', volume: 0.4}, // → 痛点
  {frame: 3330, src: 'sfx/whoosh.wav', volume: 0.4}, // → 功能-姿势
  {frame: 3520, src: 'sfx/shutter.wav', volume: 0.5}, // 剪影→成片 快门
  {frame: 3795, src: 'sfx/pop.wav', volume: 0.35}, // → 功能-构图
  {frame: 4200, src: 'sfx/pop.wav', volume: 0.35}, // → 功能-参数
  {frame: 4605, src: 'sfx/whoosh.wav', volume: 0.35}, // → 更多功能
  {frame: 4980, src: 'sfx/whoosh.wav', volume: 0.4}, // → 关联
  {frame: 5400, src: 'sfx/ding.wav', volume: 0.45}, // 总结金句
  {frame: 5610, src: 'sfx/whoosh.wav', volume: 0.45}, // → 结尾
  {frame: 5730, src: 'sfx/ding.wav', volume: 0.4}, // CTA 落定
];

export const LumiraPromo: React.FC = () => {
  const {fps, durationInFrames, width, height} = useVideoConfig();
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{backgroundColor: C.bg0}}>
      <TransitionSeries>
        <TransitionSeries.Sequence name="开场" durationInFrames={180} premountFor={fps}>
          <OpeningScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={clockWipe({width, height})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="人像摄影简史" durationInFrames={780} premountFor={fps}>
          <HistoryScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={wipe({direction: 'from-left'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="三大要素" durationInFrames={810} premountFor={fps}>
          <ElementsScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={slide({direction: 'from-bottom'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="为什么需要" durationInFrames={540} premountFor={fps}>
          <WhyScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={flip({direction: 'from-left'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="转折" durationInFrames={180} premountFor={fps}>
          <PivotScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={wipe({direction: 'from-right'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="VibeCoding开发" durationInFrames={300} premountFor={fps}>
          <BuildScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={slide({direction: 'from-right'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="App亮相" durationInFrames={240} premountFor={fps}>
          <AppRevealScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={T()} />
        <TransitionSeries.Sequence name="痛点" durationInFrames={420} premountFor={fps}>
          <PainpointsScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={wipe({direction: 'from-top'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="功能-姿势" durationInFrames={480} premountFor={fps}>
          <FeaturePoseScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={slide({direction: 'from-right'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="功能-构图" durationInFrames={420} premountFor={fps}>
          <FeatureCompositionScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={wipe({direction: 'from-bottom'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="功能-参数" durationInFrames={420} premountFor={fps}>
          <FeatureParamsScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={T()} />
        <TransitionSeries.Sequence name="更多功能" durationInFrames={390} premountFor={fps}>
          <MoreFeaturesScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={slide({direction: 'from-left'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="关联" durationInFrames={300} premountFor={fps}>
          <LinkScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={flip({direction: 'from-right'})}
          timing={T()}
        />
        <TransitionSeries.Sequence name="总结" durationInFrames={360} premountFor={fps}>
          <SummaryScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={T()} />
        <TransitionSeries.Sequence name="结尾" durationInFrames={300} premountFor={fps}>
          <OutroScene />
        </TransitionSeries.Sequence>
      </TransitionSeries>

      {/* 全局音效层 */}
      {SFX.map((s, i) => (
        <Sequence key={i} from={s.frame} durationInFrames={60}>
          <Audio src={staticFile(s.src)} volume={s.volume} />
        </Sequence>
      ))}

      {/* 全局进度条 */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          bottom: 0,
          height: 4,
          width: (frame / durationInFrames) * width,
          background: `linear-gradient(90deg, ${C.purple}, ${C.gold})`,
          opacity: 0.7,
          pointerEvents: 'none',
        }}
      />
    </AbsoluteFill>
  );
};
