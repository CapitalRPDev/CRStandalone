import React, { useRef, useState, useEffect } from "react";
import { SpawnLocation } from "./types";
import { fetchNui } from "../utils/fetchNui";



interface SpawnsProps {
    spawns: SpawnLocation[];
    playerJob: string;
    onSpawn: (spawn: SpawnLocation) => void;
    onLastLocation: () => void;
}

const Spawns: React.FC<SpawnsProps> = ({ spawns, playerJob, onSpawn, onLastLocation }) => {
  const available = spawns.filter(
    (s) => s.jobLock === false || s.jobLock === playerJob
  );

  

  const [selected, setSelected] = useState<SpawnLocation | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const isDragging = useRef(false);
  const startX = useRef(0);
  const scrollLeft = useRef(0);
  const dragMoved = useRef(false);

  useEffect(() => {
      setSelected(null);
  }, []);

  const onMouseDown = (e: React.MouseEvent) => {
    isDragging.current = true;
    dragMoved.current = false;
    startX.current = e.pageX - (scrollRef.current?.offsetLeft ?? 0);
    scrollLeft.current = scrollRef.current?.scrollLeft ?? 0;
  };

  const onMouseMove = (e: React.MouseEvent) => {
    if (!isDragging.current || !scrollRef.current) return;
    const x = e.pageX - scrollRef.current.offsetLeft;
    const walk = x - startX.current;
    if (Math.abs(walk) > 5) dragMoved.current = true;
    scrollRef.current.scrollLeft = scrollLeft.current - walk;
  };

  const onMouseUp = () => {
    isDragging.current = false;
  };

const handleClick = (spawn: SpawnLocation) => {
    if (dragMoved.current) return;
    setSelected(spawn);
    fetchNui('moveCamera', { 
        locationKey: spawn.index,
        coords: spawn.coords 
    });
};
  return (
      <>
          {selected && (
              <div className="spawn-confirm">
                  <div className="spawn-confirm-location">
                      <span className="spawn-confirm-label">SELECTED LOCATION</span>
                      <span className="spawn-confirm-name">{selected.label}</span>
                  </div>
                  <button className="spawn-confirm-btn" onClick={() => onSpawn(selected)}>
                      <span className="spawn-confirm-btn-icon">▶</span>
                      Spawn
                  </button>
              </div>
          )}

          <div className="spawn-lastlocation">
              <button className="spawn-lastlocation-btn" onClick={() => onLastLocation()}>
                  <span className="spawn-confirm-btn-icon">◀</span>
                  Last Location
              </button>
          </div>

          <div
              className="spawns-scroll-wrapper"
              ref={scrollRef}
              onMouseDown={onMouseDown}
              onMouseMove={onMouseMove}
              onMouseUp={onMouseUp}
              onMouseLeave={onMouseUp}
          >
              <div className="spawns-container">
                  {available.map((spawn) => (
                      <div
                          className={`spawn-box ${selected?.index === spawn.index ? "spawn-box--selected" : ""}`}
                          key={spawn.index}
                          onClick={() => handleClick(spawn)}
                      >
                          <div className="spawn-box-header">
                              <div className="spawn-avatar">{spawn.label.charAt(0)}</div>
                              <div className="spawn-name-block">
                                  <h3>{spawn.label}</h3>
                                  {spawn.jobLock && (
                                      <span className="spawn-job-tag">{spawn.jobLock}</span>
                                  )}
                              </div>
                          </div>
                          <div className="spawn-box-divider" />
                          <div className="character-box-details">
                              <div className="character-detail">
                                  <span className="detail-label">LOCATION</span>
                                  <span className="detail-value">{spawn.label}</span>
                              </div>
                              <div className="character-detail">
                                  <span className="detail-label">ACCESS</span>
                                  <span className="detail-value">{spawn.jobLock ? spawn.jobLock.toUpperCase() : "Public"}</span>
                              </div>
                          </div>
                      </div>
                  ))}
              </div>
          </div>
      </>
  );
};

export default Spawns;