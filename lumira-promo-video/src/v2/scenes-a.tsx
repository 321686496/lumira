import React from 'react';
import {AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {V} from './theme';
import {Paper, Stamp, StickyCap, breathe, DrawOnImage} from './ink';
import {InkSparkles} from './portrait';
import {Polaroid, ShotClosedEyes, ShotTilted, ShotStiff} from './props';

/* ============================ S1 钩子（90帧 = 3s） ============================ */
export const V2HookScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return (
    <AbsoluteFill>
      <Paper>
        {/* 少女：生图线稿，1.5s 内"手绘"完成 */}
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: '47%',
            transform: `translate(-50%,-50%) translateY(${breathe(frame, 5)}px)`,
          }}
        >
          <DrawOnImage
            src="v2/girl-line.png"
            frame={frame}
            start={2}
            duration={44}
            width={560}
            height={560}
          />
        </div>
        <InkSparkles
          frame={frame}
          fps={fps}
          start={40}
          svgWidth={1920}
          svgHeight={1080}
          points={[
            [420, 300, 6],
            [1480, 260, 7],
            [1340, 720, 5],
            [540, 760, 6],
            [1600, 520, 5],
            [330, 540, 5],
          ]}
        />
        {/* 盖章钩子 */}
        <div style={{position: 'absolute', left: 150, top: 210, transform: 'rotate(-4deg)'}}>
          <Stamp text="这张照片" frame={frame} fps={fps} start={56} size={110} color={V.ink} />
        </div>
        <div style={{position: 'absolute', left: 170, top: 360, transform: 'rotate(-4deg)'}}>
          <Stamp text="我重拍了 37 次" frame={frame} fps={fps} start={64} size={110} color={V.red} border />
        </div>
        <StickyCap
          text="所以，好看的人像到底难在哪？"
          frame={frame}
          fps={fps}
          start={20}
          duration={62}
          highlight={['难在哪']}
        />
      </Paper>
    </AbsoluteFill>
  );
};

/* ========================== S2 翻车日记（330帧 = 11s） ========================== */
export const V2FailDiaryScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const float = breathe(frame, 8, 0.025);
  const guyIn = interpolate(frame, [16, 40], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <AbsoluteFill>
      <Paper>
        {/* 标题：手写风 */}
        <div style={{position: 'absolute', left: 130, top: 100}}>
          <div
            style={{
              fontSize: 64,
              fontWeight: 800,
              color: V.ink,
              opacity: interpolate(frame, [10, 26], [0, 1], {extrapolateRight: 'clamp'}),
            }}
          >
            我的拍照翻车日记
          </div>
          <svg width={430} height={20} viewBox="0 0 430 20">
            <path
              d="M4 12 Q120 4 240 10 T426 8"
              fill="none"
              stroke={V.goldDeep}
              strokeWidth={5}
              strokeLinecap="round"
              pathLength={1}
              strokeDasharray={1}
              strokeDashoffset={interpolate(frame, [16, 40], [1, 0], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              })}
            />
          </svg>
        </div>

        {/* 左：摄影者（生图素材，multiply 融入纸底） */}
        <div
          style={{
            position: 'absolute',
            left: 90,
            top: 290,
            width: 460,
            height: 460,
            transform: `translateY(${(1 - guyIn) * 60 + float}px)`,
            opacity: guyIn,
          }}
        >
          <Img
            src={staticFile('v2/cameraman.png')}
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'contain',
              mixBlendMode: 'multiply',
            }}
          />
        </div>

        {/* 右：三张废片 */}
        <div style={{position: 'absolute', left: 620, top: 250}}>
          <Polaroid frame={frame} start={110} fps={fps} rotate={-5}>
            <ShotClosedEyes frame={frame} start={122} />
          </Polaroid>
        </div>
        <div style={{position: 'absolute', left: 990, top: 210}}>
          <Polaroid frame={frame} start={205} fps={fps} rotate={3}>
            <ShotTilted frame={frame} start={217} />
          </Polaroid>
        </div>
        <div style={{position: 'absolute', left: 1360, top: 260}}>
          <Polaroid frame={frame} start={300} fps={fps} rotate={-2}>
            <ShotStiff frame={frame} start={312} />
          </Polaroid>
        </div>

        <StickyCap
          text="我喜欢给人拍照，真的"
          frame={frame}
          fps={fps}
          start={24}
          duration={95}
          highlight={['喜欢']}
        />
        <StickyCap
          text="可交出去的，常常是这三张"
          frame={frame}
          fps={fps}
          start={135}
          duration={125}
          rotate={1}
          highlight={['这三张']}
        />
        <StickyCap
          text="闭眼的、歪的、僵的……十次里八次差点意思"
          frame={frame}
          fps={fps}
          start={275}
          duration={52}
          rotate={-0.8}
          highlight={['差点意思']}
        />
      </Paper>
    </AbsoluteFill>
  );
};
