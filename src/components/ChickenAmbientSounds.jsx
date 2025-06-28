import { useEffect, useRef } from 'react'

const ChickenAmbientSounds = ({ isGameActive, winner }) => {
  const intervalRef = useRef()
  const audioContextRef = useRef()

  useEffect(() => {
    if (window.AudioContext || window.webkitAudioContext) {
      audioContextRef.current = new (window.AudioContext || window.webkitAudioContext)()
    }
  }, [])

  const playRandomCluck = () => {
    if (!audioContextRef.current || !isGameActive) return

    const ctx = audioContextRef.current
    const gainNode = ctx.createGain()
    gainNode.connect(ctx.destination)

    // Random chicken cluck variations
    const cluckTypes = [
      { startFreq: 600, endFreq: 200, duration: 0.15 },
      { startFreq: 800, endFreq: 150, duration: 0.12 },
      { startFreq: 700, endFreq: 250, duration: 0.18 },
      { startFreq: 900, endFreq: 180, duration: 0.1 },
    ]

    const cluck = cluckTypes[Math.floor(Math.random() * cluckTypes.length)]
    const oscillator = ctx.createOscillator()
    
    oscillator.connect(gainNode)
    oscillator.frequency.setValueAtTime(cluck.startFreq, ctx.currentTime)
    oscillator.frequency.exponentialRampToValueAtTime(cluck.endFreq, ctx.currentTime + cluck.duration)
    oscillator.type = 'square'

    gainNode.gain.setValueAtTime(0.05, ctx.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + cluck.duration)

    oscillator.start()
    oscillator.stop(ctx.currentTime + cluck.duration)

    // Sometimes add a second cluck
    if (Math.random() > 0.6) {
      setTimeout(() => {
        if (!audioContextRef.current || !isGameActive) return
        
        const osc2 = ctx.createOscillator()
        const gain2 = ctx.createGain()
        
        osc2.connect(gain2)
        gain2.connect(ctx.destination)
        
        osc2.frequency.setValueAtTime(cluck.startFreq * 0.8, ctx.currentTime)
        osc2.frequency.exponentialRampToValueAtTime(cluck.endFreq * 0.8, ctx.currentTime + cluck.duration * 0.8)
        osc2.type = 'square'
        
        gain2.gain.setValueAtTime(0.03, ctx.currentTime)
        gain2.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + cluck.duration * 0.8)
        
        osc2.start()
        osc2.stop(ctx.currentTime + cluck.duration * 0.8)
      }, cluck.duration * 1000 * 0.3)
    }
  }

  // Play ambient chicken sounds
  useEffect(() => {
    if (isGameActive && !winner) {
      intervalRef.current = setInterval(() => {
        if (Math.random() > 0.7) { // 30% chance every interval
          playRandomCluck()
        }
      }, 3000 + Math.random() * 4000) // Every 3-7 seconds

      return () => {
        if (intervalRef.current) {
          clearInterval(intervalRef.current)
        }
      }
    }
  }, [isGameActive, winner])

  return null // This component doesn't render anything visual
}

export default ChickenAmbientSounds
