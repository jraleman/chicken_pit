import React, { useRef, useEffect, useState } from 'react'
import { useFrame } from '@react-three/fiber'

const AudioReactiveChicken = ({ children, redStrength, blueStrength, isRed }) => {
  const groupRef = useRef()
  const [isClucking, setIsClucking] = useState(false)
  const [isPulling, setIsPulling] = useState(false)
  const prevStrength = useRef(0)
  
  const currentStrength = isRed ? redStrength : blueStrength
  
  useEffect(() => {
    // Detect when chicken is pulling (strength increase)
    if (currentStrength > prevStrength.current) {
      setIsPulling(true)
      setIsClucking(true)
      
      // Auto-reset pulling state
      setTimeout(() => setIsPulling(false), 200)
      setTimeout(() => setIsClucking(false), 500)
    }
    prevStrength.current = currentStrength
  }, [currentStrength])
  
  useFrame((state) => {
    if (!groupRef.current) return
    
    // Audio-reactive size pulsing when clucking
    if (isClucking) {
      const pulse = Math.sin(state.clock.elapsedTime * 20) * 0.1 + 1
      groupRef.current.scale.setScalar(pulse)
    } else {
      // Gradually return to normal size
      const currentScale = groupRef.current.scale.x
      const targetScale = 1
      groupRef.current.scale.setScalar(currentScale + (targetScale - currentScale) * 0.1)
    }
    
    // Extra bounce when pulling
    if (isPulling) {
      const bounce = Math.sin(state.clock.elapsedTime * 30) * 0.2
      groupRef.current.position.y = groupRef.current.position.y + bounce
    }
    
    // Strength-based glow effect (simulated with scale variations)
    const strengthGlow = 1 + (currentStrength / 100) * 0.15
    if (!isClucking && !isPulling) {
      groupRef.current.scale.setScalar(strengthGlow)
    }
  })
  
  return (
    <group ref={groupRef}>
      {children}
    </group>
  )
}

export default AudioReactiveChicken
