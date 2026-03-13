import React, { useState } from "react";
import "./App.css";
import { fetchNui } from "../utils/fetchNui";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { debugData } from "../utils/debugData";
import PlayerStats from "./PlayerStats";
import PlayerData from "./types";
import Microphone from "./Microphone";
import StreetNames from "./StreetNames";
import { HudComponent, Notification, ProgressbarData } from "./types";
import Minimap from "./Minimap";
import Speedometer from "./Speedometer";
import Notify from "./Notify";
import Progressbar from "./Progressbar";
import SliderMinigame from "./SliderMinigame";

debugData([
  {
    action: "setVisible",
    data: true,
  },
]);

const App: React.FC = () => {
  const [playerData, setPlayerData] = useState<PlayerData>({
    health: 80,
    hunger: 55,
    thirst: 75,
    stamina: 90,
    armor: 50,
    oxygen: 100,
    speed: 0,
    rpm: 0,
    gear: 0,
    fuel: 100,
    isInVehicle: false,
  });
  const [hudComponents, setHudComponents] = useState<HudComponent[]>([]);
  const [micData, setMicData] = useState({ isActive: true, volume: 75 });
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [progressbar, setProgressbar] = useState<ProgressbarData | null>(null);
  const [seatbelt, setSeatbelt] = useState<boolean>(false);
  const [streetData, setStreetData] = useState({
    direction: "NW",
    locationName: "Los Santos",
    streetName: "Grove Street",
  });

  useNuiEvent<boolean>("setSeatbelt", (value) => {
    setSeatbelt(value);
  });

  useNuiEvent<ProgressbarData>("startProgressbar", (data) => {
    setProgressbar(data);
  });

  useNuiEvent("stopProgressbar", () => {
    setProgressbar(null);
  });

  const playSound = (src: string, volume: number = 1.0) => {
    const audio = new Audio(src);
    audio.volume = volume;
    audio.play();
  };

  useNuiEvent<Notification>("notify", (data) => {
    playSound("notification.ogg", 0.05);
    const id = String(Date.now());
    const notification = { ...data, id };
    setNotifications((prev) => [...prev, notification]);

    setTimeout(() => {
      setNotifications((prev) => prev.filter((n) => n.id !== notification.id));
    }, data.duration);
  });

  useNuiEvent<Partial<PlayerData>>("setPlayerData", (data) => {
    setPlayerData((prev) => ({ ...prev, ...data }));
  });

  useNuiEvent<HudComponent[]>("setHudComponents", (data) => {
    console.log("HUD Components received:", data);
    setHudComponents(data);
  });

  useNuiEvent<{ isActive: boolean; volume: number }>("setMicrophone", (data) => setMicData(data));
  useNuiEvent<{ direction: string; locationName: string; streetName: string }>("setStreetNames", (data) => setStreetData(data));

  return (
    <div className="nui-wrapper">
      <div className="hud-container">
        <Notify notifications={notifications} />
        {progressbar && (
          <Progressbar
            label={progressbar.label}
            duration={progressbar.duration}
            icon={progressbar.icon}
            color={progressbar.color}
            onComplete={() => setProgressbar(null)}
          />
        )}
        <Minimap />
        {playerData.isInVehicle && (
          <Speedometer speed={playerData.speed ?? 0} rpm={playerData.rpm ?? 0} gear={playerData.gear ?? 0} />
        )}
        <Microphone isActive={micData.isActive} volume={micData.volume} />
        <PlayerStats playerData={playerData} hudComponents={hudComponents} seatbelt={seatbelt} />
        <StreetNames
          direction={streetData.direction}
          locationName={streetData.locationName}
          streetName={streetData.streetName}
        />
        <SliderMinigame />
      </div>
    </div>
  );
};

export default App;