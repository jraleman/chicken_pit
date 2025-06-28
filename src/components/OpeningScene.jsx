import React, { useState, useEffect } from 'react'

const OpeningScene = ({ onComplete }) => {
  const [currentText, setCurrentText] = useState(0)
  const [isVisible, setIsVisible] = useState(true)

  const handleSkip = () => {
    setIsVisible(false)
    setTimeout(() => {
      onComplete()
    }, 500) // Shorter transition when skipping
  }

  const storyTexts = [
    "In the rolling hills of Athens, Georgia...",
    "On a family farm passed down through generations...",
    "Stands the most legendary chicken coop in the South...",
    "Where prize roosters have battled for over a century...",
    "Welcome to McAllister's Chicken Pit...",
    "Where two teams of champion birds clash in epic contests...",
    "Each fight determines the pride of the flock...",
    "The ultimate test of strength, strategy, and spirit awaits..."
  ]

  useEffect(() => {
    const textTimer = setInterval(() => {
      setCurrentText(prev => {
        if (prev < storyTexts.length - 1) {
          return prev + 1
        } else {
          clearInterval(textTimer)
          // Start fade out after all text is shown
          setTimeout(() => {
            setIsVisible(false)
            setTimeout(() => {
              onComplete()
            }, 1000) // Wait for fade out to complete
          }, 2000) // Show last text for 2 seconds
          return prev
        }
      })
    }, 1800) // Change text every 1.8 seconds (slower)

    return () => clearInterval(textTimer)
  }, [onComplete, storyTexts.length])

  return (
    <div className={`opening-scene ${!isVisible ? 'fade-out' : ''}`}>
      <div className="opening-background">
        <div className="opening-overlay"></div>
        <div className="opening-content">
          <div className="opening-title">
            <h1>The Chicken Pit</h1>
            <div className="opening-subtitle">Athens, Georgia</div>
          </div>
          
          <div className="story-container">
            <div className="story-paragraph">
              {storyTexts.map((text, index) => (
                <span
                  key={index}
                  className={`story-text-span ${index <= currentText ? 'visible' : ''} ${index === currentText ? 'current' : ''}`}
                >
                  {text}{index < storyTexts.length - 1 ? ' ' : ''}
                </span>
              ))}
            </div>
          </div>
          
          <div className="opening-footer">
            <button className="skip-button" onClick={handleSkip}>
              Skip ⏭
            </button>
            <div className="loading-dots">
              <span></span>
              <span></span>
              <span></span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default OpeningScene
