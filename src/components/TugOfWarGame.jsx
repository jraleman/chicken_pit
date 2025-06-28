import React, { useState, useRef, useEffect } from 'react'
import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import TugOfWarScene from './TugOfWarScene'
import AudioManager from './AudioManager'
import ChickenAmbientSounds from './ChickenAmbientSounds'
import DramaticSoundEffects from './DramaticSoundEffects'

const TugOfWarGame = ({ gameConfig, onReturnToMenu }) => {
  const [ropePosition, setRopePosition] = useState(0) // -5 to 5, 0 is center
  const [redStrength, setRedStrength] = useState(0)
  const [blueStrength, setBlueStrength] = useState(0)
  const [winner, setWinner] = useState(null)
  const [isGameActive, setIsGameActive] = useState(true)
  
  const strengthDecayRef = useRef()
  const aiRef = useRef()

  // AI for single player mode
  useEffect(() => {
    if (gameConfig?.mode === 'single') {
      aiRef.current = setInterval(() => {
        if (!isGameActive) return
        
        const aiTeam = gameConfig.playerTeam === 'red' ? 'blue' : 'red'
        const aiStrength = aiTeam === 'red' ? redStrength : blueStrength
        const playerStrength = aiTeam === 'red' ? blueStrength : redStrength
        
        // AI strategy: more aggressive when losing, more defensive when winning
        const strengthDifference = playerStrength - aiStrength
        const aiAggressiveness = Math.max(0.1, 0.5 + strengthDifference * 0.01)
        
        if (Math.random() < aiAggressiveness) {
          if (aiTeam === 'red') {
            setRedStrength(prev => Math.min(100, prev + 0.3))
          } else {
            setBlueStrength(prev => Math.min(100, prev + 0.3))
          }
        }
      }, 200 + Math.random() * 300) // Random timing between 200-500ms
      
      return () => clearInterval(aiRef.current)
    }
  }, [gameConfig, isGameActive, redStrength, blueStrength])

  // Decay strength over time
  useEffect(() => {
    strengthDecayRef.current = setInterval(() => {
      setRedStrength(prev => Math.max(0, prev - 1))
      setBlueStrength(prev => Math.max(0, prev - 1))
    }, 100)

    return () => clearInterval(strengthDecayRef.current)
  }, [])

  // Keyboard event handlers
  useEffect(() => {
    const handleKeyPress = (event) => {
      if (!isGameActive) return

      const key = event.key.toLowerCase()
      
      // Red chickens keys: Q, W, E
      if (key === 'q' || key === 'w' || key === 'e') {
        // In single player mode, only allow the player's team
        if (gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'red') return
        handleRedPull()
      }
      // Blue chickens keys: I, O, P
      else if (key === 'i' || key === 'o' || key === 'p') {
        // In single player mode, only allow the player's team
        if (gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'blue') return
        handleBluePull()
      }
    }

    window.addEventListener('keydown', handleKeyPress)
    
    return () => {
      window.removeEventListener('keydown', handleKeyPress)
    }
  }, [isGameActive, gameConfig])

  // Update rope position based on strength difference
  useEffect(() => {
    if (!isGameActive) return

    const strengthDiff = blueStrength - redStrength
    const newPosition = ropePosition + (strengthDiff * 0.01)
    const clampedPosition = Math.max(-11, Math.min(11, newPosition))
    
    setRopePosition(clampedPosition)

    // Check for winner
    if (clampedPosition <= -10.5) {
      setWinner('Red Chickens')
      setIsGameActive(false)
    } else if (clampedPosition >= 10.5) {
      setWinner('Blue Chickens')
      setIsGameActive(false)
    }
  }, [redStrength, blueStrength, ropePosition, isGameActive])

  const handleRedPull = () => {
    if (!isGameActive) return
    // In single player mode, only allow the player's team to be controlled
    if (gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'red') return
    setRedStrength(prev => Math.min(100, prev + 0.25))
  }

  const handleBluePull = () => {
    if (!isGameActive) return
    // In single player mode, only allow the player's team to be controlled
    if (gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'blue') return
    setBlueStrength(prev => Math.min(100, prev + 0.25))
  }

  const resetGame = () => {
    setRopePosition(0)
    setRedStrength(0)
    setBlueStrength(0)
    setWinner(null)
    setIsGameActive(true)
  }

  const getPositionText = () => {
    if (ropePosition < -2) return "Red Chickens Advantage! 🐔💪"
    if (ropePosition > 2) return "Blue Chickens Advantage! 🐔💪"
    return "Even Match! 🐔⚖️🐔"
  }

  return (
    <>
      <AudioManager
        redStrength={redStrength}
        blueStrength={blueStrength}
        winner={winner}
        isGameActive={isGameActive}
        ropePosition={ropePosition}
      />
      
      <ChickenAmbientSounds
        isGameActive={isGameActive}
        winner={winner}
      />
      
      <DramaticSoundEffects
        ropePosition={ropePosition}
        isGameActive={isGameActive}
        winner={winner}
      />
      
      <Canvas
        camera={{ position: [0, 5, 10], fov: 60 }}
        style={{ width: '100vw', height: '100vh' }}
      >
        <ambientLight intensity={0.6} />
        <directionalLight position={[10, 10, 5]} intensity={1} />
        <TugOfWarScene 
          ropePosition={ropePosition} 
          winner={winner} 
          isGameActive={isGameActive} 
          redStrength={redStrength}
          blueStrength={blueStrength}
        />
        <OrbitControls
          enablePan={false}
          enableZoom={true}
          enableRotate={true}
          maxPolarAngle={Math.PI / 2}
          minDistance={5}
          maxDistance={20}
        />
      </Canvas>

      <div className="game-ui">
        <div className="game-header">
          <h1 className="game-title">🐔 Chicken Pit 🕳️ ☠️</h1>
          <div className="game-mode">
            {gameConfig?.mode === 'single' 
              ? `Single Player - You are ${gameConfig.playerTeam === 'red' ? 'Red' : 'Blue'} Team` 
              : 'Multiplayer Mode'
            }
          </div>
          <div className="game-status">{getPositionText()}</div>
        </div>

        <div className="info-panel">
          <h4>📊 Game Stats</h4>
          <div className="info-item">
            <span>Red Power:</span>
            <span>{redStrength.toFixed(0)}</span>
          </div>
          <div className="info-item">
            <span>Blue Power:</span>
            <span>{blueStrength.toFixed(0)}</span>
          </div>
          <div className="info-item">
            <span>Rope Pos:</span>
            <span>{ropePosition.toFixed(1)}</span>
          </div>
          <div className="info-item">
            <span>Status:</span>
            <span style={{ color: isGameActive ? '#4caf50' : '#f44336' }}>
              {isGameActive ? 'Active' : 'Paused'}
            </span>
          </div>
        </div>

        <div className="controls">
          <div className="team-controls team-red">
            <div className="team-name">
              🐔 Red Chickens
              {gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'red' && (
                <span className="ai-indicator"> (AI)</span>
              )}
            </div>
            <button 
              className="pull-button" 
              onClick={handleRedPull} 
              disabled={!isGameActive || (gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'red')}
            >
              Pull!
            </button>
            <div className="keyboard-controls">
              {gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'red' 
                ? 'AI Controlled' 
                : 'Keys: Q, W, E'
              }
            </div>
            <div className="strength-meter">
              <div 
                className="strength-fill" 
                style={{ width: `${redStrength}%` }}
              />
            </div>
            <div style={{ fontSize: '0.8rem' }}>Power: {redStrength.toFixed(0)}</div>
          </div>

          <div className="center-indicator">
            <div className="rope-position">
              Center: {ropePosition.toFixed(1)}
            </div>
            <button className="reset-button" onClick={resetGame}>
              Reset
            </button>
            <button className="menu-button" onClick={onReturnToMenu}>
              Main Menu
            </button>
          </div>

          <div className="team-controls team-blue">
            <div className="team-name">
              🐔 Blue Chickens
              {gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'blue' && (
                <span className="ai-indicator"> (AI)</span>
              )}
            </div>
            <button 
              className="pull-button" 
              onClick={handleBluePull} 
              disabled={!isGameActive || (gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'blue')}
            >
              Pull!
            </button>
            <div className="keyboard-controls">
              {gameConfig?.mode === 'single' && gameConfig.playerTeam !== 'blue' 
                ? 'AI Controlled' 
                : 'Keys: I, O, P'
              }
            </div>
            <div className="strength-meter">
              <div 
                className="strength-fill" 
                style={{ width: `${blueStrength}%` }}
              />
            </div>
            <div style={{ fontSize: '0.8rem' }}>Power: {blueStrength.toFixed(0)}</div>
          </div>
        </div>
      </div>

      {winner && (
        <div className="winner-announcement">
          🎉 {winner.replace('Team', 'Chickens')} Win! 🐔👑 🎉
        </div>
      )}
    </>
  )
}

export default TugOfWarGame
