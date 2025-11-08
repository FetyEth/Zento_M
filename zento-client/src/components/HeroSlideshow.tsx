import React, { useState, useEffect } from "react";
import { ChevronLeft, ChevronRight, CandlestickChart, Users, Clock } from "lucide-react";

// Sample high-volume markets data
const highVolumeMarkets = [
  {
    id: 1,
    title: "Will Xi Jinping be out by end of 2025?",
    description:
      "Trade on the potential leadership change in China amid global tensions. High liquidity market with real-time geopolitical insights.",
    yesPrice: 0.02,
    noPrice: 0.98,
    totalVolume: 35800000,
    participants: 700,
    timeLeft: "54d left",
    heroImage: "/zento-h.png",
  },
  {
    id: 2,
    title: "Will José Antonio Kast win the Chile Presidential Election?",
    description:
      "Bet on the outcome of Chile's upcoming election as political shifts unfold. Join global traders in this surging volume market.",
    yesPrice: 0.67,
    noPrice: 0.33,
    totalVolume: 28100000,
    participants: 1200,
    timeLeft: "9d left",
    heroImage: "/hero-slide2.png",
  },
  {
    id: 3,
    title: "Will Wicked: For Good be the highest grossing movie of 2025?",
    description:
      "Participate in the box office battle prediction. Trade on Hollywood's biggest releases and audience trends in this explosive market.",
    yesPrice: 0.48,
    noPrice: 0.52,
    totalVolume: 27000000,
    participants: 1500,
    timeLeft: "54d left",
    heroImage: "/zento-h.png",
  },
  {
    id: 4,
    title: "Will Oklahoma City Thunder win the 2026 NBA Championship?",
    description:
      "Trade NBA futures as teams gear up for the playoffs. Real-time odds with transparent settlements in this high-stakes sports market.",
    yesPrice: 0.31,
    noPrice: 0.69,
    totalVolume: 22600000,
    participants: 987,
    timeLeft: "235d left",
    heroImage: "/hero-slide2.png",
  },
];

const HeroSlideshow = () => {
  const [currentSlide, setCurrentSlide] = useState(0);
  const [isAutoPlaying, setIsAutoPlaying] = useState(true);

  useEffect(() => {
    if (!isAutoPlaying) return;

    const interval = setInterval(() => {
      setCurrentSlide((prev) => (prev + 1) % highVolumeMarkets.length);
    }, 5000);

    return () => clearInterval(interval);
  }, [isAutoPlaying]);

  const nextSlide = () => {
    setCurrentSlide((prev) => (prev + 1) % highVolumeMarkets.length);
    setIsAutoPlaying(false);
  };

  const prevSlide = () => {
    setCurrentSlide((prev) => (prev - 1 + highVolumeMarkets.length) % highVolumeMarkets.length);
    setIsAutoPlaying(false);
  };

  const goToSlide = (index: number) => {
    setCurrentSlide(index);
    setIsAutoPlaying(false);
  };

  const currentMarket = highVolumeMarkets[currentSlide];

  return (
    <div className="bg-[#1a1a1d]">
      {/* Hero Slideshow */}
      <div className="w-full bg-[#2a2a2d] overflow-hidden">
        <div className="max-w-7xl mx-auto px-4 mb-4 pt-8 pb-2 md:pt-8 md:pb-2 lg:py-20">
          <div className="flex flex-col md:flex-row items-start justify-between gap-8 relative">
            {/* Left Content */}
            <div className="flex-1 z-10">
              {/* Market Title */}
              <h1 className="text-3xl md:text-xl lg:text-3xl font-bold text-white mb-4 leading-tight">
                {currentMarket.title}
              </h1>

              {/* Market Description */}
              <p className="text-[#c6c6c7] text-sm md:text-lg max-w-2xl mb-6">{currentMarket.description}</p>

              {/* Volume Badge */}
              <div className="inline-flex items-center gap-2 px-4 py-2 bg-[#d5a514]/10 border border-[#d5a514]/30 rounded-lg mb-4">
                <CandlestickChart className="w-4 h-4 text-[#d5a514]" />
                <span className="text-[#d5a514] text-sm font-semibold">
                  {(Number(currentMarket.totalVolume) / 1e6).toFixed(1)}K USDT
                </span>
              </div>

              <div className="flex items-center gap-6 mt-2 mb-5 text-sm text-gray-400">
                <span className="flex items-center gap-2">
                  <Users className="w-4 h-4" />
                  {currentMarket.participants?.toLocaleString()} traders
                </span>
                <span className="flex items-center gap-2">
                  <Clock className="w-4 h-4" />
                  {currentMarket.timeLeft}
                </span>
              </div>

              <div className="flex flex-col sm:flex-row gap-4 items-start">
                {/* <button className="w-40 sm:w-auto px-6 py-2.5 bg-[#d5a514] hover:bg-[#b8952e] text-white rounded-xl font-semibold text-lg transition-all duration-200">
                  Predict
                </button> */}
              </div>

              {/* Market Stats */}
            </div>

            {/* Hero Image - positioned at bottom right */}
            <div
              key={currentSlide}
              className="absolute lg:-bottom-[330px] -bottom-[149px] md:-bottom-[330px] -right-[130px] lg:-right-[280px] w-full md:w-auto md:max-w-md lg:max-w-[49.5rem] transition-opacity duration-500"
              style={{
                animation: "fadeIn 0.5s ease-in-out",
              }}
            >
              <img src={currentMarket.heroImage} alt={currentMarket.title} className="w-full h-auto rounded-lg" />
            </div>
          </div>

          {/* Navigation Controls */}
          <div className="flex items-center justify-between mt-4 relative z-10">
            <div className="flex gap-2">
              {highVolumeMarkets.map((_, index) => (
                <button
                  key={index}
                  onClick={() => goToSlide(index)}
                  className={`h-2 rounded-full transition-all duration-300 ${
                    index === currentSlide ? "w-8 bg-[#d5a514]" : "w-2 bg-gray-600 hover:bg-gray-500"
                  }`}
                  aria-label={`Go to slide ${index + 1}`}
                />
              ))}
            </div>
            <div className="flex gap-2">
              <button
                onClick={prevSlide}
                className="p-2 bg-white/5 hover:bg-white/10 rounded-lg backdrop-blur-sm transition-colors border border-gray-700"
                aria-label="Previous slide"
              >
                <ChevronLeft className="w-5 h-5 text-white" />
              </button>
              <button
                onClick={nextSlide}
                className="p-2 bg-white/5 hover:bg-white/10 rounded-lg backdrop-blur-sm transition-colors border border-gray-700"
                aria-label="Next slide"
              >
                <ChevronRight className="w-5 h-5 text-white" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <style>{`
        @keyframes fadeIn {
          from {
            opacity: 0;
            transform: translateY(10px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      `}</style>
    </div>
  );
};

export default HeroSlideshow;
