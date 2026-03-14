import React, { useState, useEffect } from "react";
import DutyPage from "./DutyPage";
import EvidencePage from "./EvidencePage";
import PncPage from "./PncPage";
import BossPage from "./BossPage";
import { Officer, PlayerData } from "./types";

interface LaptopHomeProps {
    onPageChange: (page: string) => void;
    activePage: string;
    activeOfficers: Officer[];
    allOfficers: Officer[];
    playerData: PlayerData | null;
    onDuty: boolean;
    onToggleDuty: () => void;
}

const LaptopHome: React.FC<LaptopHomeProps> = ({ onPageChange, activePage, activeOfficers, allOfficers, playerData, onDuty, onToggleDuty }) => {
    const [time, setTime] = useState(new Date());

    useEffect(() => {
        const interval = setInterval(() => setTime(new Date()), 1000);
        return () => clearInterval(interval);
    }, []);

    const formatted = time.toLocaleString('en-GB', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
    });

    const renderPage = () => {
        switch (activePage) {
            case 'duty-page':     return <DutyPage activeOfficers={activeOfficers} onDuty={onDuty} onToggleDuty={onToggleDuty} onPageChange={onPageChange} />;
            case 'evidence-page': return <EvidencePage onPageChange={onPageChange} />;
            case 'pnc-page':      return <PncPage />;
            case 'boss-page':     return <BossPage onPageChange={onPageChange} allOfficers={allOfficers} playerGrade={playerData?.grade ?? 0} />;
            default: return (
                <>
                    <div className="laptop-app" onClick={() => onPageChange("duty-page")}>
                        <i className="fa-solid fa-user"></i>
                    </div>
                    <div className="laptop-app" onClick={() => onPageChange("evidence-page")}>
                        <i className="fa-solid fa-magnifying-glass"></i>
                    </div>
                    <div className="laptop-app" onClick={() => onPageChange("pnc-page")}>
                        <i className="fa-solid fa-laptop"></i>
                    </div>
                    {(playerData?.grade ?? 0) >= 4 && (
                        <div className="laptop-app" onClick={() => onPageChange("boss-page")}>
                            <i className="fa-sharp fa-solid fa-user-police"></i>
                        </div>
                    )}
                </>
            );
        }
    };

    return (
        <div className="laptop-home">
            <div className="laptop-content">
                {renderPage()}
            </div>
            <div className="laptop-taskbar">
                <button className="taskbar-home-button" onClick={() => onPageChange("home")}>
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="white" width="18" height="18">
                        <path d="M3 12.5V21a1 1 0 0 0 1 1h5v-5h6v5h5a1 1 0 0 0 1-1v-8.5l-8-7.5-10 7.5Z" />
                        <path d="M12 2 1 11h2.5V21H9v-5h6v5h5.5V11H23L12 2Z" />
                    </svg>
                </button>
                <span className="taskbar-clock">{formatted}</span>
            </div>
        </div>
    );
};

export default LaptopHome;