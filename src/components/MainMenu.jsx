import React, { useState } from 'react'
import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import MenuScene from './MenuScene'
import ChickenAmbientSounds from './ChickenAmbientSounds'

const MainMenu = ({ onStartGame }) => {
  const [gameMode, setGameMode] = useState(null) // 'single' or 'multi'
  const [selectedTeam, setSelectedTeam] = useState(null) // 'red' or 'blue' (for single player)
  const [showTeamSelection, setShowTeamSelection] = useState(false)

  const handleModeSelect = (mode) => {
    setGameMode(mode)
    if (mode === 'single') {
      setShowTeamSelection(true)
    } else {
      // For multiplayer, start game immediately
      onStartGame({
        mode: 'multi',
        playerTeam: null
      })
    }
  }

  const handleTeamSelect = (team) => {
    setSelectedTeam(team)
    onStartGame({
      mode: 'single',
      playerTeam: team
    })
  }

  const goBack = () => {
    setGameMode(null)
    setShowTeamSelection(false)
    setSelectedTeam(null)
  }

  return (
    <>
      <ChickenAmbientSounds isGameActive={true} winner={null} />
      
      <Canvas
        camera={{ position: [0, 8, 15], fov: 60 }}
        style={{ width: '100vw', height: '100vh' }}
      >
        <ambientLight intensity={0.8} />
        <directionalLight position={[10, 10, 5]} intensity={1.2} />
        <MenuScene />
        <OrbitControls
          enablePan={false}
          enableZoom={true}
          enableRotate={true}
          maxPolarAngle={Math.PI / 2.2}
          minDistance={8}
          maxDistance={25}
          autoRotate={true}
          autoRotateSpeed={0.5}
        />
      </Canvas>

      <div className="menu-ui">
        <div className="menu-header">
          <h1 className="menu-title">🐔 Chicken Pit 🕳️</h1>
          <p className="menu-subtitle">Tug O' War Championship</p>
        </div>

        {!showTeamSelection ? (
          <div className="menu-content">
            <div className="mode-selection">
              <h2>Choose Game Mode</h2>
              <div className="mode-buttons">
                <button 
                  className="mode-button single-player"
                  onClick={() => handleModeSelect('single')}
                >
                  <div className="mode-icon">🤖</div>
                  <div className="mode-title">Single Player</div>
                  <div className="mode-description">Play against AI chickens</div>
                </button>
                
                <button 
                  className="mode-button multi-player"
                  onClick={() => handleModeSelect('multi')}
                >
                  <div className="mode-icon">👥</div>
                  <div className="mode-title">Multiplayer</div>
                  <div className="mode-description">Play with friends</div>
                </button>
              </div>
            </div>

            <div className="menu-instructions">
              <h3>How to Play</h3>
              <div className="instruction-grid">
                <div className="instruction-item">
                  <span className="instruction-key">Red Team:</span>
                  <span>Q, W, E keys or Click button</span>
                </div>
                <div className="instruction-item">
                  <span className="instruction-key">Blue Team:</span>
                  <span>I, O, P keys or Click button</span>
                </div>
                <div className="instruction-item">
                  <span className="instruction-key">Goal:</span>
                  <span>Pull the rope to your side to win!</span>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="menu-content">
            <div className="team-selection">
              <h2>Choose Your Team</h2>
              <div className="team-buttons">
                <button 
                  className="team-button red-team"
                  onClick={() => handleTeamSelect('red')}
                >
                  <div className="team-icon">🐔</div>
                  <div className="team-name">Red Chickens</div>
                  <div className="team-description">Fierce and fearless</div>
                </button>
                
                <button 
                  className="team-button blue-team"
                  onClick={() => handleTeamSelect('blue')}
                >
                  <div className="team-icon">🐔</div>
                  <div className="team-name">Blue Chickens</div>
                  <div className="team-description">Strong and strategic</div>
                </button>
              </div>
              
              <button className="back-button" onClick={goBack}>
                ← Back to Mode Selection
              </button>
            </div>
          </div>
        )}

        <div className="menu-footer">
          <p>🎵 Use your volume controls for the best audio experience!</p>
        </div>
      </div>
    </>
  )
}

export default MainMenu
