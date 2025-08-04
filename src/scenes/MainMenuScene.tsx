import React, { useState } from 'react';
import ChooseTeam, { type Team } from '../components/ChooseTeam';
import GameSettings, { type GameSettingsData } from '../components/GameSettings';
import { GAME_TITLE, GAME_SETTINGS } from '../contants';

interface MainMenuSceneProps {
  onStartGame: (team: Team, settings: GameSettingsData) => void;
}

const MainMenuScene: React.FC<MainMenuSceneProps> = ({ onStartGame }) => {
  const [team, setTeam] = useState<Team | null>('left');
  const [settings, setSettings] = useState<GameSettingsData | null>(GAME_SETTINGS);

  const handlePlay = () => {
    if (settings && (settings.gameMode === 'multiplayer' || team)) {
      // In multiplayer mode, team selection is not needed, so we can use 'left' as default
      const selectedTeam = settings.gameMode === 'multiplayer' ? 'left' : team!;
      onStartGame(selectedTeam, settings);
    } else {
      alert('Please select a team and set your options.');
    }
  };

  return (
    <div className="scene main-menu">
      <h1>{GAME_TITLE}</h1>
      <GameSettings onStart={setSettings} />
      {settings && settings.gameMode === 'singleplayer' && (
        <ChooseTeam onSelectTeam={setTeam} />
      )}
      <button onClick={handlePlay}>Play!</button>
    </div>
  );
};

export default MainMenuScene;