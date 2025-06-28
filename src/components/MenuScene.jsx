import React, { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import { Text } from '@react-three/drei'
import * as THREE from 'three'

// Running Chicken Component
const RunningChicken = ({ position, color, speed = 1, direction = 1 }) => {
  const chickenRef = useRef()
  const startX = position[0]
  const runDistance = 20
  
  useFrame((state) => {
    if (chickenRef.current) {
      const time = state.clock.getElapsedTime()
      
      // Running animation - move back and forth
      const progress = (time * speed) % (runDistance * 2)
      let x = startX
      
      if (progress < runDistance) {
        x = startX + (progress * direction)
      } else {
        x = startX + ((runDistance * 2 - progress) * direction)
      }
      
      chickenRef.current.position.x = x
      
      // Bob up and down while running
      chickenRef.current.position.y = position[1] + Math.sin(time * speed * 4) * 0.2
      
      // Slight rotation while running
      chickenRef.current.rotation.z = Math.sin(time * speed * 2) * 0.1
      
      // Face the direction of movement
      const movingRight = (progress < runDistance && direction > 0) || (progress >= runDistance && direction < 0)
      chickenRef.current.rotation.y = movingRight ? 0 : Math.PI
    }
  })

  return (
    <group ref={chickenRef} position={position}>
      {/* Chicken Body */}
      <mesh position={[0, 0, 0]}>
        <sphereGeometry args={[0.8, 12, 8]} />
        <meshLambertMaterial color={color} />
      </mesh>
      
      {/* Chicken Head */}
      <mesh position={[0, 1.2, 0.3]}>
        <sphereGeometry args={[0.5, 8, 8]} />
        <meshLambertMaterial color={color} />
      </mesh>
      
      {/* Beak */}
      <mesh position={[0, 1.1, 0.8]}>
        <coneGeometry args={[0.1, 0.3, 4]} />
        <meshLambertMaterial color="#ff8c00" />
      </mesh>
      
      {/* Comb */}
      <mesh position={[0, 1.6, 0.2]}>
        <boxGeometry args={[0.2, 0.4, 0.1]} />
        <meshLambertMaterial color="#ff0000" />
      </mesh>
      
      {/* Wings */}
      <mesh position={[-0.6, 0.2, 0]} rotation={[0, 0, -0.3]}>
        <boxGeometry args={[0.4, 0.8, 0.2]} />
        <meshLambertMaterial color={color} />
      </mesh>
      <mesh position={[0.6, 0.2, 0]} rotation={[0, 0, 0.3]}>
        <boxGeometry args={[0.4, 0.8, 0.2]} />
        <meshLambertMaterial color={color} />
      </mesh>
      
      {/* Tail */}
      <mesh position={[0, 0.5, -0.8]}>
        <coneGeometry args={[0.3, 0.6, 6]} />
        <meshLambertMaterial color={color} />
      </mesh>
      
      {/* Legs */}
      <mesh position={[-0.3, -0.8, 0]}>
        <cylinderGeometry args={[0.08, 0.08, 0.6]} />
        <meshLambertMaterial color="#ff8c00" />
      </mesh>
      <mesh position={[0.3, -0.8, 0]}>
        <cylinderGeometry args={[0.08, 0.08, 0.6]} />
        <meshLambertMaterial color="#ff8c00" />
      </mesh>
      
      {/* Feet */}
      <mesh position={[-0.3, -1.2, 0.2]}>
        <boxGeometry args={[0.15, 0.05, 0.3]} />
        <meshLambertMaterial color="#ff8c00" />
      </mesh>
      <mesh position={[0.3, -1.2, 0.2]}>
        <boxGeometry args={[0.15, 0.05, 0.3]} />
        <meshLambertMaterial color="#ff8c00" />
      </mesh>
    </group>
  )
}

// Floating Particle Component
const FloatingParticle = ({ position }) => {
  const particleRef = useRef()
  
  useFrame((state) => {
    if (particleRef.current) {
      const time = state.clock.getElapsedTime()
      particleRef.current.position.y = position[1] + Math.sin(time + position[0]) * 0.5
      particleRef.current.rotation.x = time * 0.5
      particleRef.current.rotation.y = time * 0.3
    }
  })

  return (
    <mesh ref={particleRef} position={position}>
      <octahedronGeometry args={[0.1]} />
      <meshLambertMaterial color="#ffff00" transparent opacity={0.6} />
    </mesh>
  )
}

const MenuScene = () => {
  // Generate random positions for running chickens
  const runningChickens = useMemo(() => {
    const chickens = []
    const colors = ['#ff6b6b', '#4834d4', '#ff9f43', '#10ac84', '#ee5a24', '#0abde3']
    
    for (let i = 0; i < 8; i++) {
      chickens.push({
        id: i,
        position: [
          -15 + Math.random() * 30, // x: -15 to 15
          -2 + Math.random() * 2,   // y: -2 to 0
          -5 + Math.random() * 10   // z: -5 to 5
        ],
        color: colors[i % colors.length],
        speed: 0.5 + Math.random() * 1.5, // 0.5 to 2
        direction: Math.random() > 0.5 ? 1 : -1
      })
    }
    return chickens
  }, [])

  // Generate floating particles
  const particles = useMemo(() => {
    const particleArray = []
    for (let i = 0; i < 15; i++) {
      particleArray.push({
        id: i,
        position: [
          -20 + Math.random() * 40, // x: -20 to 20
          2 + Math.random() * 8,    // y: 2 to 10
          -10 + Math.random() * 20  // z: -10 to 10
        ]
      })
    }
    return particleArray
  }, [])

  return (
    <>
      {/* Ground */}
      <mesh position={[0, -3, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <planeGeometry args={[50, 50]} />
        <meshLambertMaterial color="#4a7c59" />
      </mesh>

      {/* Center Platform */}
      <mesh position={[0, -2.5, 0]}>
        <cylinderGeometry args={[8, 8, 0.5, 16]} />
        <meshLambertMaterial color="#2d5a3d" />
      </mesh>

      {/* Decorative Ring */}
      <mesh position={[0, -2.2, 0]}>
        <torusGeometry args={[9, 0.3, 8, 32]} />
        <meshLambertMaterial color="#ffffff" />
      </mesh>

      {/* Running Chickens */}
      {runningChickens.map(chicken => (
        <RunningChicken
          key={chicken.id}
          position={chicken.position}
          color={chicken.color}
          speed={chicken.speed}
          direction={chicken.direction}
        />
      ))}

      {/* Floating Particles */}
      {particles.map(particle => (
        <FloatingParticle
          key={particle.id}
          position={particle.position}
        />
      ))}

      {/* Welcome Text in 3D Space */}
      <Text
        position={[0, 3, 0]}
        fontSize={2}
        color="#ffffff"
        anchorX="center"
        anchorY="middle"
        outlineWidth={0.1}
        outlineColor="#000000"
      >
        Welcome to Chicken Pit!
      </Text>

      {/* Subtitle */}
      <Text
        position={[0, 1, 0]}
        fontSize={0.8}
        color="#ffff00"
        anchorX="center"
        anchorY="middle"
        outlineWidth={0.05}
        outlineColor="#000000"
      >
        🐔 The Ultimate Tug O' War Experience 🐔
      </Text>

      {/* Background Elements */}
      <mesh position={[-15, 5, -10]}>
        <sphereGeometry args={[2, 8, 6]} />
        <meshLambertMaterial color="#87ceeb" transparent opacity={0.3} />
      </mesh>
      
      <mesh position={[15, 7, -8]}>
        <boxGeometry args={[3, 3, 3]} />
        <meshLambertMaterial color="#dda0dd" transparent opacity={0.2} />
      </mesh>

      <mesh position={[0, 10, -15]}>
        <octahedronGeometry args={[4]} />
        <meshLambertMaterial color="#f0e68c" transparent opacity={0.15} />
      </mesh>
    </>
  )
}

export default MenuScene
