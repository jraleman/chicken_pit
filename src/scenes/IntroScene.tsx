import { Canvas } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import { useEffect } from 'react';

interface IntroSceneProps {
  onNext: () => void;
}

/**
 * Second scene: show a simple 3D rope for a few seconds.
 */
const IntroScene: React.FC<IntroSceneProps> = ({ onNext }) => {
  useEffect(() => {
    const id = setTimeout(onNext, 5000);
    return () => clearTimeout(id);
  }, [onNext]);

  return (
    <div className="scene intro">
      <Canvas camera={{ position: [0, 2, 6] }}>
        <ambientLight intensity={0.5} />
        <directionalLight position={[5, 5, 5]} />
        {/* Rope as a long cylinder */}
        <mesh position={[0, 0, 0]}>
          <cylinderGeometry args={[0.1, 0.1, 4, 16]} />
          <meshStandardMaterial color="#8b4513" />
        </mesh>
        <OrbitControls enablePan={false} enableZoom={false} />
      </Canvas>
    </div>
  );
};

export default IntroScene;