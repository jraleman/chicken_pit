import React, { useEffect, useRef } from 'react';
import './ScrollingText.css';

interface ScrollingTextProps {
  text: string;
  duration: number; // seconds
  onEnd?: () => void;
  onStart?: () => void;
}

const ScrollingText: React.FC<ScrollingTextProps> = ({
  text,
  duration,
  onEnd,
  onStart,
}) => {
  const container = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Call onStart immediately when component mounts
    if (onStart) {
      onStart();
    }

    if (onEnd) {
      const id = setTimeout(onEnd, duration * 1000);
      return () => clearTimeout(id);
    }
  }, [duration, onEnd, onStart]);

  return (
    <div ref={container} className="scrolling-text-container">
      <div
        className="scrolling-text-content"
        style={{ animationDuration: `${duration}s` }}
      >
        {text.split('\n').map((line, i) => (
          <p key={i}>{line}</p>
        ))}
      </div>
    </div>
  );
};

export default ScrollingText;