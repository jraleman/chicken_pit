import { useEffect, useRef, useState } from 'react'

const AudioManager = ({ 
  redStrength, 
  blueStrength, 
  winner, 
  isGameActive, 
  ropePosition,
  onRedPull,
  onBluePull 
}) => {
  const [isMuted, setIsMuted] = useState(false)
  const [volume, setVolume] = useState(0.7)
  
  // Audio refs
  const bgMusicRef = useRef(null)
  const pullSoundRef = useRef(null)
  const chickenCluckRef = useRef(null)
  const wingFlapRef = useRef(null)
  const victoryFanfareRef = useRef(null)
  const tensionSoundRef = useRef(null)
  const ropeCreakRef = useRef(null)
  
  // Previous values for comparison
  const prevRedStrength = useRef(0)
  const prevBlueStrength = useRef(0)
  const prevWinner = useRef(null)
  const prevGameActive = useRef(isGameActive)
  const lastPullTime = useRef(0)
  const backgroundAudioContext = useRef(null)

  // Web Audio API context for procedural sounds
  useEffect(() => {
    if (window.AudioContext || window.webkitAudioContext) {
      backgroundAudioContext.current = new (window.AudioContext || window.webkitAudioContext)()
    }
  }, [])

  // Initialize audio elements
  useEffect(() => {
    // Create audio elements with procedural sounds since we don't have audio files
    initializeAudioElements()
    
    return () => {
      // Cleanup
      Object.values({
        bgMusicRef,
        pullSoundRef,
        chickenCluckRef,
        wingFlapRef,
        victoryFanfareRef,
        tensionSoundRef,
        ropeCreakRef
      }).forEach(ref => {
        if (ref.current) {
          ref.current.pause()
          ref.current.src = ''
        }
      })
    }
  }, [])

  const initializeAudioElements = () => {
    // We'll use Web Audio API to create procedural sounds
    // Since we don't have actual audio files, we'll generate sounds programmatically
    
    // Background music - simple melody loop
    if (!bgMusicRef.current) {
      createBackgroundMusic()
    }
  }

  const createBackgroundMusic = () => {
    if (!backgroundAudioContext.current) return
    
    const ctx = backgroundAudioContext.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)
    gainNode.gain.setValueAtTime(0.1, ctx.currentTime)
    
    // Create a simple upbeat melody
    const playNote = (frequency, startTime, duration) => {
      const oscillator = ctx.createOscillator()
      const noteGain = ctx.createGain()
      
      oscillator.connect(noteGain)
      noteGain.connect(gainNode)
      
      oscillator.frequency.setValueAtTime(frequency, startTime)
      oscillator.type = 'triangle'
      
      noteGain.gain.setValueAtTime(0, startTime)
      noteGain.gain.linearRampToValueAtTime(0.1, startTime + 0.1)
      noteGain.gain.exponentialRampToValueAtTime(0.001, startTime + duration)
      
      oscillator.start(startTime)
      oscillator.stop(startTime + duration)
    }
    
    // Play a simple chicken-themed melody
    const startBackgroundMusic = () => {
      if (!isGameActive || isMuted) return
      
      const now = ctx.currentTime
      const tempo = 0.4
      
      // Simple melody pattern
      const melody = [
        { note: 523.25, beat: 0 },    // C5
        { note: 587.33, beat: 1 },    // D5
        { note: 659.25, beat: 2 },    // E5
        { note: 587.33, beat: 3 },    // D5
        { note: 523.25, beat: 4 },    // C5
        { note: 440.00, beat: 5 },    // A4
        { note: 493.88, beat: 6 },    // B4
        { note: 523.25, beat: 7 },    // C5
      ]
      
      melody.forEach(({ note, beat }) => {
        playNote(note, now + beat * tempo, tempo * 0.8)
      })
      
      // Schedule next loop
      setTimeout(() => {
        if (isGameActive && !isMuted) {
          startBackgroundMusic()
        }
      }, melody.length * tempo * 1000)
    }
    
    startBackgroundMusic()
  }

  const playPullSound = (isRed = true) => {
    if (isMuted || !backgroundAudioContext.current) return
    
    const ctx = backgroundAudioContext.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)
    
    // Create a "whoosh" sound for pulling
    const oscillator = ctx.createOscillator()
    const filter = ctx.createBiquadFilter()
    
    oscillator.connect(filter)
    filter.connect(gainNode)
    
    oscillator.frequency.setValueAtTime(isRed ? 150 : 180, ctx.currentTime)
    oscillator.frequency.exponentialRampToValueAtTime(isRed ? 80 : 100, ctx.currentTime + 0.2)
    oscillator.type = 'sawtooth'
    
    filter.frequency.setValueAtTime(1000, ctx.currentTime)
    filter.frequency.exponentialRampToValueAtTime(200, ctx.currentTime + 0.2)
    
    gainNode.gain.setValueAtTime(0.2, ctx.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.2)
    
    oscillator.start()
    oscillator.stop(ctx.currentTime + 0.2)
  }

  const playChickenCluck = () => {
    if (isMuted || !backgroundAudioContext.current) return
    
    const ctx = backgroundAudioContext.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)
    
    // Create a chicken cluck sound with more variation
    const cluckTypes = [
      { startFreq: 800, endFreq: 200, duration: 0.1 },
      { startFreq: 600, endFreq: 150, duration: 0.12 },
      { startFreq: 900, endFreq: 180, duration: 0.08 },
      { startFreq: 700, endFreq: 220, duration: 0.15 },
    ]
    
    const cluck = cluckTypes[Math.floor(Math.random() * cluckTypes.length)]
    const oscillator = ctx.createOscillator()
    oscillator.connect(gainNode)
    
    oscillator.frequency.setValueAtTime(cluck.startFreq, ctx.currentTime)
    oscillator.frequency.exponentialRampToValueAtTime(cluck.endFreq, ctx.currentTime + cluck.duration)
    oscillator.type = 'square'
    
    gainNode.gain.setValueAtTime(0.15, ctx.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + cluck.duration)
    
    oscillator.start()
    oscillator.stop(ctx.currentTime + cluck.duration)
    
    // Add a quick second cluck with random chance
    if (Math.random() > 0.5) {
      setTimeout(() => {
        if (isMuted || !backgroundAudioContext.current) return
        
        const osc2 = ctx.createOscillator()
        const gain2 = ctx.createGain()
        
        osc2.connect(gain2)
        gain2.connect(ctx.destination)
        
        osc2.frequency.setValueAtTime(cluck.startFreq * 0.8, ctx.currentTime)
        osc2.frequency.exponentialRampToValueAtTime(cluck.endFreq * 0.8, ctx.currentTime + cluck.duration * 0.8)
        osc2.type = 'square'
        
        gain2.gain.setValueAtTime(0.1, ctx.currentTime)
        gain2.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + cluck.duration * 0.8)
        
        osc2.start()
        osc2.stop(ctx.currentTime + cluck.duration * 0.8)
      }, cluck.duration * 1000 * 0.4)
    }
  }

  const playWingFlap = () => {
    if (isMuted || !backgroundAudioContext.current) return
    
    const ctx = backgroundAudioContext.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)
    
    // Create wing flap sound (whoosh)
    const noiseBuffer = ctx.createBuffer(1, ctx.sampleRate * 0.3, ctx.sampleRate)
    const output = noiseBuffer.getChannelData(0)
    
    for (let i = 0; i < noiseBuffer.length; i++) {
      output[i] = Math.random() * 2 - 1
    }
    
    const noiseSource = ctx.createBufferSource()
    const filter = ctx.createBiquadFilter()
    
    noiseSource.buffer = noiseBuffer
    noiseSource.connect(filter)
    filter.connect(gainNode)
    
    filter.type = 'highpass'
    filter.frequency.setValueAtTime(1000, ctx.currentTime)
    filter.frequency.exponentialRampToValueAtTime(2000, ctx.currentTime + 0.1)
    
    gainNode.gain.setValueAtTime(0.08, ctx.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3)
    
    noiseSource.start()
    noiseSource.stop(ctx.currentTime + 0.3)
  }

  const playVictoryFanfare = () => {
    if (isMuted || !backgroundAudioContext.current) return
    
    const ctx = backgroundAudioContext.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)
    gainNode.gain.setValueAtTime(0.25, ctx.currentTime)
    
    // Epic victory fanfare melody
    const fanfare = [
      { note: 523.25, time: 0, duration: 0.4 },     // C5
      { note: 659.25, time: 0.3, duration: 0.4 },   // E5
      { note: 783.99, time: 0.6, duration: 0.4 },   // G5
      { note: 1046.50, time: 0.9, duration: 0.8 },  // C6
      { note: 783.99, time: 1.5, duration: 0.3 },   // G5
      { note: 1046.50, time: 1.8, duration: 1.0 },  // C6
    ]
    
    fanfare.forEach(({ note, time, duration }) => {
      const oscillator = ctx.createOscillator()
      const noteGain = ctx.createGain()
      
      oscillator.connect(noteGain)
      noteGain.connect(gainNode)
      
      oscillator.frequency.setValueAtTime(note, ctx.currentTime + time)
      oscillator.type = 'triangle'
      
      noteGain.gain.setValueAtTime(0, ctx.currentTime + time)
      noteGain.gain.linearRampToValueAtTime(0.4, ctx.currentTime + time + 0.1)
      noteGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + time + duration)
      
      oscillator.start(ctx.currentTime + time)
      oscillator.stop(ctx.currentTime + time + duration)
    })
    
    // Add sparkly sound effects for extra celebration
    for (let i = 0; i < 10; i++) {
      setTimeout(() => {
        const sparkle = ctx.createOscillator()
        const sparkleGain = ctx.createGain()
        
        sparkle.connect(sparkleGain)
        sparkleGain.connect(ctx.destination)
        
        sparkle.frequency.setValueAtTime(1500 + Math.random() * 1500, ctx.currentTime)
        sparkle.type = 'sine'
        
        sparkleGain.gain.setValueAtTime(0.08, ctx.currentTime)
        sparkleGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.5)
        
        sparkle.start()
        sparkle.stop(ctx.currentTime + 0.5)
      }, i * 80)
    }
  }

  const playRopeCreak = (intensity = 0.5) => {
    if (isMuted || !backgroundAudioContext.current) return
    
    const ctx = backgroundAudioContext.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)
    
    // Create rope creaking sound
    const oscillator = ctx.createOscillator()
    oscillator.connect(gainNode)
    
    oscillator.frequency.setValueAtTime(100 + intensity * 50, ctx.currentTime)
    oscillator.frequency.linearRampToValueAtTime(120 + intensity * 60, ctx.currentTime + 0.5)
    oscillator.type = 'sawtooth'
    
    gainNode.gain.setValueAtTime(intensity * 0.1, ctx.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.5)
    
    oscillator.start()
    oscillator.stop(ctx.currentTime + 0.5)
  }

  const playGameStartSound = () => {
    if (isMuted || !backgroundAudioContext.current) return
    
    const ctx = backgroundAudioContext.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)
    
    // Play an upbeat start sound
    const startMelody = [
      { note: 392.00, time: 0, duration: 0.2 },     // G4
      { note: 523.25, time: 0.2, duration: 0.2 },   // C5
      { note: 659.25, time: 0.4, duration: 0.3 },   // E5
    ]
    
    startMelody.forEach(({ note, time, duration }) => {
      const oscillator = ctx.createOscillator()
      const noteGain = ctx.createGain()
      
      oscillator.connect(noteGain)
      noteGain.connect(gainNode)
      
      oscillator.frequency.setValueAtTime(note, ctx.currentTime + time)
      oscillator.type = 'triangle'
      
      noteGain.gain.setValueAtTime(0, ctx.currentTime + time)
      noteGain.gain.linearRampToValueAtTime(0.2, ctx.currentTime + time + 0.05)
      noteGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + time + duration)
      
      oscillator.start(ctx.currentTime + time)
      oscillator.stop(ctx.currentTime + time + duration)
    })
    
    // Add a chicken cluck after the melody
    setTimeout(() => {
      playChickenCluck()
      setTimeout(() => playChickenCluck(), 150)
    }, 600)
  }

  // Monitor game state changes for audio triggers
  useEffect(() => {
    // Check for strength increases (pulling)
    if (redStrength > prevRedStrength.current) {
      const now = Date.now()
      if (now - lastPullTime.current > 100) { // Throttle sound effects
        playPullSound(true)
        playChickenCluck()
        if (Math.random() > 0.7) playWingFlap()
        lastPullTime.current = now
      }
    }
    
    if (blueStrength > prevBlueStrength.current) {
      const now = Date.now()
      if (now - lastPullTime.current > 100) {
        playPullSound(false)
        playChickenCluck()
        if (Math.random() > 0.7) playWingFlap()
        lastPullTime.current = now
      }
    }
    
    prevRedStrength.current = redStrength
    prevBlueStrength.current = blueStrength
  }, [redStrength, blueStrength])

  // Play victory sound
  useEffect(() => {
    if (winner && winner !== prevWinner.current) {
      playVictoryFanfare()
      // Play multiple chicken clucks for celebration
      setTimeout(() => playChickenCluck(), 200)
      setTimeout(() => playChickenCluck(), 400)
      setTimeout(() => playChickenCluck(), 600)
    }
    prevWinner.current = winner
  }, [winner])

  // Play rope tension sounds based on position
  useEffect(() => {
    const intensity = Math.abs(ropePosition) / 10
    if (intensity > 0.3 && isGameActive) {
      const playTension = () => {
        playRopeCreak(intensity)
        if (isGameActive && Math.abs(ropePosition) > 3) {
          setTimeout(playTension, 1000 + Math.random() * 2000)
        }
      }
      setTimeout(playTension, Math.random() * 1000)
    }
  }, [ropePosition, isGameActive])

  // Start background music when game becomes active
  useEffect(() => {
    // Check if game just became active (reset or initial start)
    if (isGameActive && !prevGameActive.current && backgroundAudioContext.current && !isMuted) {
      playGameStartSound()
    }
    
    if (isGameActive && backgroundAudioContext.current && !isMuted) {
      // Resume audio context if suspended
      if (backgroundAudioContext.current.state === 'suspended') {
        backgroundAudioContext.current.resume()
      }
      createBackgroundMusic()
    }
    
    prevGameActive.current = isGameActive
  }, [isGameActive, isMuted])

  const toggleMute = () => {
    setIsMuted(!isMuted)
    if (backgroundAudioContext.current) {
      if (!isMuted) {
        backgroundAudioContext.current.suspend()
      } else {
        backgroundAudioContext.current.resume()
      }
    }
  }

  return (
    <div className="audio-controls">
      <button className="audio-button" onClick={toggleMute}>
        {isMuted ? '🔇' : '🔊'}
      </button>
      <input
        type="range"
        min="0"
        max="1"
        step="0.1"
        value={volume}
        onChange={(e) => setVolume(parseFloat(e.target.value))}
        className="volume-slider"
        disabled={isMuted}
      />
      <span className="volume-label">{Math.round(volume * 100)}%</span>
    </div>
  )
}

export default AudioManager
