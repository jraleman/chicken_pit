import React, { useRef, useState, useEffect } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import GameDialog from '../components/GameDialog';
import { type GameSettingsData } from '../components/GameSettings';
import { Mesh } from 'three';
import { LEFT_TEAM_CONTROLS, RIGHT_TEAM_CONTROLS, MULTIPLAYER_LEFT_LABEL, MULTIPLAYER_RIGHT_LABEL } from '../contants';

interface MainGameSceneProps {
  team: 'left' | 'right';
  settings: GameSettingsData;
  onRestart: () => void;
}

const Post: React.FC<{ position: [number, number, number] }> = ({ position }) => (
  <mesh position={position}>
    <boxGeometry args={[0.2, 1, 0.2]} />
    <meshStandardMaterial color="gray" />
  </mesh>
);

const Rope: React.FC<{
  ropeLength: number;
  color: string;
  ropePos: number;
}> = ({ ropeLength, color, ropePos }) => {
  const ref = useRef<Mesh>(null!);
  useFrame(() => {
    if (ref.current) {
      ref.current.position.x = ropePos;
    }
  });
  return (
    <mesh ref={ref}>
      <cylinderGeometry args={[0.05, 0.05, ropeLength, 12]} />
      <meshStandardMaterial color={color} />
    </mesh>
  );
};


const MainGameScene: React.FC<MainGameSceneProps> = ({
  team,
  settings,
  onRestart,
}) => {
  const [ropePos, setRopePos] = useState(0);
  const [winner, setWinner] = useState<string | null>(null);
  const limit = settings.ropeLength / 2;
  const isMultiplayer = settings.gameMode === 'multiplayer';

  // user pulls - in multiplayer, both teams are controlled by players
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (winner) return;
      
      if (isMultiplayer) {
        // In multiplayer mode, both teams can be controlled
        if (LEFT_TEAM_CONTROLS.includes(e.key)) {
          setRopePos(p => Math.min(p + 0.15, limit));
        }
        if (RIGHT_TEAM_CONTROLS.includes(e.key)) {
          setRopePos(p => Math.max(p - 0.15, -limit));
        }
      } else {
        // In singleplayer mode, only the selected team can be controlled
        if (team === 'left' && LEFT_TEAM_CONTROLS.includes(e.key)) {
          setRopePos(p => Math.min(p + 0.15, limit));
        }
        if (team === 'right' && RIGHT_TEAM_CONTROLS.includes(e.key)) {
          setRopePos(p => Math.max(p - 0.15, -limit));
        }
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [team, winner, limit, isMultiplayer]);

  // CPU pulls every frame - only in singleplayer mode
  const CPUPuller = () => {
    useFrame((_, delta) => {
      if (winner || isMultiplayer) return; // Don't run CPU in multiplayer mode
      const force = 0.5 * delta;
      setRopePos(p =>
        team === 'left'
          ? Math.max(p - force, -limit)
          : Math.min(p + force, limit)
      );
    });
    return null;
  };

  // check victory
  useEffect(() => {
    if (ropePos >= limit) {
      if (isMultiplayer) {
        setWinner('Left Team');
      } else {
        setWinner(team === 'left' ? 'You' : 'CPU');
      }
    }
    if (ropePos <= -limit) {
      if (isMultiplayer) {
        setWinner('Right Team');
      } else {
        setWinner(team === 'right' ? 'You' : 'CPU');
      }
    }
  }, [ropePos, team, limit, isMultiplayer]);

  return (
    <div className={`scene main-game ${isMultiplayer ? 'multiplayer-mode' : ''}`}>
      <Canvas camera={{ position: [0, 2, 5] }}>
        <ambientLight intensity={0.5} />
        <directionalLight position={[5, 8, 5]} />
        <Post position={[-limit, 0, 0]} />
        <Post position={[ limit, 0, 0]} />
        <Rope
          ropeLength={settings.ropeLength}
          color={settings.ropeColor}
          ropePos={ropePos}
        />
        <CPUPuller />
      </Canvas>

      {!winner ? (
        <div className="instructions">
          {isMultiplayer ? (
            <p>
              <strong>{MULTIPLAYER_LEFT_LABEL}</strong><br />
              <strong>{MULTIPLAYER_RIGHT_LABEL}</strong>
            </p>
          ) : (
            <p>
              Press <strong>{team === 'left' ? 'A' : 'L'}</strong> to pull!
            </p>
          )}
        </div>
      ) : (
        <GameDialog
          message={`${winner} win the tug-o-war!`}
          onClose={onRestart}
        />
      )}
    </div>
  );
};

export default MainGameScene;