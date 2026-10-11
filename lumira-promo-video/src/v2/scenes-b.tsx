import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {V} from './theme';
import {Paper, StickyCap, Stamp} from './ink';
import {OldAlbum, Camera1839, Camera1900, Fashion1950} from './props';
import {LightIllust, GridIllust, EmotionIllust} from './elements';
import {InkSparkles} from './portrait';

/* ========================= S3 翻相册学历史（420帧 = 14s） ========================= */
export const V2AlbumScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  // 三节点依次出现（前 120 帧是相册本体）
  const nodes = [
    {at: 130, x: 60, rot: -2, Cam: Camera1839, tag: '1839', txt: '曝光 8 分钟'},
    {at: 250, x: 700, rot: 2, Cam: Camera1900, tag: '1900', txt: '你只管按'},
    {at: 370 - 60, x: 1340, rot: -2, Cam: Fashion1950, tag: '1950s', txt: '拍照成了学问'},
  ];
  return (
    <AbsoluteFill>
      <Paper>
        {/* 相册：开场上半段居中，随后缩小上移让位 */}
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: interpolate(frame, [0, 110], ['47%', '24%']),
            width: interpolate(frame, [0, 110], [880, 560]),
            height: interpolate(frame, [0, 110], [660, 420]),
            transform: 'translate(-50%,-50%)',
          }}
        >
          <OldAlbum frame={frame} start={0} speed={0.9} />
        </div>

        {/* 三个历史节点 */}
        {nodes.map(({at, x, rot, Cam, tag, txt}, i) => {
          const op = interpolate(frame, [at, at + 14], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
          return (
            <div
              key={i}
              style={{
                position: 'absolute',
                left: x,
                top: 470,
                width: 480,
                height: 480,
                opacity: op,
                transform: `rotate(${rot}deg)`,
              }}
            >
              <Cam frame={frame} start={at} speed={0.75} />
              <div style={{position: 'absolute', right: 20, top: 30, textAlign: 'right'}}>
                <Stamp text={tag} frame={frame} fps={fps} start={at + 16} size={72} color={V.goldDeep} />
                <div style={{fontSize: 40, fontWeight: 700, color: V.inkSoft, marginTop: 10}}>{txt}</div>
              </div>
            </div>
          );
        })}

        <StickyCap text="后来我翻了一百年的照片" frame={frame} fps={fps} start={30} duration={105} highlight={['一百年']} />
        <StickyCap text="从曝光八分钟，到「你只管按快门」" frame={frame} fps={fps} start={150} duration={135} rotate={1} highlight={['你只管按快门']} />
        <StickyCap text="时尚大片，把拍照变成了一门学问" frame={frame} fps={fps} start={300} duration={118} rotate={-1} highlight={['学问']} />
      </Paper>
    </AbsoluteFill>
  );
};

/* ========================= S4 三件事（480帧 = 16s） ========================= */
export const V2ThreeThingsScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const items = [
    {at: 60, x: 130, Illust: LightIllust, name: '光线', desc: '影调和氛围，都是光给的'},
    {at: 210, x: 720, Illust: GridIllust, name: '构图', desc: '她该站在画面的哪里'},
    {at: 360, x: 1310, Illust: EmotionIllust, name: '情绪', desc: '眼里有光，嘴角有笑'},
  ];
  return (
    <AbsoluteFill>
      <Paper>
        <InkSparkles
          frame={frame}
          fps={fps}
          start={70}
          svgWidth={1920}
          svgHeight={1080}
          points={[[500, 180, 6], [960, 140, 5], [1430, 190, 6]]}
        />
        {/* 标题盖章 */}
        <div style={{position: 'absolute', left: '50%', top: 90, transform: 'translateX(-50%)'}}>
          <Stamp text="把人拍好看，就三件事" frame={frame} fps={fps} start={10} size={84} color={V.ink} />
        </div>
        {items.map(({at, x, Illust, name, desc}, i) => (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: 260,
              width: 480,
              height: 620,
              opacity: interpolate(frame, [at, at + 12], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}),
            }}
          >
            <div style={{width: 480, height: 460}}>
              <Illust frame={frame} start={at} speed={0.7} />
            </div>
            <div style={{textAlign: 'center', marginTop: 6}}>
              <span
                style={{
                  fontSize: 62,
                  fontWeight: 900,
                  color: V.goldDeep,
                  borderBottom: `5px solid ${V.gold}`,
                  paddingBottom: 6,
                }}
              >
                {name}
              </span>
              <div style={{fontSize: 36, color: V.inkSoft, marginTop: 18, fontWeight: 600}}>{desc}</div>
            </div>
          </div>
        ))}
        <StickyCap text="一百年来，好看的人像都没绕开这三件事" frame={frame} fps={fps} start={100} duration={145} highlight={['三件事']} />
        <StickyCap text="光线、构图、情绪——听起来也就三个词" frame={frame} fps={fps} start={265} duration={120} rotate={1} highlight={['三个词']} />
        <StickyCap text="但每一个词背后，都藏着一套功课" frame={frame} fps={fps} start={400} duration={78} rotate={-0.8} highlight={['功课']} />
      </Paper>
    </AbsoluteFill>
  );
};
