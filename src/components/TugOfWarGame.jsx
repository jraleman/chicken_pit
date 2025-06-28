import React, { useState, useRef, useEffect } from 'react'
import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import TugOfWarScene from './TugOfWarScene'

const TugOfWarGame = () => {
  const [ropePosition, setRopePosition] = useState(0) // -5 to 5, 0 is center
  const [redStrength, setRedStrength] = useState(0)
  const [blueStrength, setBlueStrength] = useState(0)
  const [winner, setWinner] = useState(null)
  const [isGameActive, setIsGameActive] = useState(true)
  
  const strengthDecayRef = useRef()

  // Decay strength over time
  useEffect(() => {
    strengthDecayRef.current = setInterval(() => {
      setRedStrength(prev => Math.max(0, prev - 1))
      setBlueStrength(prev => Math.max(0, prev - 1))
    }, 100)

    return () => clearInterval(strengthDecayRef.current)
  }, [])

  // Update rope position based on strength difference
  useEffect(() => {
    if (!isGameActive) return

    const strengthDiff = blueStrength - redStrength
    const newPosition = ropePosition + (strengthDiff * 0.01)
    const clampedPosition = Math.max(-5, Math.min(5, newPosition))
    
    setRopePosition(clampedPosition)

    // Check for winner
    if (clampedPosition <= -4.5) {
      setWinner('Red Team')
      setIsGameActive(false)
    } else if (clampedPosition >= 4.5) {
      setWinner('Blue Team')
      setIsGameActive(false)
    }
  }, [redStrength, blueStrength, ropePosition, isGameActive])

  const handleRedPull = () => {
    if (!isGameActive) return
    setRedStrength(prev => Math.min(100, prev + 15))
  }

  const handleBluePull = () => {
    if (!isGameActive) return
    setBlueStrength(prev => Math.min(100, prev + 15))
  }

  const resetGame = () => {
    setRopePosition(0)
    setRedStrength(0)
    setBlueStrength(0)
    setWinner(null)
    setIsGameActive(true)
  }

  const getPositionText = () => {
    if (ropePosition < -2) return "Red Team Advantage!"
    if (ropePosition > 2) return "Blue Team Advantage!"
    return "Even Match!"
  }

  return (
    <>
      <Canvas
        camera={{ position: [0, 5, 10], fov: 60 }}
        style={{ width: '100vw', height: '100vh' }}
      >
        <ambientLight intensity={0.6} />
        <directionalLight position={[10, 10, 5]} intensity={1} />
        <TugOfWarScene ropePosition={ropePosition} />
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
          <h1 className="game-title">🐔 Chicken Pit Tug O' War 🐔</h1>
          <div className="game-status">{getPositionText()}</div>
        </div>

        <div className="controls">
          <div className="team-controls team-red">
            <div className="team-name">🔴 Red Team</div>
            <button className="pull-button" onClick={handleRedPull} disabled={!isGameActive}>
              Pull!
            </button>
            <div className="strength-meter">
              <div 
                className="strength-fill" 
                style={{ width: `${redStrength}%` }}
              />
            </div>
            <div>Strength: {redStrength}</div>
          </div>

          <div className="center-indicator">
            <div className="rope-position">
              Rope Position: {ropePosition.toFixed(1)}
            </div>
            <button className="reset-button" onClick={resetGame}>
              Reset Game
            </button>
          </div>

          <div className="team-controls team-blue">
            <div className="team-name">🔵 Blue Team</div>
            <button className="pull-button" onClick={handleBluePull} disabled={!isGameActive}>
              Pull!
            </button>
            <div className="strength-meter">
              <div 
                className="strength-fill" 
                style={{ width: `${blueStrength}%` }}
              />
            </div>
            <div>Strength: {blueStrength}</div>
          </div>
        </div>
      </div>

      {winner && (
        <div className="winner-announcement">
          🎉 {winner} Wins! 🎉
        </div>
      )}
    </>
  )
}

export default TugOfWarGame
