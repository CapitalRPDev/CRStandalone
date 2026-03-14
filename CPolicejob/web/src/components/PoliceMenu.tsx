import React, { useState, useEffect } from "react";
import { PlayerData } from "./types";
import { fetchNui } from "../utils/fetchNui";

interface Action {
    label: string;
    sublabel: string;
    icon: string;
    action: string;
}

interface PoliceMenuProps {
    playerData: PlayerData | null;
    onClose: () => void;
    actions?: Action[];
}

const DEFAULT_ACTIONS: Action[] = [
    { label: "Search",        sublabel: "Search a player",   icon: "fa-solid fa-magnifying-glass", action: "search"       },
    { label: "Seize Vehicle", sublabel: "Impound vehicle",   icon: "fa-solid fa-car",              action: "seizeVehicle" },
    { label: "Open MDT",      sublabel: "Access MDT",        icon: "fa-solid fa-laptop",           action: "openMDT"      },
    { label: "Breathalyse",   sublabel: "Test for alcohol",  icon: "fa-solid fa-wind",             action: "breathalyse"  },
    { label: "ANPR",          sublabel: "Scan plate",        icon: "fa-solid fa-camera",           action: "anpr"         },
];

const PoliceMenu: React.FC<PoliceMenuProps> = ({ playerData, onClose, actions = DEFAULT_ACTIONS }) => {
    const [selectedIndex, setSelectedIndex] = useState(0);

    useEffect(() => {
        const wheelHandler = (e: WheelEvent) => {
            e.preventDefault();
            setSelectedIndex(prev => {
                if (e.deltaY > 0) return (prev + 1) % actions.length;
                return (prev - 1 + actions.length) % actions.length;
            });
        };

        const keyHandler = (e: KeyboardEvent) => {
            if (e.key === 'Escape') {
                onClose();
                fetchNui('closePoliceMenu', {}).catch(() => {});
            }
            if (e.key === 'Enter' || e.key === 'e' || e.key === 'E') {
                fetchNui('policeMenuAction', { action: actions[selectedIndex].action }).catch(() => {});
                onClose();
                fetchNui('closePoliceMenu', {}).catch(() => {});
            }
        };

        window.addEventListener('wheel', wheelHandler, { passive: false });
        window.addEventListener('keydown', keyHandler);
        return () => {
            window.removeEventListener('wheel', wheelHandler);
            window.removeEventListener('keydown', keyHandler);
        };
    }, [selectedIndex, actions, onClose]);

    const selected = actions[selectedIndex];

    return (
        <div className="police-menu-wrapper">
            <div className="police-menu-selected">
                <div className="police-menu-key">E</div>
                <span className="police-menu-selected-label">Select Action</span>
            </div>
            <div className="police-menu-container">
                {actions.map((action, i) => (
                    <div
                        key={i}
                        className={`police-menu-action ${i === selectedIndex ? 'active' : ''}`}
                        onClick={() => {
                            setSelectedIndex(i);
                            fetchNui('policeMenuAction', { action: action.action }).catch(() => {});
                        }}
                    >
                        <i className={action.icon}></i>
                        <div className="police-menu-action-text">
                            <span className="police-menu-action-label">{action.label}</span>
                            <span className="police-menu-action-sublabel">{action.sublabel}</span>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
};

export default PoliceMenu;