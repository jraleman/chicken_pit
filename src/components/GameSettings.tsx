import React, { useState } from 'react';

export type GameSettingsData = {
  ropeLength: number;
  ropeColor: string;
}

interface GameSettingsProps {
  onStart: (settings: GameSettingsData) => void;
}

/**
 * Form to configure rope length and color.
 */
const GameSettings: React.FC<GameSettingsProps> = ({ onStart }) => {
  const [ropeLength, setRopeLength] = useState(4);
  const [ropeColor, setRopeColor] = useState('#8b4513');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onStart({ ropeLength, ropeColor });
  };

  return (
    <form className="game-settings" onSubmit={handleSubmit}>
      <label>
        Rope Length:
        <input
          type="number"
          value={ropeLength}
          min={2}
          max={10}
          onChange={e => setRopeLength(parseInt(e.target.value, 10))}
        />
      </label>
      <label>
        Rope Color:
        <input
          type="color"
          value={ropeColor}
          onChange={e => setRopeColor(e.target.value)}
        />
      </label>
      <button type="submit">Apply &amp; Continue</button>
    </form>
  );
};

export default GameSettings;