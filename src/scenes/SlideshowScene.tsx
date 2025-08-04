import { useEffect, useState } from "react";
import { SLIDE_SHOW_DURATION } from "../contants";
import logo from "../assets/images/dcs-games.jpg";

interface SlideShowSceneProps {
  onNext: () => void;
}

export type Slide = {
  id: number;
  title: string;
  subtitle?: string;
  logoUrl?: string;
  backgroundColor: string;
};

const SlideShowScene: React.FC<SlideShowSceneProps> = ({ onNext }) => {
  const [currentSlide, setCurrentSlide] = useState(0);
  const [isVisible, setIsVisible] = useState(true);

  // Slideshow content - can be easily updated with actual team logos
  const slides: Slide[] = [
    {
      id: 1,
      title: "DeskCanSaw",
      subtitle: "Games",
      backgroundColor: "#afddea",
      // logoUrl: "/assets/images/dcs-games.jpg",
      logoUrl: logo,
    },
  ];

  const slideDuration = SLIDE_SHOW_DURATION / slides.length;
  const fadeDuration = 666;

  useEffect(() => {
    const slideInterval = setInterval(() => {
      setIsVisible(false);

      setTimeout(() => {
        setCurrentSlide((prev) => {
          const nextSlide = prev + 1;
          if (nextSlide >= slides.length) {
            onNext();
            return prev;
          }
          return nextSlide;
        });
        setIsVisible(true);
      }, fadeDuration);
    }, slideDuration);

    return () => clearInterval(slideInterval);
  }, [onNext, slides.length, slideDuration, fadeDuration]);

  // Cleanup timeout when component unmounts
  useEffect(() => {
    const totalDuration = setTimeout(onNext, SLIDE_SHOW_DURATION);
    return () => clearTimeout(totalDuration);
  }, [onNext]);

  const currentSlideData = slides[currentSlide];

  return (
    <div
      className="scene slideshow"
      style={{
        transition: `background-color ${fadeDuration}ms ease-in-out`,
        backgroundColor: currentSlideData.backgroundColor,
      }}
    >
      <div
        className="slide-content"
        style={{
          opacity: isVisible ? 1 : 0,
          transition: `opacity ${fadeDuration}ms ease-in-out`,
        }}
      >
        <img
          src={currentSlideData.logoUrl}
          alt={currentSlideData.title}
          className="team-logo"
          style={{
            width: 200,
            height: "auto",
            transition: `opacity ${fadeDuration}ms ease-in-out`,
          }}
        />
      </div>
    </div>
  );
};

export default SlideShowScene;
