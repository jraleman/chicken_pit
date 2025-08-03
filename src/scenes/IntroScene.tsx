import React, { useEffect, useRef, useState } from 'react';
import ScrollingText from '../components/ScrollingText';
import { GAME_AUDIO_VOLUME, GAME_INTRO_DURATION, GAME_INTRO_TEXT } from '../contants';
import introAudio from '../assets/audio/intro.mp3';

interface IntroSceneProps {
  onNext: () => void;
}

const IntroScene: React.FC<IntroSceneProps> = ({ onNext }) => {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [isMuted, setIsMuted] = useState(false);
  const [audioStarted, setAudioStarted] = useState(false);
  const [userInteracted, setUserInteracted] = useState(false);

  useEffect(() => {
    const audio = audioRef.current;
    if (audio) {
      audio.volume = GAME_AUDIO_VOLUME;
    }

    // Cleanup function to pause audio when component unmounts
    return () => {
      if (audio) {
        audio.pause();
      }
    };
  }, []);

  const startAudio = () => {
    if (audioRef.current && !audioStarted) {
      audioRef.current.play().catch((error) => {
        console.log('Audio play failed:', error);
      });
      setAudioStarted(true);
    }
  };

  const handleUserInteraction = () => {
    setUserInteracted(true);
    startAudio();
  };

  const toggleMute = () => {
    if (!userInteracted) {
      handleUserInteraction();
    }
    if (audioRef.current) {
      audioRef.current.muted = !isMuted;
      setIsMuted(!isMuted);
    }
  };

  const handleNext = () => {
    if (!userInteracted) {
      handleUserInteraction();
    }
    onNext();
  };

  const handleStart = () => {
    setUserInteracted(true);
    if (audioRef.current && !audioStarted) {
      audioRef.current.play().catch((error) => {
        console.log('Audio play failed:', error);
      });
      setAudioStarted(true);
    }
  };

  return (
    <>
      <audio ref={audioRef} src={introAudio} loop />
      {!userInteracted ? (
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          textAlign: 'center',
          color: 'white',
          zIndex: 1001
        }}>
          <h2 style={{ marginBottom: '20px' }}>Click to start the intro</h2>
          <button 
            onClick={handleStart}
            style={{
              padding: '15px 30px',
              backgroundColor: '#333',
              color: 'white',
              border: 'none',
              borderRadius: '5px',
              cursor: 'pointer',
              fontSize: '16px'
            }}
          >
            Start Intro
          </button>
        </div>
      ) : (
        <ScrollingText 
          text={GAME_INTRO_TEXT} 
          duration={GAME_INTRO_DURATION} 
          onEnd={handleNext}
        />
      )}
      {userInteracted && (
        <button 
          onClick={toggleMute}
          style={{
            position: 'absolute',
            top: '20px',
            right: '20px',
            padding: '10px 15px',
            backgroundColor: isMuted ? '#666' : '#333',
            color: 'white',
            border: 'none',
            borderRadius: '5px',
            cursor: 'pointer',
            fontSize: '14px',
            zIndex: 1000
          }}
        >
          {isMuted ? '🔇' : '🔊'}
        </button>
      )}
      {userInteracted && (
        <button 
          onClick={handleNext}
          style={{
            position: 'absolute',
            bottom: '20px',
            right: '20px',
            padding: '10px 20px',
            backgroundColor: '#333',
            color: 'white',
            border: 'none',
            borderRadius: '5px',
            cursor: 'pointer',
            fontSize: '14px',
            zIndex: 1000
          }}
        >
          Skip Intro
        </button>
      )}
    </>
  );
};

export default IntroScene;