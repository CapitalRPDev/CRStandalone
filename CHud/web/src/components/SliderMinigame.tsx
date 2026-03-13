import React, { useEffect, useRef, useState } from "react";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { fetchNui } from "../utils/fetchNui";

interface SliderConfig {
    speed: number;
    required: number;
    maxFaults: number;
}

interface ZoneConfig {
    center: number;
    width: number;
}

const randomZone = (): ZoneConfig => {
    const width = Math.floor(Math.random() * 16) + 10;
    const half = width / 2;
    const center = Math.floor(Math.random() * (80 - half * 2)) + 10 + half;
    return { center, width };
};

const SliderMinigame: React.FC = () => {
    const [visible, setVisible] = useState(false);
    const [config, setConfig] = useState<SliderConfig>({ speed: 2, required: 3, maxFaults: 2 });
    const [position, setPosition] = useState(0);
    const [completedDisplay, setCompletedDisplay] = useState(0);
    const [faultsDisplay, setFaultsDisplay] = useState(0);
    const [flash, setFlash] = useState<"success" | "fail" | null>(null);
    const [zone, setZone] = useState<ZoneConfig>({ center: 50, width: 24 });

    const animRef = useRef<number>();
    const posRef = useRef(0);
    const dirRef = useRef(1);
    const activeRef = useRef(false);
    const pausedRef = useRef(false);
    const completedRef = useRef(0);
    const faultsRef = useRef(0);
    const configRef = useRef<SliderConfig>({ speed: 2, required: 3, maxFaults: 2 });
    const zoneRef = useRef<ZoneConfig>({ center: 50, width: 24 });

    useNuiEvent<SliderConfig>("showSliderMinigame", (data) => {
        const initialZone = randomZone();
        configRef.current = data;
        zoneRef.current = initialZone;
        setConfig(data);
        setZone(initialZone);
        setVisible(true);
        setCompletedDisplay(0);
        setFaultsDisplay(0);
        setFlash(null);
        posRef.current = 0;
        dirRef.current = 1;
        completedRef.current = 0;
        faultsRef.current = 0;
        activeRef.current = true;
        pausedRef.current = false;
    });

    useEffect(() => {
        if (!visible) return;

        const animate = () => {
            if (!activeRef.current) return;
            if (!pausedRef.current) {
                posRef.current += dirRef.current * (configRef.current.speed * 0.4);
                if (posRef.current >= 100) {
                    posRef.current = 100;
                    dirRef.current = -1;
                } else if (posRef.current <= 0) {
                    posRef.current = 0;
                    dirRef.current = 1;
                }
                setPosition(posRef.current);
            }
            animRef.current = requestAnimationFrame(animate);
        };

        animRef.current = requestAnimationFrame(animate);
        return () => { if (animRef.current) cancelAnimationFrame(animRef.current); };
    }, [visible]);

    useEffect(() => {
        if (!visible) return;

        const handleKey = (e: KeyboardEvent) => {
            if (e.code !== "KeyE" || !activeRef.current || pausedRef.current) return;
            e.preventDefault();
            e.stopPropagation();

            const { center, width } = zoneRef.current;
            const half = width / 2;
            const hit = posRef.current >= center - half && posRef.current <= center + half;

            pausedRef.current = true;

            if (hit) {
                completedRef.current += 1;
                setCompletedDisplay(completedRef.current);
                setFlash("success");

                const isComplete = completedRef.current >= configRef.current.required;

                setTimeout(() => {
                    setFlash(null);
                    if (isComplete) {
                        activeRef.current = false;
                        if (animRef.current) cancelAnimationFrame(animRef.current);
                        setVisible(false);
                        fetchNui("sliderMinigameResult", { success: true });
                    } else {
                        const newZone = randomZone();
                        zoneRef.current = newZone;
                        setZone(newZone);
                        pausedRef.current = false;
                    }
                }, 1000);
            } else {
                faultsRef.current += 1;
                setFaultsDisplay(faultsRef.current);
                setFlash("fail");

                const isFailed = faultsRef.current >= configRef.current.maxFaults;

                setTimeout(() => {
                    setFlash(null);
                    if (isFailed) {
                        activeRef.current = false;
                        if (animRef.current) cancelAnimationFrame(animRef.current);
                        setVisible(false);
                        fetchNui("sliderMinigameResult", { success: false });
                    } else {
                        const newZone = randomZone();
                        zoneRef.current = newZone;
                        setZone(newZone);
                        pausedRef.current = false;
                    }
                }, 1000);
            }
        };

        window.addEventListener("keydown", handleKey, true);
        return () => window.removeEventListener("keydown", handleKey, true);
    }, [visible]);

    if (!visible) return null;

    return (
        <div className="slider-minigame-wrapper">
            <div className="slider-minigame">
                <div className="slider-header">
                    <span className="slider-title">SKILL CHECK</span>
                    <div className="slider-meta">
                        <div className="slider-progress-dots">
                            {Array.from({ length: config.required }).map((_, i) => (
                                <div key={i} className={`slider-dot ${i < completedDisplay ? "slider-dot--filled" : ""}`} />
                            ))}
                        </div>
                        <div className="slider-faults">
                            {Array.from({ length: config.maxFaults + 1 }).map((_, i) => (
                                <div key={i} className={`slider-fault ${i < faultsDisplay ? "slider-fault--filled" : ""}`} />
                            ))}
                        </div>
                    </div>
                </div>

                <div className={`slider-track ${flash === "success" ? "flash-success" : flash === "fail" ? "flash-fail" : ""}`}>
                    <div
                        className="slider-zone"
                        style={{
                            left: `${zone.center - zone.width / 2}%`,
                            width: `${zone.width}%`,
                        }}
                    />
                    <div
                        className="slider-center-line"
                        style={{ left: `${zone.center}%` }}
                    />
                    <div className="slider-indicator" style={{ left: `${position}%` }} />
                </div>

                <div className="slider-hint">
                    <div className="interaction-key" style={{ width: 22, height: 22, fontSize: 11 }}>E</div>
                    <span>Press when in the zone</span>
                </div>
            </div>
        </div>
    );
};

export default SliderMinigame;