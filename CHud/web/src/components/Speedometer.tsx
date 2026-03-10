import React from "react";

interface SpeedometerProps {
  speed: number;
  rpm?: number;
  gear?: number;
}

const Speedometer: React.FC<SpeedometerProps> = ({ speed, rpm = 0, gear }) => {
  const totalBars = 30;
  const filledBars = Math.round((Math.min(rpm, 100) / 100) * totalBars);
  const redlineStart = Math.floor(totalBars * 0.75);

  return (
    <div className="speedometer-container">
      <div className="speedometer-top">
        <span className="speedometer-speed">{speed}</span>
        <span className="speedometer-unit">MPH</span>
      </div>
      <div className="speedometer-bars">
        {Array.from({ length: totalBars }).map((_, i) => (
          <div
            key={i}
            className={`speedometer-bar ${
              i < filledBars
                ? i >= redlineStart
                  ? "filled redline"
                  : "filled"
                : ""
            }`}
          />
        ))}
      </div>
    </div>
  );
};

export default Speedometer;