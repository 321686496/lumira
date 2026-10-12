import {Composition, Folder} from 'remotion';
import {LumiraPromo} from './LumiraPromo';
import {V2Promo} from './v2/V2Promo';
import {AtmoE01} from './atmo/AtmoE01';
import {Replay37E01} from './replay37/E01';
import {FactE01} from './facts/E01';
import {FactE02} from './facts/E02';
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

const W = 1920;
const H = 1080;
const FPS = 30;

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Folder name="Scenes">
        <Composition id="Opening" component={OpeningScene} width={W} height={H} fps={FPS} durationInFrames={180} />
        <Composition id="History" component={HistoryScene} width={W} height={H} fps={FPS} durationInFrames={780} />
        <Composition id="Elements" component={ElementsScene} width={W} height={H} fps={FPS} durationInFrames={810} />
        <Composition id="Why" component={WhyScene} width={W} height={H} fps={FPS} durationInFrames={540} />
        <Composition id="Pivot" component={PivotScene} width={W} height={H} fps={FPS} durationInFrames={180} />
        <Composition id="Build" component={BuildScene} width={W} height={H} fps={FPS} durationInFrames={300} />
        <Composition id="AppReveal" component={AppRevealScene} width={W} height={H} fps={FPS} durationInFrames={240} />
        <Composition id="Painpoints" component={PainpointsScene} width={W} height={H} fps={FPS} durationInFrames={420} />
        <Composition id="FeaturePose" component={FeaturePoseScene} width={W} height={H} fps={FPS} durationInFrames={480} />
        <Composition id="FeatureComposition" component={FeatureCompositionScene} width={W} height={H} fps={FPS} durationInFrames={420} />
        <Composition id="FeatureParams" component={FeatureParamsScene} width={W} height={H} fps={FPS} durationInFrames={420} />
        <Composition id="MoreFeatures" component={MoreFeaturesScene} width={W} height={H} fps={FPS} durationInFrames={390} />
        <Composition id="Link" component={LinkScene} width={W} height={H} fps={FPS} durationInFrames={300} />
        <Composition id="Summary" component={SummaryScene} width={W} height={H} fps={FPS} durationInFrames={360} />
        <Composition id="Outro" component={OutroScene} width={W} height={H} fps={FPS} durationInFrames={300} />
      </Folder>
      <Composition
        id="LumiraPromo"
        component={LumiraPromo}
        width={W}
        height={H}
        fps={FPS}
        durationInFrames={5910}
      />
      <Composition
        id="LumiraPromoV2"
        component={V2Promo}
        width={W}
        height={H}
        fps={FPS}
        durationInFrames={2475}
      />
      <Composition
        id="AtmoE01"
        component={AtmoE01}
        width={1080}
        height={1920}
        fps={FPS}
        durationInFrames={1050}
      />
      <Composition
        id="Replay37E01"
        component={Replay37E01}
        width={1080}
        height={1920}
        fps={FPS}
        durationInFrames={750}
      />
      <Composition
        id="FactE01"
        component={FactE01}
        width={1080}
        height={1920}
        fps={FPS}
        durationInFrames={750}
      />
      <Composition
        id="FactE02"
        component={FactE02}
        width={1080}
        height={1920}
        fps={FPS}
        durationInFrames={750}
      />
    </>
  );
};
