import React from "react";
import { HudComponent } from "./types";
import PlayerData from "./types";

interface PlayerStatsProps {
  playerData: PlayerData;
  hudComponents: HudComponent[];
  seatbelt: boolean;
}

const PlayerStats: React.FC<PlayerStatsProps> = ({ playerData, hudComponents, seatbelt }) => {
  const getValue = (name: string): number => {
    const val = playerData[name as keyof PlayerData];
    return typeof val === "number" ? val : 0;
  };

  const sorted = [...hudComponents].sort((a, b) => a.order - b.order);

  const rows = sorted.reduce<Record<number, HudComponent[]>>((acc, comp) => {
    const row = comp.row ?? 1;
    if (!acc[row]) acc[row] = [];
    acc[row].push(comp);
    return acc;
  }, {});

  const rowNumbers = Object.keys(rows).map(Number).sort((a, b) => a - b);

  return (
      <div className="stats-wrapper">
        {rowNumbers.map((rowNum) => (
          <div key={rowNum} className="stats-container">
            {rows[rowNum].map((comp) => {
              const value = getValue(comp.name);
              if (comp.hideWhenZero && value === 0) return null;
              if (comp.showOnlyUnderwater && !playerData.isUnderwater) return null;
              if (comp.showOnlyInCar && !playerData.isInVehicle) return null;

              return (
                <div
                  key={comp.name}
                  className={`stat stat-${comp.name}`}
                  style={{
                    "--color": comp.color,
                    "--progress": value / 100,
                  } as React.CSSProperties}
                >
                  <i className={comp.icon} />
                </div>
              );
            })}
          </div>
        ))}

        {playerData.isInVehicle && (
          <div className={`seatbelt-indicator ${seatbelt ? "seatbelt-on" : "seatbelt-off"}`}>
            <i className="fa-solid fa-vest-patches" />
          </div>
        )}
      </div>
  );
};

export default PlayerStats;