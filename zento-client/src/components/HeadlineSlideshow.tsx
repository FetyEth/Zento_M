import React, { useState, useEffect, useRef } from 'react';
import { Bell, Plus } from 'lucide-react';
import { useRouter } from 'next/navigation';

interface NewsItem {
  summary: string;
  timestamp: string;
  title: string;
  category: string;
  score: number;
  upvote_ratio: number;
  num_comments: number;
}

interface HeadlineSlideshowProps {
  headlines: NewsItem[];
  isLoading?: boolean;
}

const HeadlineSlideshow: React.FC<HeadlineSlideshowProps> = ({ headlines, isLoading = false }) => {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isAnimating, setIsAnimating] = useState(false);
  const [isHovering, setIsHovering] = useState(false);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);
  const router = useRouter();

  useEffect(() => {
    if (headlines.length === 0 || isLoading || isHovering) return;

    intervalRef.current = setInterval(() => {
      setIsAnimating(true);
      
      setTimeout(() => {
        setCurrentIndex((prevIndex) => (prevIndex + 1) % headlines.length);
        setIsAnimating(false);
      }, 500);
    }, 4000);

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [headlines.length, isLoading, isHovering]);

  const handleMouseEnter = () => {
    setIsHovering(true);
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
    }
  };

  const handleMouseLeave = () => {
    setIsHovering(false);
  };

  const handleCreateClick = () => {
    const currentHeadline = headlines[currentIndex];
    const headline = currentHeadline.title || currentHeadline.summary;
    
    // Encode the headline for URL
    const encodedHeadline = encodeURIComponent(headline);
    
    router.push(`/create?headline=${encodedHeadline}`);
  };

  if (isLoading) {
    return (
      <div className="w-full bg-[#27272b]/30 border-y border-[#d5a514]/10 py-3 animate-pulse">
        <div className="max-w-7xl mx-auto px-4 flex items-center gap-3">
          <div className="w-4 h-4 bg-gray-700/50 rounded flex-shrink-0"></div>
          <div className="h-4 bg-gray-700/50 rounded flex-1 max-w-md"></div>
          <div className="w-20 h-8 bg-gray-700/50 rounded"></div>
        </div>
      </div>
    );
  }

  if (headlines.length === 0) return null;

  const currentHeadline = headlines[currentIndex];

  return (
    <div className="w-full bg-[#27272b]/30 border-y border-[#d5a514]/10 py-3 overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 flex items-center gap-3">
        {/* Fixed Bell Icon */}
        <Bell className="w-4 h-4 text-[#d5a514] flex-shrink-0" />
        
        {/* Sliding Headline with Hover Controls */}
        <div 
          className="relative h-6 overflow-hidden flex-1"
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
        >
          <div
            className={`transition-all duration-500 ${
              isAnimating ? '-translate-y-full opacity-0' : 'translate-y-0 opacity-100'
            }`}
          >
            <p className="text-gray-300 text-sm truncate cursor-default">
              {currentHeadline.title || currentHeadline.summary}
            </p>
          </div>
        </div>

        {/* Create Button */}
        <button
          onClick={handleCreateClick}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-[#d5a514] hover:bg-[#b68f10] text-white text-sm font-medium rounded-lg transition-colors flex-shrink-0"
        >
          <Plus className="w-4 h-4" />
          <span className="hidden sm:inline">Create</span>
        </button>
      </div>
    </div>
  );
};

export default HeadlineSlideshow;