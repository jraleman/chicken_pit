import React, { useState } from 'react';
import SlideshowScene from './scenes/SlideshowScene';
import IntroScene      from './scenes/IntroScene';
import MainMenuScene  from './scenes/MainMenuScene';
import MainGameScene  from './scenes/MainGameScene';
import { type Team }       from './components/ChooseTeam';
import { type GameSettingsData } from './components/GameSettings';

const App: React.FC = () => {
  const [step, setStep] = useState(0);
  const [team, setTeam] = useState<Team>('left');
  const [settings, setSettings] = useState<GameSettingsData>({
    ropeLength: 4,
    ropeColor: '#8b4513',
  });

  const next = () => setStep(s => s + 1);
  const startGame = (t: Team, s: GameSettingsData) => {
    setTeam(t);
    setSettings(s);
    setStep(3);
  };
  const restart = () => setStep(2);

  switch (step) {
    case 0:
      return <SlideshowScene onNext={next} />;
    case 1:
      return <IntroScene onNext={next} />;
    case 2:
      return <MainMenuScene onStartGame={startGame} />;
    case 3:
      return (
        <MainGameScene
          team={team}
          settings={settings}
          onRestart={restart}
        />
      );
    default:
      return <div>Invalid step</div>;
  }
};

export default App;
