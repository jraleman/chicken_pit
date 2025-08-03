import React, { useState } from 'react';
import ChooseTeam, { type Team } from '../components/ChooseTeam';
import GameSettings, { type GameSettingsData } from '../components/GameSettings';

interface MainMenuSceneProps {
  onStartGame: (team: Team, settings: GameSettingsData) => void;
}

/**
 * Third scene: pick your side and settings, then hit “Play!”
 */
const MainMenuScene: React.FC<MainMenuSceneProps> = ({ onStartGame }) => {
  const [team, setTeam] = useState<Team | null>(null);
  const [settings, setSettings] = useState<GameSettingsData | null>(null);

  const handlePlay = () => {
    if (team && settings) {
      onStartGame(team, settings);
    } else {
      alert('Please select a team and set your options.');
    }
  };

  return (
    <div className="scene main-menu">
      <h1>3D Tug-O-War</h1>
      <ChooseTeam onSelectTeam={setTeam} />
      <GameSettings onStart={setSettings} />
      <button onClick={handlePlay}>Play!</button>
    </div>
  );
};

export default MainMenuScene;