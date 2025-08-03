import React from 'react';

const Post: React.FC<{ position: [number, number, number] }> = ({ position }) => (
  <mesh position={position}>
    <boxGeometry args={[0.2, 1, 0.2]} />
    <meshStandardMaterial color="gray" />
  </mesh>
);

export default Post;
