import React, { useState } from "react";
import IntroScene from "./scenes/IntroScene";
import SlideShowScene from "./scenes/SlideShowScene";
import MainMenuScene from "./scenes/MainMenuScene";
import MainGameScene from "./scenes/MainGameScene";
import { type Team } from "./components/ChooseTeam";
import { type GameSettingsData } from "./components/GameSettings";
import { GAME_INITIAL_SCENE_IDX, LEFT_TEAM_COLOR, RIGHT_TEAM_COLOR, ROPE_COLOR } from "./contants";

const App: React.FC = () => {
  const [step, setStep] = useState(GAME_INITIAL_SCENE_IDX);
  const [team, setTeam] = useState<Team>("left");
  const [settings, setSettings] = useState<GameSettingsData>({
    ropeLength: 4,
    ropeColor: ROPE_COLOR,
    leftTeamColor: LEFT_TEAM_COLOR,
    rightTeamColor: RIGHT_TEAM_COLOR,
    gameMode: 'singleplayer',
  });

  const next = () => setStep((s) => s + 1);
  const startGame = (t: Team, s: GameSettingsData) => {
    setTeam(t);
    setSettings(s);
    setStep(3);
  };
  const restart = () => setStep(2);

  switch (step) {
    case 0:
      return <SlideShowScene onNext={next} />;
    case 1:
      return <IntroScene onNext={next} />;
    case 2:
      return <MainMenuScene onStartGame={startGame} />;
    case 3:
      return (
        <MainGameScene team={team} settings={settings} onRestart={restart} />
      );
    default:
      return <div>Invalid step</div>;
  }
};

export default App;
