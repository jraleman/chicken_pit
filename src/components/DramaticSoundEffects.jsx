import { useEffect, useRef } from 'react'

const DramaticSoundEffects = ({ ropePosition, isGameActive, winner }) => {
  const audioContextRef = useRef()
  const currentSoundsRef = useRef(new Set()) // Track all playing sounds
  const lastDramaticTime = useRef(0)
  const lastCloseCallTime = useRef(0)
  const prevWinnerRef = useRef(null)
  const isInitialized = useRef(false)

  // Initialize audio context
  useEffect(() => {
    if (!isInitialized.current && (window.AudioContext || window.webkitAudioContext)) {
      audioContextRef.current = new (window.AudioContext || window.webkitAudioContext)()
      isInitialized.current = true
      console.log('DramaticSoundEffects: Audio context initialized')
      
      // Add a one-time click listener to resume audio context
      const resumeAudio = () => {
        if (audioContextRef.current && audioContextRef.current.state === 'suspended') {
          audioContextRef.current.resume().then(() => {
            console.log('DramaticSoundEffects: Audio context resumed after user interaction')
          })
        }
        document.removeEventListener('click', resumeAudio)
      }
      document.addEventListener('click', resumeAudio)
    }
  }, [])

  // Cleanup function to stop all sounds
  const stopAllSounds = () => {
    console.log('DramaticSoundEffects: Stopping all sounds')
    currentSoundsRef.current.forEach(sound => {
      try {
        if (sound && sound.stop) {
          sound.stop()
        }
      } catch (e) {
        // Sound may have already stopped
      }
    })
    currentSoundsRef.current.clear()
  }

  const playDramaticRiser = (intensity = 0.5) => {
    if (!audioContextRef.current || !isGameActive) {
      console.log('DramaticSoundEffects: Cannot play dramatic riser - no context or game inactive')
      return
    }

    const now = Date.now()
    if (now - lastDramaticTime.current < 3000) { // 3 second cooldown
      console.log('DramaticSoundEffects: Dramatic riser on cooldown')
      return
    }

    console.log('DramaticSoundEffects: Playing dramatic riser with intensity:', intensity)
    
    // Resume audio context if needed
    if (audioContextRef.current.state === 'suspended') {
      audioContextRef.current.resume()
    }

    const ctx = audioContextRef.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)

    const oscillator = ctx.createOscillator()
    const filter = ctx.createBiquadFilter()
    
    oscillator.connect(filter)
    filter.connect(gainNode)

    const startFreq = 100 + intensity * 50
    const endFreq = 300 + intensity * 200
    const duration = 2.0
    
    oscillator.frequency.setValueAtTime(startFreq, ctx.currentTime)
    oscillator.frequency.exponentialRampToValueAtTime(endFreq, ctx.currentTime + duration)
    oscillator.type = 'sawtooth'

    filter.frequency.setValueAtTime(800, ctx.currentTime)
    filter.frequency.exponentialRampToValueAtTime(2000, ctx.currentTime + duration)
    filter.Q.setValueAtTime(3, ctx.currentTime)

    gainNode.gain.setValueAtTime(0, ctx.currentTime)
    gainNode.gain.linearRampToValueAtTime(intensity * 0.1, ctx.currentTime + 0.5)
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration)

    oscillator.start()
    oscillator.stop(ctx.currentTime + duration)
    
    // Track this sound
    currentSoundsRef.current.add(oscillator)
    lastDramaticTime.current = now
    
    // Remove from tracking when it ends
    setTimeout(() => {
      currentSoundsRef.current.delete(oscillator)
    }, duration * 1000)
  }

  const playCloseCallSound = () => {
    if (!audioContextRef.current || !isGameActive) return

    const now = Date.now()
    if (now - lastCloseCallTime.current < 2000) { // 2 second cooldown
      return
    }

    console.log('DramaticSoundEffects: Playing close call heartbeat')

    const ctx = audioContextRef.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)

    // Heartbeat-like sound for close calls
    const playBeat = (delay, intensity) => {
      setTimeout(() => {
        if (!isGameActive) return
        
        const osc = ctx.createOscillator()
        const beatGain = ctx.createGain()
        
        osc.connect(beatGain)
        beatGain.connect(gainNode)
        
        osc.frequency.setValueAtTime(80, ctx.currentTime)
        osc.frequency.exponentialRampToValueAtTime(60, ctx.currentTime + 0.3)
        osc.type = 'sine'
        
        beatGain.gain.setValueAtTime(intensity, ctx.currentTime)
        beatGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3)
        
        osc.start()
        osc.stop(ctx.currentTime + 0.3)
        
        currentSoundsRef.current.add(osc)
        setTimeout(() => currentSoundsRef.current.delete(osc), 300)
      }, delay)
    }

    // Double heartbeat pattern
    playBeat(0, 0.2)
    playBeat(300, 0.15)
    
    lastCloseCallTime.current = now
  }

  const playVictoryFanfare = (isRed = true) => {
    if (!audioContextRef.current) return

    const ctx = audioContextRef.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)
    gainNode.gain.setValueAtTime(0.2, ctx.currentTime)

    // Victory melody - different for each team
    const melodies = {
      red: [
        { note: 523.25, time: 0, duration: 0.3 },     // C5
        { note: 659.25, time: 0.3, duration: 0.3 },   // E5
        { note: 783.99, time: 0.6, duration: 0.3 },   // G5
        { note: 1046.50, time: 0.9, duration: 0.6 },  // C6
        { note: 783.99, time: 1.5, duration: 0.2 },   // G5
        { note: 1046.50, time: 1.7, duration: 0.8 },  // C6
      ],
      blue: [
        { note: 587.33, time: 0, duration: 0.3 },     // D5
        { note: 739.99, time: 0.3, duration: 0.3 },   // F#5
        { note: 880.00, time: 0.6, duration: 0.3 },   // A5
        { note: 1174.66, time: 0.9, duration: 0.6 },  // D6
        { note: 880.00, time: 1.5, duration: 0.2 },   // A5
        { note: 1174.66, time: 1.7, duration: 0.8 },  // D6
      ]
    }

    const melody = isRed ? melodies.red : melodies.blue

    melody.forEach(({ note, time, duration }) => {
      const oscillator = ctx.createOscillator()
      const noteGain = ctx.createGain()
      
      oscillator.connect(noteGain)
      noteGain.connect(gainNode)
      
      oscillator.frequency.setValueAtTime(note, ctx.currentTime + time)
      oscillator.type = 'triangle'
      
      noteGain.gain.setValueAtTime(0, ctx.currentTime + time)
      noteGain.gain.linearRampToValueAtTime(0.3, ctx.currentTime + time + 0.05)
      noteGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + time + duration)
      
      oscillator.start(ctx.currentTime + time)
      oscillator.stop(ctx.currentTime + time + duration)
    })

    // Add some sparkle sounds
    for (let i = 0; i < 8; i++) {
      setTimeout(() => {
        const sparkle = ctx.createOscillator()
        const sparkleGain = ctx.createGain()
        
        sparkle.connect(sparkleGain)
        sparkleGain.connect(ctx.destination)
        
        sparkle.frequency.setValueAtTime(2000 + Math.random() * 1000, ctx.currentTime)
        sparkle.type = 'sine'
        
        sparkleGain.gain.setValueAtTime(0.1, ctx.currentTime)
        sparkleGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3)
        
        sparkle.start()
        sparkle.stop(ctx.currentTime + 0.3)
      }, i * 100)
    }
  }

  const playDefeatSound = () => {
    if (!audioContextRef.current) return

    const ctx = audioContextRef.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)

    // Sad descending sound
    const oscillator = ctx.createOscillator()
    oscillator.connect(gainNode)
    
    oscillator.frequency.setValueAtTime(400, ctx.currentTime)
    oscillator.frequency.exponentialRampToValueAtTime(150, ctx.currentTime + 1.5)
    oscillator.type = 'triangle'
    
    gainNode.gain.setValueAtTime(0.1, ctx.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 1.5)
    
    oscillator.start()
    oscillator.stop(ctx.currentTime + 1.5)
  }

  // Main effect monitoring - simplified and reliable
  useEffect(() => {
    if (!isGameActive) {
      stopAllSounds()
      return
    }

    const intensity = Math.abs(ropePosition) / 11 // Normalize to 0-1 based on win condition
    console.log('DramaticSoundEffects: Rope position:', ropePosition, 'Intensity:', intensity.toFixed(2))

    // DRAMATIC RISER - High tension zones
    if (intensity > 0.8) {
      const now = Date.now()
      if (now - lastDramaticTime.current > 3000) { // 3 second cooldown
        console.log('DramaticSoundEffects: Triggering dramatic riser at intensity:', intensity)
        playDramaticRiser(intensity)
      }
    }

    // CLOSE CALL HEARTBEAT - Very close to winning
    if (intensity > 0.95) {
      const now = Date.now()
      if (now - lastCloseCallTime.current > 2500) { // 2.5 second cooldown
        console.log('DramaticSoundEffects: Triggering close call heartbeat')
        playCloseCallSound()
      }
    }

    // TENSION RELIEF - Stop sounds when rope returns to center
    if (intensity < 0.3) {
      if (currentSoundsRef.current.size > 0) {
        console.log('DramaticSoundEffects: Low tension - stopping dramatic sounds')
        stopAllSounds()
      }
    }

  }, [ropePosition, isGameActive])

  // Handle game state changes
  useEffect(() => {
    if (!isGameActive) {
      console.log('DramaticSoundEffects: Game inactive - stopping all sounds')
      stopAllSounds()
      lastDramaticTime.current = 0
      lastCloseCallTime.current = 0
    }
  }, [isGameActive])

  // Handle victory
  useEffect(() => {
    if (winner && winner !== prevWinnerRef.current) {
      console.log('DramaticSoundEffects: Winner detected:', winner, '- stopping dramatic sounds')
      stopAllSounds()
      
      const isRed = winner.includes('Red')
      playVictoryFanfare(isRed)
      
      setTimeout(() => {
        playDefeatSound()
      }, 1500)
    }
    prevWinnerRef.current = winner
  }, [winner])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      console.log('DramaticSoundEffects: Component unmounting - cleanup')
      stopAllSounds()
    }
  }, [])

  // Test function - can be called from browser console
  window.testDramaticSounds = () => {
    console.log('Testing dramatic sound effects...')
    if (!audioContextRef.current) {
      console.log('No audio context available')
      return
    }
    
    if (audioContextRef.current.state === 'suspended') {
      audioContextRef.current.resume().then(() => {
        console.log('Audio context resumed')
        playDramaticRiser(0.8)
      })
    } else {
      playDramaticRiser(0.8)
    }
  }

  return null
}

export default DramaticSoundEffects
