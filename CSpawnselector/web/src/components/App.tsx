import React, { useState } from "react";
import "./App.css";
import { fetchNui } from "../utils/fetchNui";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { debugData } from "../utils/debugData";
import Spawns from "./Spawns";
import { SpawnLocation } from "./types";

debugData<any>([
  {
    action: "setupSpawns",
    data: {
      spawns: [
        { label: "Legion Square", index: 1, jobLock: false },
        { label: "Bexley Hospital", index: 2, jobLock: false },
        { label: "Police Station", index: 3, jobLock: "police" },
        { label: "British Estate", index: 4, jobLock: false },
        { label: "Paleto Hospital", index: 5, jobLock: false },
        { label: "Buckingham Palace", index: 6, jobLock: false },
        { label: "Eclipse Towers", index: 7, jobLock: false },
        { label: "Job Centre", index: 8, jobLock: false },
        { label: "Mining", index: 9, jobLock: false },
        { label: "Casino", index: 10, jobLock: false },
        { label: "Air Force Base", index: 11, jobLock: false },
      ],
      playerJob: "police"
    }
  },
  {
    action: "ui",
    data: { toggle: true }
  }
]);

const App: React.FC = () => {
  const [visible, setVisible] = useState(true);
  const [spawns, setSpawns] = useState<SpawnLocation[]>([]);
  const [playerJob, setPlayerJob] = useState<string>("");

  useNuiEvent<any>("setupSpawns", (data) => {
      setSpawns(data.spawns ?? []);
      setPlayerJob(data.playerJob ?? "");
      setVisible(true);
  });
  useNuiEvent<any>("ui", (data) => {
      if (data.toggle === false) {
          setVisible(false);
      }
  });

  const handleLastLocation = () => {
      fetchNui("lastLocation", {});
  };

  const handleSpawn = (spawn: SpawnLocation) => {
      fetchNui("selectSpawn", { index: spawn.index });
  };
  if (!visible) return null;

return (
  <div className="nui-wrapper">
    <div className="spawnselector-container">

    <div className="spawnselector-header">
      <img src="./logo.png" alt="logo" className="spawnselector-logo" />
      <span className="spawnselector-title">Spawn Selector</span>
    </div>

      <Spawns spawns={spawns} playerJob={playerJob} onSpawn={handleSpawn} onLastLocation={handleLastLocation} />


    </div>
  </div>
);
};

export default App;