import React, { useRef, useState, useEffect } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'

const SoundParticles = ({ redStrength, blueStrength, ropePosition, winner }) => {
  const particlesRef = useRef()
  const [particles, setParticles] = useState([])
  const prevRedStrength = useRef(0)
  const prevBlueStrength = useRef(0)
  
  // Create particles when chickens pull
  useEffect(() => {
    const newParticles = []
    
    // Red chicken particles
    if (redStrength > prevRedStrength.current) {
      for (let i = 0; i < 5; i++) {
        newParticles.push({
          id: Date.now() + Math.random(),
          position: new THREE.Vector3(-8 + Math.random() * 2, 2 + Math.random(), Math.random() * 2),
          velocity: new THREE.Vector3(
            Math.random() * 2 - 1,
            Math.random() * 2 + 1,
            Math.random() * 2 - 1
          ),
          life: 1,
          maxLife: 1,
          color: '#ff4757',
          size: 0.1 + Math.random() * 0.1
        })
      }
    }
    
    // Blue chicken particles
    if (blueStrength > prevBlueStrength.current) {
      for (let i = 0; i < 5; i++) {
        newParticles.push({
          id: Date.now() + Math.random() + 1000,
          position: new THREE.Vector3(8 + Math.random() * 2, 2 + Math.random(), Math.random() * 2),
          velocity: new THREE.Vector3(
            Math.random() * 2 - 1,
            Math.random() * 2 + 1,
            Math.random() * 2 - 1
          ),
          life: 1,
          maxLife: 1,
          color: '#3742fa',
          size: 0.1 + Math.random() * 0.1
        })
      }
    }
    
    if (newParticles.length > 0) {
      setParticles(prev => [...prev, ...newParticles])
    }
    
    prevRedStrength.current = redStrength
    prevBlueStrength.current = blueStrength
  }, [redStrength, blueStrength])
  
  // Victory confetti
  useEffect(() => {
    if (winner) {
      const confetti = []
      const winnerColor = winner.includes('Red') ? '#ff4757' : '#3742fa'
      
      for (let i = 0; i < 30; i++) {
        confetti.push({
          id: Date.now() + Math.random() + 10000,
          position: new THREE.Vector3(
            Math.random() * 20 - 10,
            8 + Math.random() * 2,
            Math.random() * 10 - 5
          ),
          velocity: new THREE.Vector3(
            Math.random() * 4 - 2,
            Math.random() * 2 - 1,
            Math.random() * 4 - 2
          ),
          life: 3,
          maxLife: 3,
          color: Math.random() > 0.5 ? winnerColor : '#ffd700',
          size: 0.15 + Math.random() * 0.1
        })
      }
      
      setParticles(prev => [...prev, ...confetti])
    }
  }, [winner])
  
  useFrame((state, delta) => {
    setParticles(prev => 
      prev.map(particle => ({
        ...particle,
        position: particle.position.clone().add(particle.velocity.clone().multiplyScalar(delta)),
        velocity: particle.velocity.clone().multiplyScalar(0.98), // Air resistance
        life: particle.life - delta
      }))
      .filter(particle => particle.life > 0)
    )
  })
  
  return (
    <group ref={particlesRef}>
      {particles.map(particle => (
        <mesh key={particle.id} position={particle.position}>
          <sphereGeometry args={[particle.size]} />
          <meshBasicMaterial 
            color={particle.color} 
            transparent 
            opacity={particle.life / particle.maxLife}
          />
        </mesh>
      ))}
      
      {/* Musical notes floating around when sounds play */}
      {(redStrength > 50 || blueStrength > 50) && (
        <>
          <mesh position={[-6, 4, 0]}>
            <sphereGeometry args={[0.1]} />
            <meshBasicMaterial color="#ffff00" />
          </mesh>
          <mesh position={[6, 4, 0]}>
            <sphereGeometry args={[0.1]} />
            <meshBasicMaterial color="#ffff00" />
          </mesh>
        </>
      )}
    </group>
  )
}

export default SoundParticles
