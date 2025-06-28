import React, { useState } from 'react'
import OpeningScene from './components/OpeningScene'
import MainMenu from './components/MainMenu'
import TugOfWarGame from './components/TugOfWarGame'
import './App.css'

function App() {
  const [gameState, setGameState] = useState('opening') // 'opening', 'menu', or 'game'
  const [gameConfig, setGameConfig] = useState(null)

  const handleOpeningComplete = () => {
    setGameState('menu')
  }

  const handleStartGame = (config) => {
    setGameConfig(config)
    setGameState('game')
  }

  const handleReturnToMenu = () => {
    setGameState('menu')
    setGameConfig(null)
  }

  return (
    <div className="App">
      {gameState === 'opening' ? (
        <OpeningScene onComplete={handleOpeningComplete} />
      ) : gameState === 'menu' ? (
        <MainMenu onStartGame={handleStartGame} />
      ) : (
        <TugOfWarGame 
          gameConfig={gameConfig} 
          onReturnToMenu={handleReturnToMenu}
        />
      )}
    </div>
  )
}

export default App
