import React, { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import { Text, Box, Cylinder, Sphere } from '@react-three/drei'
import * as THREE from 'three'

const Chicken = ({ position, color, isLeft, ropePosition, winner, isGameActive }) => {
  const meshRef = useRef()
  const groupRef = useRef()
  const headRef = useRef()
  const combRef = useRef()
  const leftWingRef = useRef()
  const rightWingRef = useRef()
  const tailRef = useRef()
  const leftEyeRef = useRef()
  const rightEyeRef = useRef()
  
  useFrame((state) => {
    if (meshRef.current) {
      // Add subtle breathing animation to body
      meshRef.current.scale.y = 1 + Math.sin(state.clock.elapsedTime * 2) * 0.05
      meshRef.current.scale.x = 1 + Math.sin(state.clock.elapsedTime * 1.8) * 0.02
    }
    
    // Enhanced chicken head bobbing and movement
    if (headRef.current && combRef.current && isGameActive) {
      const bobAmount = Math.sin(state.clock.elapsedTime * 3) * 0.1
      const headTilt = Math.sin(state.clock.elapsedTime * 2) * 0.05
      headRef.current.position.y = 1.8 + bobAmount
      headRef.current.rotation.z = headTilt
      combRef.current.position.y = 2.1 + bobAmount
      combRef.current.rotation.z = headTilt
    }
    
    // Wing flapping animation during pulling
    if (leftWingRef.current && rightWingRef.current && isGameActive) {
      const flapIntensity = Math.abs(ropePosition) * 0.3 + 0.1
      const flapSpeed = 5 + Math.abs(ropePosition) * 0.5
      const flapAmount = Math.sin(state.clock.elapsedTime * flapSpeed) * flapIntensity
      
      leftWingRef.current.rotation.z = (isLeft ? -0.3 : 0.3) + flapAmount
      rightWingRef.current.rotation.z = (isLeft ? 0.3 : -0.3) - flapAmount
    }
    
    // Tail feather swaying
    if (tailRef.current && isGameActive) {
      const swayAmount = Math.sin(state.clock.elapsedTime * 1.5) * 0.2
      tailRef.current.rotation.y = swayAmount
    }
    
    // Eye blinking animation
    if (leftEyeRef.current && rightEyeRef.current && isGameActive) {
      const blinkTime = state.clock.elapsedTime % 3
      if (blinkTime > 2.8) {
        const blinkAmount = Math.sin((blinkTime - 2.8) * 50) * 0.5 + 0.5
        leftEyeRef.current.scale.y = 0.1 + blinkAmount * 0.9
        rightEyeRef.current.scale.y = 0.1 + blinkAmount * 0.9
      } else {
        leftEyeRef.current.scale.y = 1
        rightEyeRef.current.scale.y = 1
      }
    }
    
    if (groupRef.current) {
      // Check if this team should fall into the hole
      const isRedTeam = color === '#ff4757'
      const shouldFall = !isGameActive && winner && 
        ((winner === 'Blue Chickens' && isRedTeam) || 
         (winner === 'Red Chickens' && !isRedTeam))
      
      if (shouldFall) {
        // Falling animation - move toward center and down
        const currentY = groupRef.current.position.y
        const targetY = -5 // Fall into the hole
        const currentX = groupRef.current.position.x
        const targetX = 0 // Move toward center of hole
        
        if (currentY > targetY) {
          // Fall down with acceleration
          groupRef.current.position.y = Math.max(targetY, currentY - 0.1)
          // Move toward center
          groupRef.current.position.x = currentX + (targetX - currentX) * 0.02
          // Add spinning effect while falling (chickens flailing)
          groupRef.current.rotation.z += 0.15
          groupRef.current.rotation.x += 0.1
          
          // Frantic wing flapping while falling
          if (leftWingRef.current && rightWingRef.current) {
            const panicFlap = Math.sin(state.clock.elapsedTime * 20) * 0.8
            leftWingRef.current.rotation.z = panicFlap
            rightWingRef.current.rotation.z = -panicFlap
          }
        }
      } else if (isGameActive) {
        // Reset position and rotation when game is active (handles reset)
        groupRef.current.position.x = position[0]
        groupRef.current.position.y = position[1]
        groupRef.current.position.z = position[2]
        groupRef.current.rotation.x = 0
        
        // Normal leaning effect during game
        const leanAmount = Math.abs(ropePosition) * 0.05
        const leanDirection = ropePosition > 0 ? (isLeft ? -1 : 1) : (isLeft ? 1 : -1)
        groupRef.current.rotation.z = leanDirection * leanAmount
      } else if (!winner) {
        // Game is not active but no winner yet (reset state)
        groupRef.current.position.x = position[0]
        groupRef.current.position.y = position[1]
        groupRef.current.position.z = position[2]
        groupRef.current.rotation.x = 0
        groupRef.current.rotation.z = 0
      }
    }
  })

  const mainColor = color
  const accentColor = color === '#ff4757' ? '#ff6b6b' : '#4834d4'
  const featherColor = color === '#ff4757' ? '#ff8a80' : '#7986cb'
  const darkFeatherColor = color === '#ff4757' ? '#cc2e2e' : '#2c2c7a'

  return (
    <group ref={groupRef} position={position}>
      {/* Chicken body - main oval shaped body */}
      <Sphere ref={meshRef} args={[0.6, 0.8, 0.5]} position={[0, 0.6, 0]} scale={[1, 1.2, 0.8]}>
        <meshLambertMaterial color={mainColor} />
      </Sphere>
      
      {/* Body feather details - overlapping smaller spheres for texture */}
      <Sphere args={[0.15]} position={[-0.3, 0.4, 0.4]}>
        <meshLambertMaterial color={featherColor} />
      </Sphere>
      <Sphere args={[0.15]} position={[0.3, 0.4, 0.4]}>
        <meshLambertMaterial color={featherColor} />
      </Sphere>
      <Sphere args={[0.12]} position={[0, 0.8, 0.45]}>
        <meshLambertMaterial color={featherColor} />
      </Sphere>
      <Sphere args={[0.1]} position={[-0.2, 0.7, 0.5]}>
        <meshLambertMaterial color={darkFeatherColor} />
      </Sphere>
      <Sphere args={[0.1]} position={[0.2, 0.7, 0.5]}>
        <meshLambertMaterial color={darkFeatherColor} />
      </Sphere>
      
      {/* Chicken neck */}
      <Cylinder args={[0.25, 0.35, 0.4]} position={[0, 1.4, 0]}>
        <meshLambertMaterial color={accentColor} />
      </Cylinder>
      
      {/* Chicken head */}
      <Sphere ref={headRef} args={[0.35]} position={[0, 1.8, 0]}>
        <meshLambertMaterial color={accentColor} />
      </Sphere>
      
      {/* Head feather details */}
      <Sphere args={[0.08]} position={[-0.2, 1.9, 0.2]}>
        <meshLambertMaterial color={featherColor} />
      </Sphere>
      <Sphere args={[0.08]} position={[0.2, 1.9, 0.2]}>
        <meshLambertMaterial color={featherColor} />
      </Sphere>
      
      {/* Enhanced chicken beak - upper and lower parts */}
      <Cylinder args={[0.02, 0.08, 0.3]} position={[0, 1.85, 0.35]} rotation={[Math.PI/2, 0, 0]}>
        <meshLambertMaterial color="#FFA500" />
      </Cylinder>
      <Cylinder args={[0.015, 0.06, 0.25]} position={[0, 1.75, 0.33]} rotation={[Math.PI/2, 0, 0]}>
        <meshLambertMaterial color="#FF8C00" />
      </Cylinder>
      
      {/* Nostrils */}
      <Sphere args={[0.015]} position={[-0.02, 1.82, 0.47]}>
        <meshLambertMaterial color="#000000" />
      </Sphere>
      <Sphere args={[0.015]} position={[0.02, 1.82, 0.47]}>
        <meshLambertMaterial color="#000000" />
      </Sphere>
      
      {/* Multi-part chicken comb (more realistic) */}
      <group ref={combRef} position={[0, 2.1, 0]}>
        <Sphere args={[0.12, 0.18, 0.08]} position={[0, 0, 0]} scale={[1, 1.5, 0.5]}>
          <meshLambertMaterial color="#FF0000" />
        </Sphere>
        <Sphere args={[0.08, 0.12, 0.06]} position={[-0.08, 0.05, 0]}>
          <meshLambertMaterial color="#CC0000" />
        </Sphere>
        <Sphere args={[0.08, 0.12, 0.06]} position={[0.08, 0.05, 0]}>
          <meshLambertMaterial color="#CC0000" />
        </Sphere>
        <Sphere args={[0.06, 0.08, 0.04]} position={[0, 0.08, 0]}>
          <meshLambertMaterial color="#FF0000" />
        </Sphere>
      </group>
      
      {/* Enhanced chicken wattles */}
      <Sphere args={[0.08, 0.12, 0.06]} position={[-0.12, 1.55, 0.25]} rotation={[0.2, 0, 0]}>
        <meshLambertMaterial color="#FF0000" />
      </Sphere>
      <Sphere args={[0.08, 0.12, 0.06]} position={[0.12, 1.55, 0.25]} rotation={[0.2, 0, 0]}>
        <meshLambertMaterial color="#FF0000" />
      </Sphere>
      
      {/* Detailed wings with multiple feather layers */}
      <group ref={leftWingRef} position={[isLeft ? 0.6 : -0.6, 0.8, 0]} rotation={[0, 0, isLeft ? -0.3 : 0.3]}>
        <Sphere args={[0.25, 0.4, 0.15]}>
          <meshLambertMaterial color={featherColor} />
        </Sphere>
        <Sphere args={[0.2, 0.3, 0.1]} position={[0, 0, 0.1]}>
          <meshLambertMaterial color={darkFeatherColor} />
        </Sphere>
        <Sphere args={[0.15, 0.25, 0.08]} position={[0, -0.1, 0.15]}>
          <meshLambertMaterial color={mainColor} />
        </Sphere>
      </group>
      
      <group ref={rightWingRef} position={[isLeft ? -0.6 : 0.6, 0.8, 0]} rotation={[0, 0, isLeft ? 0.3 : -0.3]}>
        <Sphere args={[0.25, 0.4, 0.15]}>
          <meshLambertMaterial color={featherColor} />
        </Sphere>
        <Sphere args={[0.2, 0.3, 0.1]} position={[0, 0, 0.1]}>
          <meshLambertMaterial color={darkFeatherColor} />
        </Sphere>
        <Sphere args={[0.15, 0.25, 0.08]} position={[0, -0.1, 0.15]}>
          <meshLambertMaterial color={mainColor} />
        </Sphere>
      </group>
      
      {/* Enhanced chicken legs with joints */}
      <group position={[-0.15, -0.3, 0]}>
        <Cylinder args={[0.06, 0.04, 0.35]} position={[0, 0.15, 0]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
        <Sphere args={[0.05]} position={[0, -0.05, 0]}>
          <meshLambertMaterial color="#FFA500" />
        </Sphere>
        <Cylinder args={[0.04, 0.03, 0.25]} position={[0, -0.25, 0]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
      </group>
      
      <group position={[0.15, -0.3, 0]}>
        <Cylinder args={[0.06, 0.04, 0.35]} position={[0, 0.15, 0]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
        <Sphere args={[0.05]} position={[0, -0.05, 0]}>
          <meshLambertMaterial color="#FFA500" />
        </Sphere>
        <Cylinder args={[0.04, 0.03, 0.25]} position={[0, -0.25, 0]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
      </group>
      
      {/* Detailed chicken feet with toes */}
      <group position={[-0.15, -0.65, 0.05]}>
        <Sphere args={[0.1, 0.05, 0.15]}>
          <meshLambertMaterial color="#FFD700" />
        </Sphere>
        {/* Toes */}
        <Cylinder args={[0.01, 0.01, 0.12]} position={[0, 0, 0.15]} rotation={[Math.PI/6, 0, 0]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
        <Cylinder args={[0.01, 0.01, 0.1]} position={[-0.05, 0, 0.12]} rotation={[Math.PI/6, 0, -Math.PI/6]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
        <Cylinder args={[0.01, 0.01, 0.1]} position={[0.05, 0, 0.12]} rotation={[Math.PI/6, 0, Math.PI/6]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
        <Cylinder args={[0.008, 0.008, 0.08]} position={[0, 0, -0.08]} rotation={[-Math.PI/6, 0, 0]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
      </group>
      
      <group position={[0.15, -0.65, 0.05]}>
        <Sphere args={[0.1, 0.05, 0.15]}>
          <meshLambertMaterial color="#FFD700" />
        </Sphere>
        {/* Toes */}
        <Cylinder args={[0.01, 0.01, 0.12]} position={[0, 0, 0.15]} rotation={[Math.PI/6, 0, 0]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
        <Cylinder args={[0.01, 0.01, 0.1]} position={[-0.05, 0, 0.12]} rotation={[Math.PI/6, 0, -Math.PI/6]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
        <Cylinder args={[0.01, 0.01, 0.1]} position={[0.05, 0, 0.12]} rotation={[Math.PI/6, 0, Math.PI/6]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
        <Cylinder args={[0.008, 0.008, 0.08]} position={[0, 0, -0.08]} rotation={[-Math.PI/6, 0, 0]}>
          <meshLambertMaterial color="#FFD700" />
        </Cylinder>
      </group>
      
      {/* Enhanced tail feathers with multiple layers */}
      <group ref={tailRef} position={[0, 0.8, -0.6]} rotation={[0.5, 0, 0]}>
        <Sphere args={[0.2, 0.4, 0.1]}>
          <meshLambertMaterial color={featherColor} />
        </Sphere>
        <Sphere args={[0.15, 0.35, 0.08]} position={[0, 0.05, 0.05]}>
          <meshLambertMaterial color={darkFeatherColor} />
        </Sphere>
        <Sphere args={[0.1, 0.25, 0.06]} position={[0, 0.1, 0.1]}>
          <meshLambertMaterial color={mainColor} />
        </Sphere>
        {/* Individual tail feathers */}
        <Cylinder args={[0.02, 0.02, 0.2]} position={[-0.1, 0.15, 0]} rotation={[0, 0, -0.3]}>
          <meshLambertMaterial color={darkFeatherColor} />
        </Cylinder>
        <Cylinder args={[0.02, 0.02, 0.2]} position={[0.1, 0.15, 0]} rotation={[0, 0, 0.3]}>
          <meshLambertMaterial color={darkFeatherColor} />
        </Cylinder>
        <Cylinder args={[0.025, 0.025, 0.25]} position={[0, 0.2, 0]}>
          <meshLambertMaterial color={featherColor} />
        </Cylinder>
      </group>
      
      {/* Detailed eyes with pupils and iris */}
      <group ref={leftEyeRef} position={[-0.15, 1.9, 0.25]}>
        <Sphere args={[0.06]}>
          <meshLambertMaterial color="#FFFFFF" />
        </Sphere>
        <Sphere args={[0.03]} position={[0, 0, 0.04]}>
          <meshLambertMaterial color="#4A4A4A" />
        </Sphere>
        <Sphere args={[0.015]} position={[0, 0, 0.055]}>
          <meshLambertMaterial color="#000000" />
        </Sphere>
        <Sphere args={[0.008]} position={[0.008, 0.008, 0.06]}>
          <meshLambertMaterial color="#FFFFFF" />
        </Sphere>
      </group>
      
      <group ref={rightEyeRef} position={[0.15, 1.9, 0.25]}>
        <Sphere args={[0.06]}>
          <meshLambertMaterial color="#FFFFFF" />
        </Sphere>
        <Sphere args={[0.03]} position={[0, 0, 0.04]}>
          <meshLambertMaterial color="#4A4A4A" />
        </Sphere>
        <Sphere args={[0.015]} position={[0, 0, 0.055]}>
          <meshLambertMaterial color="#000000" />
        </Sphere>
        <Sphere args={[0.008]} position={[-0.008, 0.008, 0.06]}>
          <meshLambertMaterial color="#FFFFFF" />
        </Sphere>
      </group>
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
  const grassRef = useRef()
  
  useFrame((state) => {
    // Gentle grass swaying animation
    if (grassRef.current) {
      grassRef.current.children.forEach((grass, index) => {
        const offset = index * 0.1
        grass.rotation.z = Math.sin(state.clock.elapsedTime * 0.5 + offset) * 0.05
      })
    }
  })

  // Generate random grass positions
  const grassPositions = useMemo(() => {
    const positions = []
    for (let i = 0; i < 200; i++) {
      const x = (Math.random() - 0.5) * 24 // Spread across the field
      const z = (Math.random() - 0.5) * 20
      // Don't place grass too close to the hole
      const distanceFromCenter = Math.sqrt(x * x + z * z)
      if (distanceFromCenter > 2.5) {
        positions.push([x, 0.05, z])
      }
    }
    return positions
  }, [])

  return (
    <group>
      {/* Main field base - single continuous ground */}
      <Box args={[24, 0.4, 20]} position={[0, -0.2, 0]}>
        <meshLambertMaterial color="#2d5016" />
      </Box>
      
      {/* Grass texture layer */}
      <Box args={[24, 0.02, 20]} position={[0, 0.01, 0]}>
        <meshLambertMaterial color="#4a7c2a" />
      </Box>
      
      {/* Additional grass texture patches */}
      <Box args={[22, 0.01, 18]} position={[0, 0.02, 0]}>
        <meshLambertMaterial color="#5d8f3a" />
      </Box>
      
      {/* Individual grass blades */}
      <group ref={grassRef}>
        {grassPositions.map((position, index) => (
          <Cylinder
            key={index}
            args={[0.01, 0.02, Math.random() * 0.3 + 0.1]}
            position={[position[0], position[1] + (Math.random() * 0.15 + 0.05), position[2]]}
            rotation={[Math.random() * 0.2 - 0.1, Math.random() * Math.PI, Math.random() * 0.2 - 0.1]}
          >
            <meshLambertMaterial color={`hsl(${90 + Math.random() * 20}, ${70 + Math.random() * 30}%, ${25 + Math.random() * 15}%)`} />
          </Cylinder>
        ))}
      </group>
      
      {/* Flower patches scattered around */}
      <group>
        {Array.from({ length: 20 }, (_, i) => {
          const angle = (i / 20) * Math.PI * 2
          const radius = 8 + Math.random() * 6
          const x = Math.cos(angle) * radius
          const z = Math.sin(angle) * radius
          return (
            <group key={i} position={[x, 0.05, z]}>
              <Sphere args={[0.03]} position={[0, 0.05, 0]}>
                <meshLambertMaterial color={['#ffeb3b', '#e91e63', '#9c27b0', '#2196f3', '#ff5722'][Math.floor(Math.random() * 5)]} />
              </Sphere>
              <Cylinder args={[0.005, 0.005, 0.08]} position={[0, 0, 0]}>
                <meshLambertMaterial color="#4caf50" />
              </Cylinder>
            </group>
          )
        })}
      </group>
      
      {/* THE HOLE - Hollow cylinder that goes deep */}
      <group>
        {/* Hole opening - ring shape */}
        <Cylinder args={[2.2, 2.2, 0.1]} position={[0, 0, 0]}>
          <meshLambertMaterial color="#3e2723" />
        </Cylinder>
        
        {/* Inner hole rim - worn dirt edge */}
        <Cylinder args={[2.05, 2.05, 0.05]} position={[0, -0.025, 0]}>
          <meshLambertMaterial color="#5d4037" />
        </Cylinder>
        
        {/* Hole walls - multiple layers going down */}
        <Cylinder args={[2, 1.9, 1]} position={[0, -0.5, 0]}>
          <meshLambertMaterial color="#1a1a1a" />
        </Cylinder>
        <Cylinder args={[1.9, 1.8, 1]} position={[0, -1.5, 0]}>
          <meshLambertMaterial color="#0d0d0d" />
        </Cylinder>
        <Cylinder args={[1.8, 1.7, 1]} position={[0, -2.5, 0]}>
          <meshLambertMaterial color="#050505" />
        </Cylinder>
        <Cylinder args={[1.7, 1.6, 2]} position={[0, -4, 0]}>
          <meshLambertMaterial color="#000000" />
        </Cylinder>
        
        {/* Bottom of hole - complete darkness */}
        <Cylinder args={[1.6, 1.6, 0.1]} position={[0, -5.05, 0]}>
          <meshLambertMaterial color="#000000" />
        </Cylinder>
        
        {/* Spooky mist effects around hole edge */}
        <Sphere args={[2.3]} position={[0, -0.1, 0]}>
          <meshLambertMaterial color="#424242" transparent opacity={0.08} />
        </Sphere>
        <Sphere args={[2.1]} position={[0, -0.2, 0]}>
          <meshLambertMaterial color="#303030" transparent opacity={0.12} />
        </Sphere>
        <Sphere args={[1.9]} position={[0, -0.3, 0]}>
          <meshLambertMaterial color="#1a1a1a" transparent opacity={0.15} />
        </Sphere>
        
        {/* Floating dirt particles around hole */}
        {Array.from({ length: 15 }, (_, i) => {
          const angle = (i / 15) * Math.PI * 2
          const radius = 2.3 + Math.random() * 0.5
          const x = Math.cos(angle) * radius
          const z = Math.sin(angle) * radius
          return (
            <Sphere key={i} args={[0.02]} position={[x, 0.1 + Math.random() * 0.1, z]}>
              <meshLambertMaterial color="#795548" transparent opacity={0.6} />
            </Sphere>
          )
        })}
      </group>
      
      {/* Field markings - center line split around the hole */}
      <Box args={[0.1, 0.05, 4]} position={[-1.5, 0.05, 0]}>
        <meshLambertMaterial color="#FFFFFF" />
      </Box>
      <Box args={[0.1, 0.05, 4]} position={[1.5, 0.05, 0]}>
        <meshLambertMaterial color="#FFFFFF" />
      </Box>
      
      {/* Goal lines with corner flags */}
      <group>
        {/* Red team goal line */}
        <Box args={[0.15, 0.05, 12]} position={[-10, 0.05, 0]}>
          <meshLambertMaterial color="#FF0000" />
        </Box>
        {/* Red team corner flags */}
        <Cylinder args={[0.02, 0.02, 1]} position={[-10, 0.5, 6]}>
          <meshLambertMaterial color="#8B4513" />
        </Cylinder>
        <Box args={[0.3, 0.2, 0.01]} position={[-10, 0.9, 6]}>
          <meshLambertMaterial color="#FF0000" />
        </Box>
        <Cylinder args={[0.02, 0.02, 1]} position={[-10, 0.5, -6]}>
          <meshLambertMaterial color="#8B4513" />
        </Cylinder>
        <Box args={[0.3, 0.2, 0.01]} position={[-10, 0.9, -6]}>
          <meshLambertMaterial color="#FF0000" />
        </Box>
      </group>
      
      <group>
        {/* Blue team goal line */}
        <Box args={[0.15, 0.05, 12]} position={[10, 0.05, 0]}>
          <meshLambertMaterial color="#0000FF" />
        </Box>
        {/* Blue team corner flags */}
        <Cylinder args={[0.02, 0.02, 1]} position={[10, 0.5, 6]}>
          <meshLambertMaterial color="#8B4513" />
        </Cylinder>
        <Box args={[0.3, 0.2, 0.01]} position={[10, 0.9, 6]}>
          <meshLambertMaterial color="#0000FF" />
        </Box>
        <Cylinder args={[0.02, 0.02, 1]} position={[10, 0.5, -6]}>
          <meshLambertMaterial color="#8B4513" />
        </Cylinder>
        <Box args={[0.3, 0.2, 0.01]} position={[10, 0.9, -6]}>
          <meshLambertMaterial color="#0000FF" />
        </Box>
      </group>
      
      {/* Warning signs around the hole - more detailed */}
      <group>
        {/* Warning sign posts */}
        <Cylinder args={[0.05, 0.05, 0.8]} position={[0, 0.4, 3]}>
          <meshLambertMaterial color="#8B4513" />
        </Cylinder>
        <Box args={[1, 0.4, 0.05]} position={[0, 0.7, 3]}>
          <meshLambertMaterial color="#FFFF00" />
        </Box>
        <Text
          position={[0, 0.7, 3.03]}
          fontSize={0.15}
          color="#FF0000"
          anchorX="center"
          anchorY="middle"
        >
          ⚠️ DANGER PIT ⚠️
        </Text>
        
        <Cylinder args={[0.05, 0.05, 0.8]} position={[0, 0.4, -3]}>
          <meshLambertMaterial color="#8B4513" />
        </Cylinder>
        <Box args={[1, 0.4, 0.05]} position={[0, 0.7, -3]}>
          <meshLambertMaterial color="#FFFF00" />
        </Box>
        <Text
          position={[0, 0.7, -3.03]}
          fontSize={0.15}
          color="#FF0000"
          anchorX="center"
          anchorY="middle"
        >
          ⚠️ DANGER PIT ⚠️
        </Text>
        
        {/* Side warning signs */}
        <Cylinder args={[0.05, 0.05, 0.8]} position={[3, 0.4, 0]} rotation={[0, Math.PI/2, 0]}>
          <meshLambertMaterial color="#8B4513" />
        </Cylinder>
        <Box args={[0.05, 0.4, 1]} position={[3, 0.7, 0]}>
          <meshLambertMaterial color="#FFFF00" />
        </Box>
        
        <Cylinder args={[0.05, 0.05, 0.8]} position={[-3, 0.4, 0]} rotation={[0, Math.PI/2, 0]}>
          <meshLambertMaterial color="#8B4513" />
        </Cylinder>
        <Box args={[0.05, 0.4, 1]} position={[-3, 0.7, 0]}>
          <meshLambertMaterial color="#FFFF00" />
        </Box>
      </group>
      
      {/* Rock decorations around field edges */}
      {Array.from({ length: 25 }, (_, i) => {
        const angle = (i / 25) * Math.PI * 2
        const radius = 11 + Math.random() * 2
        const x = Math.cos(angle) * radius
        const z = Math.sin(angle) * radius
        return (
          <Sphere 
            key={i} 
            args={[0.1 + Math.random() * 0.1]} 
            position={[x, -0.05 + Math.random() * 0.1, z]}
            scale={[1, 0.5 + Math.random() * 0.3, 1]}
          >
            <meshLambertMaterial color={`hsl(${20 + Math.random() * 40}, ${30 + Math.random() * 20}%, ${15 + Math.random() * 15}%)`} />
          </Sphere>
        )
      })}
    </group>
  )
}

const TugOfWarScene = ({ ropePosition, winner, isGameActive }) => {
  // Calculate player positions based on rope position
  // Red team players move with the rope (negative direction)
  const redBasePosition = -6 + ropePosition * 0.3 // Players move less than the rope for realism
  
  // Blue team players move with the rope (positive direction)  
  const blueBasePosition = 6 + ropePosition * 0.3

  return (
    <>
      <Ground />
      
      {/* Red team chickens - positions adjust with rope */}
      <Chicken 
        position={[redBasePosition, 0, 1]} 
        color="#ff4757" 
        isLeft={true} 
        ropePosition={ropePosition}
        winner={winner}
        isGameActive={isGameActive}
      />
      <Chicken 
        position={[redBasePosition - 1, 0, -1]} 
        color="#ff4757" 
        isLeft={true} 
        ropePosition={ropePosition}
        winner={winner}
        isGameActive={isGameActive}
      />
      <Chicken 
        position={[redBasePosition - 2, 0, 0]} 
        color="#ff4757" 
        isLeft={true} 
        ropePosition={ropePosition}
        winner={winner}
        isGameActive={isGameActive}
      />
      
      {/* Blue team chickens - positions adjust with rope */}
      <Chicken 
        position={[blueBasePosition, 0, 1]} 
        color="#3742fa" 
        isLeft={false} 
        ropePosition={ropePosition}
        winner={winner}
        isGameActive={isGameActive}
      />
      <Chicken 
        position={[blueBasePosition + 1, 0, -1]} 
        color="#3742fa" 
        isLeft={false} 
        ropePosition={ropePosition}
        winner={winner}
        isGameActive={isGameActive}
      />
      <Chicken 
        position={[blueBasePosition + 2, 0, 0]} 
        color="#3742fa" 
        isLeft={false} 
        ropePosition={ropePosition}
        winner={winner}
        isGameActive={isGameActive}
      />
      
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
        🐔 RED CHICKENS 🐔
      </Text>
      
      <Text
        position={[blueBasePosition, 3, 0]}
        fontSize={0.8}
        color="#3742fa"
        anchorX="center"
        anchorY="middle"
      >
        🐔 BLUE CHICKENS 🐔
      </Text>
      
      {/* Decorative elements */}
      {/* Enhanced Chicken Spectators */}
      {/* Left side spectator chickens */}
      <group position={[-10, 0, 3]}>
        {/* Body */}
        <Sphere args={[0.4, 0.5, 0.3]} position={[0, 0.4, 0]} scale={[1, 1.2, 0.8]}>
          <meshLambertMaterial color="#FFB6C1" />
        </Sphere>
        {/* Head */}
        <Sphere args={[0.2]} position={[0, 1, 0]}>
          <meshLambertMaterial color="#FF69B4" />
        </Sphere>
        {/* Beak */}
        <Cylinder args={[0.01, 0.04, 0.15]} position={[0, 1, 0.2]} rotation={[Math.PI/2, 0, 0]}>
          <meshLambertMaterial color="#FFA500" />
        </Cylinder>
        {/* Comb */}
        <Sphere args={[0.08, 0.1, 0.04]} position={[0, 1.15, 0]}>
          <meshLambertMaterial color="#FF0000" />
        </Sphere>
        {/* Wings */}
        <Sphere args={[0.15, 0.2, 0.08]} position={[-0.3, 0.5, 0]} rotation={[0, 0, -0.2]}>
          <meshLambertMaterial color="#FF8FA3" />
        </Sphere>
        <Sphere args={[0.15, 0.2, 0.08]} position={[0.3, 0.5, 0]} rotation={[0, 0, 0.2]}>
          <meshLambertMaterial color="#FF8FA3" />
        </Sphere>
        {/* Tail */}
        <Sphere args={[0.1, 0.2, 0.05]} position={[0, 0.5, -0.35]} rotation={[0.3, 0, 0]}>
          <meshLambertMaterial color="#FF8FA3" />
        </Sphere>
      </group>
      
      <group position={[-10, 0, -3]}>
        {/* Body */}
        <Sphere args={[0.4, 0.5, 0.3]} position={[0, 0.4, 0]} scale={[1, 1.2, 0.8]}>
          <meshLambertMaterial color="#98FB98" />
        </Sphere>
        {/* Head */}
        <Sphere args={[0.2]} position={[0, 1, 0]}>
          <meshLambertMaterial color="#90EE90" />
        </Sphere>
        {/* Beak */}
        <Cylinder args={[0.01, 0.04, 0.15]} position={[0, 1, 0.2]} rotation={[Math.PI/2, 0, 0]}>
          <meshLambertMaterial color="#FFA500" />
        </Cylinder>
        {/* Comb */}
        <Sphere args={[0.08, 0.1, 0.04]} position={[0, 1.15, 0]}>
          <meshLambertMaterial color="#FF0000" />
        </Sphere>
        {/* Wings */}
        <Sphere args={[0.15, 0.2, 0.08]} position={[-0.3, 0.5, 0]} rotation={[0, 0, -0.2]}>
          <meshLambertMaterial color="#ADFFAD" />
        </Sphere>
        <Sphere args={[0.15, 0.2, 0.08]} position={[0.3, 0.5, 0]} rotation={[0, 0, 0.2]}>
          <meshLambertMaterial color="#ADFFAD" />
        </Sphere>
        {/* Tail */}
        <Sphere args={[0.1, 0.2, 0.05]} position={[0, 0.5, -0.35]} rotation={[0.3, 0, 0]}>
          <meshLambertMaterial color="#ADFFAD" />
        </Sphere>
      </group>
      
      {/* Right side spectator chickens */}
      <group position={[10, 0, 3]}>
        {/* Body */}
        <Sphere args={[0.4, 0.5, 0.3]} position={[0, 0.4, 0]} scale={[1, 1.2, 0.8]}>
          <meshLambertMaterial color="#87CEEB" />
        </Sphere>
        {/* Head */}
        <Sphere args={[0.2]} position={[0, 1, 0]}>
          <meshLambertMaterial color="#4169E1" />
        </Sphere>
        {/* Beak */}
        <Cylinder args={[0.01, 0.04, 0.15]} position={[0, 1, 0.2]} rotation={[Math.PI/2, 0, 0]}>
          <meshLambertMaterial color="#FFA500" />
        </Cylinder>
        {/* Comb */}
        <Sphere args={[0.08, 0.1, 0.04]} position={[0, 1.15, 0]}>
          <meshLambertMaterial color="#FF0000" />
        </Sphere>
        {/* Wings */}
        <Sphere args={[0.15, 0.2, 0.08]} position={[-0.3, 0.5, 0]} rotation={[0, 0, -0.2]}>
          <meshLambertMaterial color="#9FD5FF" />
        </Sphere>
        <Sphere args={[0.15, 0.2, 0.08]} position={[0.3, 0.5, 0]} rotation={[0, 0, 0.2]}>
          <meshLambertMaterial color="#9FD5FF" />
        </Sphere>
        {/* Tail */}
        <Sphere args={[0.1, 0.2, 0.05]} position={[0, 0.5, -0.35]} rotation={[0.3, 0, 0]}>
          <meshLambertMaterial color="#9FD5FF" />
        </Sphere>
      </group>
      
      <group position={[10, 0, -3]}>
        {/* Body */}
        <Sphere args={[0.4, 0.5, 0.3]} position={[0, 0.4, 0]} scale={[1, 1.2, 0.8]}>
          <meshLambertMaterial color="#DDA0DD" />
        </Sphere>
        {/* Head */}
        <Sphere args={[0.2]} position={[0, 1, 0]}>
          <meshLambertMaterial color="#9370DB" />
        </Sphere>
        {/* Beak */}
        <Cylinder args={[0.01, 0.04, 0.15]} position={[0, 1, 0.2]} rotation={[Math.PI/2, 0, 0]}>
          <meshLambertMaterial color="#FFA500" />
        </Cylinder>
        {/* Comb */}
        <Sphere args={[0.08, 0.1, 0.04]} position={[0, 1.15, 0]}>
          <meshLambertMaterial color="#FF0000" />
        </Sphere>
        {/* Wings */}
        <Sphere args={[0.15, 0.2, 0.08]} position={[-0.3, 0.5, 0]} rotation={[0, 0, -0.2]}>
          <meshLambertMaterial color="#E6B3E6" />
        </Sphere>
        <Sphere args={[0.15, 0.2, 0.08]} position={[0.3, 0.5, 0]} rotation={[0, 0, 0.2]}>
          <meshLambertMaterial color="#E6B3E6" />
        </Sphere>
        {/* Tail */}
        <Sphere args={[0.1, 0.2, 0.05]} position={[0, 0.5, -0.35]} rotation={[0.3, 0, 0]}>
          <meshLambertMaterial color="#E6B3E6" />
        </Sphere>
      </group>
    </>
  )
}

export default TugOfWarScene
