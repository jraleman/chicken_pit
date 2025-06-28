import React, { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import { Text, Box, Cylinder, Sphere } from '@react-three/drei'
import * as THREE from 'three'

const Player = ({ position, color, isLeft, ropePosition }) => {
  const meshRef = useRef()
  const groupRef = useRef()
  
  useFrame((state) => {
    if (meshRef.current) {
      // Add subtle breathing animation
      meshRef.current.scale.y = 1 + Math.sin(state.clock.elapsedTime * 2) * 0.05
    }
    
    if (groupRef.current) {
      // Add leaning effect based on rope tension
      const leanAmount = Math.abs(ropePosition) * 0.05
      const leanDirection = ropePosition > 0 ? (isLeft ? -1 : 1) : (isLeft ? 1 : -1)
      groupRef.current.rotation.z = leanDirection * leanAmount
    }
  })

  return (
    <group ref={groupRef} position={position}>
      {/* Player body */}
      <Box ref={meshRef} args={[0.8, 1.5, 0.4]} position={[0, 0.75, 0]}>
        <meshLambertMaterial color={color} />
      </Box>
      
      {/* Player head */}
      <Sphere args={[0.3]} position={[0, 1.8, 0]}>
        <meshLambertMaterial color={color === '#ff4757' ? '#ff6b6b' : '#4834d4'} />
      </Sphere>
      
      {/* Arms - positioned for pulling */}
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
  // Calculate player positions based on rope position
  // Red team players move with the rope (negative direction)
  const redBasePosition = -6 + ropePosition * 0.3 // Players move less than the rope for realism
  
  // Blue team players move with the rope (positive direction)  
  const blueBasePosition = 6 + ropePosition * 0.3

  return (
    <>
      <Ground />
      
      {/* Red team players - positions adjust with rope */}
      <Player position={[redBasePosition, 0, 1]} color="#ff4757" isLeft={true} ropePosition={ropePosition} />
      <Player position={[redBasePosition - 1, 0, -1]} color="#ff4757" isLeft={true} ropePosition={ropePosition} />
      <Player position={[redBasePosition - 2, 0, 0]} color="#ff4757" isLeft={true} ropePosition={ropePosition} />
      
      {/* Blue team players - positions adjust with rope */}
      <Player position={[blueBasePosition, 0, 1]} color="#3742fa" isLeft={false} ropePosition={ropePosition} />
      <Player position={[blueBasePosition + 1, 0, -1]} color="#3742fa" isLeft={false} ropePosition={ropePosition} />
      <Player position={[blueBasePosition + 2, 0, 0]} color="#3742fa" isLeft={false} ropePosition={ropePosition} />
      
      {/* Rope */}
      <Rope ropePosition={ropePosition} />
      
      {/* Team labels - also move with teams */}
      <Text
        position={[redBasePosition, 3, 0]}
        fontSize={0.8}
        color="#ff4757"
        anchorX="center"
        anchorY="middle"
      >
        RED TEAM
      </Text>
      
      <Text
        position={[blueBasePosition, 3, 0]}
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
