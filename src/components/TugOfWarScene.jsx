import React, { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import { Text, Box, Cylinder, Sphere } from '@react-three/drei'
import * as THREE from 'three'

const Player = ({ position, color, isLeft }) => {
  const meshRef = useRef()
  
  useFrame((state) => {
    if (meshRef.current) {
      // Add subtle breathing animation
      meshRef.current.scale.y = 1 + Math.sin(state.clock.elapsedTime * 2) * 0.05
    }
  })

  return (
    <group position={position}>
      {/* Player body */}
      <Box ref={meshRef} args={[0.8, 1.5, 0.4]} position={[0, 0.75, 0]}>
        <meshLambertMaterial color={color} />
      </Box>
      
      {/* Player head */}
      <Sphere args={[0.3]} position={[0, 1.8, 0]}>
        <meshLambertMaterial color={color === '#ff4757' ? '#ff6b6b' : '#4834d4'} />
      </Sphere>
      
      {/* Arms */}
      <Box args={[0.2, 0.8, 0.2]} position={[isLeft ? 0.5 : -0.5, 1, 0.3]}>
        <meshLambertMaterial color={color} />
      </Box>
      <Box args={[0.2, 0.8, 0.2]} position={[isLeft ? -0.5 : 0.5, 1, 0.3]}>
        <meshLambertMaterial color={color} />
      </Box>
      
      {/* Legs */}
      <Box args={[0.25, 0.8, 0.25]} position={[-0.2, -0.4, 0]}>
        <meshLambertMaterial color={color} />
      </Box>
      <Box args={[0.25, 0.8, 0.25]} position={[0.2, -0.4, 0]}>
        <meshLambertMaterial color={color} />
      </Box>
    </group>
  )
}

const Rope = ({ ropePosition }) => {
  const ropeRef = useRef()
  
  // Create rope segments
  const segments = useMemo(() => {
    const segmentCount = 20
    const totalLength = 10
    const segmentLength = totalLength / segmentCount
    
    return Array.from({ length: segmentCount }, (_, i) => {
      const x = (i - segmentCount / 2) * segmentLength + ropePosition
      const y = 1.5 + Math.sin((i / segmentCount) * Math.PI * 2) * 0.1 // Slight curve
      return [x, y, 0]
    })
  }, [ropePosition])

  return (
    <group ref={ropeRef}>
      {segments.map((position, index) => (
        <Cylinder
          key={index}
          args={[0.05, 0.05, 0.4]}
          position={position}
          rotation={[0, 0, Math.PI / 2]}
        >
          <meshLambertMaterial color="#8B4513" />
        </Cylinder>
      ))}
      
      {/* Center marker on rope */}
      <Sphere args={[0.1]} position={[ropePosition, 1.5, 0]}>
        <meshLambertMaterial color="#FFD700" />
      </Sphere>
    </group>
  )
}

const Ground = () => {
  return (
    <group>
      {/* Main ground */}
      <Box args={[20, 0.2, 10]} position={[0, -0.1, 0]}>
        <meshLambertMaterial color="#90EE90" />
      </Box>
      
      {/* Center line */}
      <Box args={[0.1, 0.1, 8]} position={[0, 0.1, 0]}>
        <meshLambertMaterial color="#FFFFFF" />
      </Box>
      
      {/* Goal lines */}
      <Box args={[0.1, 0.1, 8]} position={[-4.5, 0.1, 0]}>
        <meshLambertMaterial color="#FF0000" />
      </Box>
      <Box args={[0.1, 0.1, 8]} position={[4.5, 0.1, 0]}>
        <meshLambertMaterial color="#0000FF" />
      </Box>
    </group>
  )
}

const TugOfWarScene = ({ ropePosition }) => {
  return (
    <>
      <Ground />
      
      {/* Red team players */}
      <Player position={[-6, 0, 1]} color="#ff4757" isLeft={true} />
      <Player position={[-7, 0, -1]} color="#ff4757" isLeft={true} />
      <Player position={[-8, 0, 0]} color="#ff4757" isLeft={true} />
      
      {/* Blue team players */}
      <Player position={[6, 0, 1]} color="#3742fa" isLeft={false} />
      <Player position={[7, 0, -1]} color="#3742fa" isLeft={false} />
      <Player position={[8, 0, 0]} color="#3742fa" isLeft={false} />
      
      {/* Rope */}
      <Rope ropePosition={ropePosition} />
      
      {/* Team labels */}
      <Text
        position={[-6, 3, 0]}
        fontSize={0.8}
        color="#ff4757"
        anchorX="center"
        anchorY="middle"
      >
        RED TEAM
      </Text>
      
      <Text
        position={[6, 3, 0]}
        fontSize={0.8}
        color="#3742fa"
        anchorX="center"
        anchorY="middle"
      >
        BLUE TEAM
      </Text>
      
      {/* Decorative elements */}
      {/* Crowd/Spectators */}
      <Sphere args={[0.3]} position={[-10, 1, 3]}>
        <meshLambertMaterial color="#FFB6C1" />
      </Sphere>
      <Sphere args={[0.3]} position={[-10, 1, -3]}>
        <meshLambertMaterial color="#98FB98" />
      </Sphere>
      <Sphere args={[0.3]} position={[10, 1, 3]}>
        <meshLambertMaterial color="#87CEEB" />
      </Sphere>
      <Sphere args={[0.3]} position={[10, 1, -3]}>
        <meshLambertMaterial color="#DDA0DD" />
      </Sphere>
    </>
  )
}

export default TugOfWarScene
