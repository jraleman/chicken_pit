import React from 'react';
import ScrollingText from '../components/ScrollingText';

interface SlideshowSceneProps {
  onNext: () => void;
}

/**
 * First scene: scroll some intro text, then advance.
 */
const SlideshowScene: React.FC<SlideshowSceneProps> = ({ onNext }) => {
  const intro = `
The humid dawn air in Athens, Georgia,
trembled as the ER Nurse stepped onto the chicken-processing farm, 
stethoscope swinging by her side. 

Called for a patient in distress, 
she leaned over the edge of the vast chicken pit—and slipped. 

Feathers and clucks swirled as she sank into the cool muck, 
hidden from sight for hours. 

When rescuers at last hauled her out, 
she was rushed back to the very ER she served.

In her fevered haze, two figures emerged: 
the Blue Chicken, calm and guiding, 
and the Red Chicken, frantic and insistent. 

Blue whispered, “Breathe, steady your heart.” 
Red crowed, “Act now, shove through!” 

Instantly, the walls of her breakdown peeled away—she was free of the pit.
`;

  return <ScrollingText text={intro} duration={8} onEnd={onNext} />;
};

export default SlideshowScene;