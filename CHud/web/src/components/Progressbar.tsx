import React, { useEffect, useState } from "react";

interface ProgressbarProps {
  label: string;
  duration: number;
  icon?: string;
  color?: string;
  onComplete?: () => void;
}

const Progressbar: React.FC<ProgressbarProps> = ({ label, duration, icon, color = "#2ecc71", onComplete }) => {
  const [progress, setProgress] = useState(0);
  const totalArrows = 20;
  const filled = Math.round((progress / 100) * totalArrows);

  useEffect(() => {
    const start = Date.now();
    const interval = setInterval(() => {
      const elapsed = Date.now() - start;
      const p = Math.min(100, (elapsed / duration) * 100);
      setProgress(p);
      if (p >= 100) {
        clearInterval(interval);
        onComplete?.();
      }
    }, 50);
    return () => clearInterval(interval);
  }, [duration]);

  return (
    <div className="progressbar-container">
          <span className="corner bottom-left" />
        <span className="corner bottom-right" />
      <div className="progressbar-header">
        <div className="progressbar-label-wrapper">
          {icon && <i className={`fas ${icon}`} style={{ color }} />}
          <span className="progressbar-label">{label}</span>
        </div>
        <span className="progressbar-percent">{Math.round(progress)}%</span>
      </div>
      <div className="progressbar-arrows">
        {Array.from({ length: totalArrows }).map((_, i) => (
          <span key={i} className={`progressbar-arrow ${i < filled ? "filled" : ""}`} style={i < filled ? { color, textShadow: `0 0 6px ${color}80` } : {}}>
            ›
          </span>
        ))}
      </div>
    </div>
  );
};

export default Progressbar;