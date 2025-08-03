import React, { Suspense } from 'react';
import { useLoader } from '@react-three/fiber';
import { OBJLoader } from 'three-stdlib';

interface BarnProps {
  position?: [number, number, number];
  scale?: [number, number, number] | number;
  rotation?: [number, number, number];
}

const BarnModel: React.FC<BarnProps> = ({ 
  position = [0, 0, -10], 
  scale = [1, 1, 1],
  rotation = [0, 0, 0]
}) => {
  // Load the barn OBJ model
  const obj = useLoader(OBJLoader, '/assets/3d/barn.obj');
  
  // Clone the geometry to avoid issues with multiple instances
  const clonedObj = obj.clone();
  
  return (
    <primitive 
      object={clonedObj} 
      position={position}
      scale={scale}
      rotation={rotation}
    />
  );
};

const Barn: React.FC<BarnProps> = (props) => {
  return (
    <Suspense fallback={null}>
      <BarnModel {...props} />
    </Suspense>
  );
};

export default Barn;
