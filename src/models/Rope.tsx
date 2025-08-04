import React, { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { Mesh } from 'three';

const Rope: React.FC<{
  ropeLength: number;
  color: string;
  ropePos: number;
}> = ({ ropeLength, color, ropePos }) => {
  const ref = useRef<Mesh>(null!);
  useFrame(() => {
    if (ref.current) {
      ref.current.position.x = ropePos;
    }
  });
  return (
    <mesh ref={ref} rotation={[0, 0, Math.PI / 2]}>
      <cylinderGeometry args={[0.05, 0.05, ropeLength, 12]} />
      <meshStandardMaterial color={color} />
    </mesh>
  );
};

export default Rope;