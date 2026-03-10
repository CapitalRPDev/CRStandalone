import React from "react";

interface MicrophoneProps {
  isActive: boolean;
  volume: number;
}

const Microphone: React.FC<MicrophoneProps> = ({ isActive, volume }) => {
  const totalBars = 7;
  const filledBars = Math.ceil((volume / 100) * totalBars);

  return (
    <div className="mic-container">
      <div className={`mic-icon ${isActive ? 'active' : ''}`}>
        <i className="fa-solid fa-microphone"></i>
      </div>
      <div className="mic-bars">
        {[...Array(totalBars)].map((_, index) => (
          <div
            key={index}
            className={`mic-bar ${index < filledBars && isActive ? 'filled' : ''}`}
          />
        ))}
      </div>
    </div>
  );
};

export default Microphone;