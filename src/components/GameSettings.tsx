import React, { useState } from "react";
import { LEFT_TEAM_COLOR, RIGHT_TEAM_COLOR, ROPE_COLOR } from "../contants";

export type GameSettingsData = {
  ropeLength: number;
  ropeColor: string;
  leftTeamColor: string;
  rightTeamColor: string;
  gameMode: "singleplayer" | "multiplayer";
};

interface GameSettingsProps {
  onStart: (settings: GameSettingsData) => void;
}

const GameSettings: React.FC<GameSettingsProps> = ({ onStart }) => {
  const [ropeLength, setRopeLength] = useState(4);
  const [ropeColor, setRopeColor] = useState(ROPE_COLOR);
  const [leftTeamColor, setLeftTeamColor] = useState(LEFT_TEAM_COLOR);
  const [rightTeamColor, setRightTeamColor] = useState(RIGHT_TEAM_COLOR);
  const [gameMode, setGameMode] = useState<"singleplayer" | "multiplayer">(
    "singleplayer"
  );

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onStart({ ropeLength, ropeColor, leftTeamColor, rightTeamColor, gameMode });
  };

  const showAdvancedSettings = false;

  return (
    <form className="game-settings" onSubmit={handleSubmit}>
      <label>Game Mode:</label>
      <select
        value={gameMode}
        onChange={(e) =>
          setGameMode(e.target.value as "singleplayer" | "multiplayer")
        }
      >
        <option value="singleplayer">Single Player (vs CPU)</option>
        <option value="multiplayer">Local Multiplayer</option>
      </select>
      {showAdvancedSettings && (
        <>
          <label>Rope Length:</label>
          <input
            type="number"
            value={ropeLength}
            min={2}
            max={10}
            onChange={(e) => setRopeLength(parseInt(e.target.value, 10))}
          />
          <label>Rope Color:</label>
          <input
            type="color"
            value={ropeColor}
            onChange={(e) => setRopeColor(e.target.value)}
          />
          <label>Left Team Color:</label>
          <input
            type="color"
            value={leftTeamColor}
            onChange={(e) => setLeftTeamColor(e.target.value)}
          />
          <label>Right Team Color:</label>
          <input
            type="color"
            value={rightTeamColor}
            onChange={(e) => setRightTeamColor(e.target.value)}
          />
        </>
      )}
      <button type="submit">Apply &amp; Continue</button>
    </form>
  );
};

export default GameSettings;
