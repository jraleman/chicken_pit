import React, { useRef, useState, useEffect } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import GameDialog from '../components/GameDialog';
import { type GameSettingsData } from '../components/GameSettings';
import { Mesh } from 'three';

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

/**
 * Third-person vs CPU tug-o-war. You press “A” or “L” to pull.
 */
const MainGameScene: React.FC<MainGameSceneProps> = ({
  team,
  settings,
  onRestart,
}) => {
  const [ropePos, setRopePos] = useState(0);
  const [winner, setWinner] = useState<string | null>(null);
  const limit = settings.ropeLength / 2;

  // user pulls
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (winner) return;
      if (team === 'left' && e.key === 'a') {
        setRopePos(p => Math.min(p + 0.15, limit));
      }
      if (team === 'right' && e.key === 'l') {
        setRopePos(p => Math.max(p - 0.15, -limit));
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [team, winner, limit]);

  // CPU pulls every frame
  const CPUPuller = () => {
    useFrame((_, delta) => {
      if (winner) return;
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
      setWinner(team === 'left' ? 'You' : 'CPU');
    }
    if (ropePos <= -limit) {
      setWinner(team === 'right' ? 'You' : 'CPU');
    }
  }, [ropePos, team, limit]);

  return (
    <div className="scene main-game">
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
          <p>
            Press <strong>{team === 'left' ? 'A' : 'L'}</strong> to pull!
          </p>
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