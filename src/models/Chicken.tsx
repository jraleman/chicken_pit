import React, { useRef, Suspense } from 'react';
import { useFrame } from '@react-three/fiber';
import { useLoader } from '@react-three/fiber';
import { OBJLoader } from 'three-stdlib';
import { Mesh, MeshStandardMaterial } from 'three';

interface ChickenProps {
  position: [number, number, number];
  team: 'left' | 'right';
  isPulling?: boolean;
  color?: string;
}

const ChickenModel: React.FC<ChickenProps> = ({ position, team, isPulling = false, color }) => {
  const chickenRef = useRef<Mesh>(null);
  
  // Load the chicken OBJ model
  const obj = useLoader(OBJLoader, './assets/3d/chicken.obj');
  
  // Clone the geometry to avoid issues with multiple instances
  const clonedObj = obj.clone();
  
  // Apply color to all meshes in the model
  React.useEffect(() => {
    if (clonedObj && color) {
      clonedObj.traverse((child) => {
        if ((child as Mesh).isMesh) {
          // Create a new material with the team color
          (child as Mesh).material = new MeshStandardMaterial({ color });
        }
      });
    }
  }, [clonedObj, color]);
  
  // Animation for pulling effect
  useFrame((state) => {
    if (chickenRef.current && isPulling) {
      // Add a slight bobbing animation when pulling
      const time = state.clock.getElapsedTime();
      chickenRef.current.position.y = position[1] + Math.sin(time * 10) * 0.02;
      
      // Add slight rotation animation
      chickenRef.current.rotation.z = Math.sin(time * 8) * 0.05;
    } else if (chickenRef.current) {
      // Reset to base position when not pulling
      chickenRef.current.position.y = position[1];
      chickenRef.current.rotation.z = 0;
    }
  });

  return (
    <group ref={chickenRef} position={position}>
      <primitive 
        object={clonedObj} 
        scale={[0.5, 0.5, 0.5]}
        rotation={[0, team === 'right' ? Math.PI : 0, 0]} // Face the rope
      />
    </group>
  );
};

// Fallback component if model fails to load
const ChickenFallback: React.FC<ChickenProps> = ({ position, team, isPulling = false, color }) => {
  const chickenRef = useRef<Mesh>(null);

  // Animation for pulling effect
  useFrame((state) => {
    if (chickenRef.current && isPulling) {
      const time = state.clock.getElapsedTime();
      chickenRef.current.position.y = position[1] + Math.sin(time * 10) * 0.02;
      chickenRef.current.rotation.z = Math.sin(time * 8) * 0.05;
    } else if (chickenRef.current) {
      chickenRef.current.position.y = position[1];
      chickenRef.current.rotation.z = 0;
    }
  });

  return (
    <group ref={chickenRef} position={position}>
      {/* Simple cube as fallback */}
      <mesh rotation={[0, team === 'right' ? Math.PI : 0, 0]}>
        <boxGeometry args={[0.3, 0.4, 0.2]} />
        <meshStandardMaterial color={color || (team === 'left' ? '#ff6b6b' : '#4ecdc4')} />
      </mesh>
    </group>
  );
};

const Chicken: React.FC<ChickenProps> = (props) => {
  return (
    <Suspense fallback={<ChickenFallback {...props} />}>
      <ChickenModel {...props} />
    </Suspense>
  );
};

export default Chicken;
