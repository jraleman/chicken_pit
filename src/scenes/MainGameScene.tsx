import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import GameDialog from '../components/GameDialog';
import { type GameSettingsData } from '../components/GameSettings';
import { LEFT_TEAM_CONTROLS, RIGHT_TEAM_CONTROLS, MULTIPLAYER_LEFT_LABEL, MULTIPLAYER_RIGHT_LABEL, LEFT_TEAM_LABEL, RIGHT_TEAM_LABEL, GAME_WINS_NEEDED } from '../contants';
import Post from '../models/Post';
import Rope from '../models/Rope';
import Chicken from '../models/Chicken';
import Barn from '../models/Barn';

interface MainGameSceneProps {
  team: 'left' | 'right';
  settings: GameSettingsData;
  onRestart: () => void;
}

const MainGameScene: React.FC<MainGameSceneProps> = ({
  team,
  settings,
  onRestart,
}) => {
  const [ropePos, setRopePos] = useState(0);
  const [winner, setWinner] = useState<string | null>(null);
  const [leftTeamPulling, setLeftTeamPulling] = useState(false);
  const [rightTeamPulling, setRightTeamPulling] = useState(false);
  const [cameraRotation, setCameraRotation] = useState(0); // Horizontal rotation in radians
  const [leftWins, setLeftWins] = useState(0);
  const [rightWins, setRightWins] = useState(0);
  const [overallWinner, setOverallWinner] = useState<string | null>(null);
  const limit = settings.ropeLength / 2;
  const isMultiplayer = settings.gameMode === 'multiplayer';
  
  // Camera rotation limits (in radians)
  const MAX_CAMERA_ROTATION = Math.PI / 3; // 60 degrees
  const CAMERA_ROTATION_SPEED = 0.2;

  // Function to restart the round (reset rope position and winner)
  const restartRound = useCallback(() => {
    setRopePos(0);
    setWinner(null);
    setLeftTeamPulling(false);
    setRightTeamPulling(false);
  }, []);

  // Camera controller component
  const CameraController = () => {
    const { camera } = useThree();
    const cameraRef = useRef(cameraRotation);
    
    // Update ref when state changes
    useFrame(() => {
      // Update the ref with the current state value
      cameraRef.current = cameraRotation;
      
      // Update camera position based on rotation
      const radius = 5; // Distance from center
      const height = 2; // Camera height
      
      camera.position.x = Math.sin(cameraRef.current) * radius;
      camera.position.z = Math.cos(cameraRef.current) * radius;
      camera.position.y = height;
      
      // Always look at the center of the scene
      camera.lookAt(0, 0, 0);
    });
    
    return null;
  };

  // user pulls and camera controls
  useEffect(() => {
    const keydownHandler = (e: KeyboardEvent) => {
      if (winner) return;
      
      // Camera controls with arrow keys
      if (e.key === 'ArrowLeft') {
        setCameraRotation(prev => Math.max(prev - CAMERA_ROTATION_SPEED, -MAX_CAMERA_ROTATION));
        return;
      }
      if (e.key === 'ArrowRight') {
        setCameraRotation(prev => Math.min(prev + CAMERA_ROTATION_SPEED, MAX_CAMERA_ROTATION));
        return;
      }
      
      // Game controls
      if (isMultiplayer) {
        // In multiplayer mode, both teams can be controlled
        if (LEFT_TEAM_CONTROLS.includes(e.key)) {
          setRopePos(p => Math.min(p + 0.15, limit));
          setLeftTeamPulling(true);
        }
        if (RIGHT_TEAM_CONTROLS.includes(e.key)) {
          setRopePos(p => Math.max(p - 0.15, -limit));
          setRightTeamPulling(true);
        }
      } else {
        // In singleplayer mode, only the selected team can be controlled
        if (team === 'left' && LEFT_TEAM_CONTROLS.includes(e.key)) {
          setRopePos(p => Math.min(p + 0.15, limit));
          setLeftTeamPulling(true);
        }
        if (team === 'right' && RIGHT_TEAM_CONTROLS.includes(e.key)) {
          setRopePos(p => Math.max(p - 0.15, -limit));
          setRightTeamPulling(true);
        }
      }
    };

    const keyupHandler = (e: KeyboardEvent) => {
      if (winner) return;
      
      // Only handle game controls on keyup (not camera controls)
      if (isMultiplayer) {
        if (LEFT_TEAM_CONTROLS.includes(e.key)) {
          setLeftTeamPulling(false);
        }
        if (RIGHT_TEAM_CONTROLS.includes(e.key)) {
          setRightTeamPulling(false);
        }
      } else {
        if (team === 'left' && LEFT_TEAM_CONTROLS.includes(e.key)) {
          setLeftTeamPulling(false);
        }
        if (team === 'right' && RIGHT_TEAM_CONTROLS.includes(e.key)) {
          setRightTeamPulling(false);
        }
      }
    };

    window.addEventListener('keydown', keydownHandler);
    window.addEventListener('keyup', keyupHandler);
    return () => {
      window.removeEventListener('keydown', keydownHandler);
      window.removeEventListener('keyup', keyupHandler);
    };
  }, [team, winner, limit, isMultiplayer, MAX_CAMERA_ROTATION, CAMERA_ROTATION_SPEED]);

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
      
      // Set CPU pulling animation
      if (team === 'left') {
        setRightTeamPulling(Math.random() > 0.7); // Random pulling animation for CPU
      } else {
        setLeftTeamPulling(Math.random() > 0.7); // Random pulling animation for CPU
      }
    });
    return null;
  };

  // check victory
  useEffect(() => {
    if (winner || overallWinner) return; // Don't check if already won or overall winner decided
    
    if (ropePos >= limit) {
      if (isMultiplayer) {
        setWinner(LEFT_TEAM_LABEL);
        const newLeftWins = leftWins + 1;
        setLeftWins(newLeftWins);
        
        if (newLeftWins >= GAME_WINS_NEEDED) {
          setOverallWinner(LEFT_TEAM_LABEL);
        } else {
          // Restart round after a short delay
          setTimeout(restartRound, 1500);
        }
      } else {
        const playerWon = team === 'left';
        setWinner(playerWon ? 'You' : 'CPU');
        
        if (playerWon) {
          const newLeftWins = leftWins + 1;
          setLeftWins(newLeftWins);
          if (newLeftWins >= GAME_WINS_NEEDED) {
            setOverallWinner('You');
          } else {
            setTimeout(restartRound, 1500);
          }
        } else {
          const newRightWins = rightWins + 1;
          setRightWins(newRightWins);
          if (newRightWins >= GAME_WINS_NEEDED) {
            setOverallWinner('CPU');
          } else {
            setTimeout(restartRound, 1500);
          }
        }
      }
    }
    
    if (ropePos <= -limit) {
      if (isMultiplayer) {
        setWinner(RIGHT_TEAM_LABEL);
        const newRightWins = rightWins + 1;
        setRightWins(newRightWins);
        
        if (newRightWins >= GAME_WINS_NEEDED) {
          setOverallWinner(RIGHT_TEAM_LABEL);
        } else {
          // Restart round after a short delay
          setTimeout(restartRound, 1500);
        }
      } else {
        const playerWon = team === 'right';
        setWinner(playerWon ? 'You' : 'CPU');
        
        if (playerWon) {
          const newRightWins = rightWins + 1;
          setRightWins(newRightWins);
          if (newRightWins >= GAME_WINS_NEEDED) {
            setOverallWinner('You');
          } else {
            setTimeout(restartRound, 1500);
          }
        } else {
          const newLeftWins = leftWins + 1;
          setLeftWins(newLeftWins);
          if (newLeftWins >= GAME_WINS_NEEDED) {
            setOverallWinner('CPU');
          } else {
            setTimeout(restartRound, 1500);
          }
        }
      }
    }
  }, [ropePos, team, limit, isMultiplayer, winner, overallWinner, leftWins, rightWins, GAME_WINS_NEEDED, restartRound]);

  const showScoreDisplay = false;

  return (
    <div className={`scene main-game ${isMultiplayer ? 'multiplayer-mode' : ''}`}>
      <Canvas camera={{ position: [0, 2, 5]}}>
        <ambientLight intensity={0.5} />
        <directionalLight position={[5, 8, 5]} />
        
        {/* Background barn */}
        <Barn 
          position={[0, 0, -15]} 
          scale={2}
        />
        
        <Post position={[-limit, 0, 0]} />
        <Post position={[ limit, 0, 0]} />
        <Rope
          ropeLength={settings.ropeLength}
          color={settings.ropeColor}
          ropePos={ropePos}
        />
        {/* Left team chicken */}
        <Chicken 
          position={[-limit - 1, 0, 0]} 
          team="left" 
          isPulling={leftTeamPulling}
          color={settings.leftTeamColor}
        />
        {/* Right team chicken */}
        <Chicken 
          position={[limit + 1, 0, 0]} 
          team="right" 
          isPulling={rightTeamPulling}
          color={settings.rightTeamColor}
        />
        <CameraController />
        <CPUPuller />
      </Canvas>

      {/* Win counter display */}
      {showScoreDisplay && (
        <div className="win-counter" style={{ 
          position: 'absolute', 
          top: '20px', 
          left: '50%', 
          transform: 'translateX(-50%)', 
          color: 'white', 
          fontSize: '1.2em', 
          fontWeight: 'bold',
          textShadow: '2px 2px 4px rgba(0,0,0,0.8)',
          zIndex: 100
        }}>
          {isMultiplayer ? (
            <span>{LEFT_TEAM_LABEL}: {leftWins} | {RIGHT_TEAM_LABEL}: {rightWins}</span>
          ) : (
            <span>You: {team === 'left' ? leftWins : rightWins} | CPU: {team === 'left' ? rightWins : leftWins}</span>
          )}
          <div style={{ fontSize: '0.8em', opacity: 0.8, textAlign: 'center' }}>
            First to {GAME_WINS_NEEDED} wins!
          </div>
        </div>
      )}

      {/* Round winner display */}
      {winner && !overallWinner && (
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          color: 'white',
          fontSize: '2em',
          fontWeight: 'bold',
          textShadow: '2px 2px 4px rgba(0,0,0,0.8)',
          textAlign: 'center',
          zIndex: 200
        }}>
          {winner} won this round!
        </div>
      )}

      {!winner && !overallWinner ? (
        <div className="instructions">
          {isMultiplayer ? (
            <p>
              <strong>{MULTIPLAYER_LEFT_LABEL}</strong><br />
              <strong>{MULTIPLAYER_RIGHT_LABEL}</strong><br />
              <span style={{ fontSize: '0.9em', opacity: 0.8 }}>Use ← → arrow keys to rotate camera</span>
            </p>
          ) : (
            <p>
              Press <strong>{team === 'left' ? 'Q / A' : 'P / L'}</strong> to pull!<br />
              <span style={{ fontSize: '0.9em', opacity: 0.8 }}>Use ← → arrow keys to rotate camera</span>
            </p>
          )}
        </div>
      ) : overallWinner ? (
        <GameDialog
          message={`${overallWinner} won! They are the ${GAME_WINS_NEEDED} rounds champion!`}
          onClose={onRestart}
        />
      ) : null}
    </div>
  );
};

export default MainGameScene;