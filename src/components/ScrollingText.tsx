import React, { useEffect, useRef } from 'react';
import './ScrollingText.css';

interface ScrollingTextProps {
  text: string;
  duration?: number; // seconds
  onEnd?: () => void;
}

/**
 * Full-screen vertically scrolling text (like a movie crawl).
 */
const ScrollingText: React.FC<ScrollingTextProps> = ({
  text,
  duration = 8,
  onEnd,
}) => {
  const container = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (onEnd) {
      const id = setTimeout(onEnd, duration * 1000);
      return () => clearTimeout(id);
    }
  }, [duration, onEnd]);

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