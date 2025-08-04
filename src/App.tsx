import React, { useState, useEffect, useRef } from "react";
import IntroScene from "./scenes/IntroScene";
import SlideShowScene from "./scenes/SlideShowScene";
import MainMenuScene from "./scenes/MainMenuScene";
import MainGameScene from "./scenes/MainGameScene";
import AudioControls from "./components/AudioControls";
import { type Team } from "./components/ChooseTeam";
import { type GameSettingsData } from "./components/GameSettings";
import {
  GAME_CREDITS_IDX,
  GAME_INTRO_IDX,
  GAME_MENU_IDX,
  GAME_SCENE_IDX,
  LEFT_TEAM_COLOR,
  RIGHT_TEAM_COLOR,
  ROPE_COLOR,
  ROPE_LENGTH,
} from "./contants";
import musicFile from "./assets/audio/music.mp3";
import "./components/AudioControls.css";

const App: React.FC = () => {
  const [step, setStep] = useState(GAME_CREDITS_IDX);
  const [team, setTeam] = useState<Team>("left");
  const [settings, setSettings] = useState<GameSettingsData>({
    ropeLength: ROPE_LENGTH,
    ropeColor: ROPE_COLOR,
    leftTeamColor: LEFT_TEAM_COLOR,
    rightTeamColor: RIGHT_TEAM_COLOR,
    gameMode: "singleplayer",
  });

  // Audio control state
  const [volume, setVolume] = useState(0.5);
  const [isMuted, setIsMuted] = useState(false);

  const audioRef = useRef<HTMLAudioElement | null>(null);

  // Load and play music when step is above 2
  useEffect(() => {
    if (step > GAME_INTRO_IDX) {
      if (!audioRef.current) {
        audioRef.current = new Audio(musicFile);
        audioRef.current.loop = true;
      }

      // Set volume based on state
      audioRef.current.volume = isMuted ? 0 : volume;

      audioRef.current.play().catch((error) => {
        console.log("Audio play failed:", error);
      });
    } else {
      // Stop music when step is 2 or below
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current.currentTime = 0;
      }
    }
  }, [step, volume, isMuted]);

  // Update audio volume when volume or mute state changes
  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.volume = isMuted ? 0 : volume;
    }
  }, [volume, isMuted]);

  // Cleanup audio on component unmount
  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current = null;
      }
    };
  }, []);

  const next = () => setStep((s) => s + 1);
  const startGame = (t: Team, s: GameSettingsData) => {
    setTeam(t);
    setSettings(s);
    setStep(3);
  };
  const restart = () => setStep(2);

  // Audio control handlers
  const handleVolumeChange = (newVolume: number) => {
    setVolume(newVolume);
    if (newVolume > 0 && isMuted) {
      setIsMuted(false);
    }
  };

  const handleToggleMute = () => {
    setIsMuted(prev => !prev);
  };

  // Show audio controls only when music should be playing
  const showAudioControls = step > GAME_INTRO_IDX;

  switch (step) {
    case GAME_CREDITS_IDX:
      return <SlideShowScene onNext={next} />;
    case GAME_INTRO_IDX:
      return <IntroScene onNext={next} />;
    case GAME_MENU_IDX:
      return (
        <>
          <MainMenuScene onStartGame={startGame} />
          {showAudioControls && (
            <AudioControls
              volume={volume}
              isMuted={isMuted}
              onVolumeChange={handleVolumeChange}
              onToggleMute={handleToggleMute}
            />
          )}
        </>
      );
    case GAME_SCENE_IDX:
      return (
        <>
          <MainGameScene team={team} settings={settings} onRestart={restart} />
          {showAudioControls && (
            <AudioControls
              volume={volume}
              isMuted={isMuted}
              onVolumeChange={handleVolumeChange}
              onToggleMute={handleToggleMute}
            />
          )}
        </>
      );
    default:
      return <div>Invalid step</div>;
  }
};

export default App;
