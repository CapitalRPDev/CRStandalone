import React from "react";

interface Option {
    label: string;
    icon: string;
}

interface Interaction3DProps {
    options: Option[];
    selectedIndex: number;
    visible: boolean;
}

const Interaction3D: React.FC<Interaction3DProps> = ({ options, selectedIndex, visible }) => {
    if (!visible) return null;

    return (
        <div className="interaction-wrapper">
            <div className="interaction-selected">
                <div className="interaction-key">E</div>
                <span>{options[selectedIndex - 1]?.label}</span>
            </div>
            <div className="interaction-options">
                {options.map((opt, i) => (
                    <div
                        key={i}
                        className={`interaction-option ${i + 1 === selectedIndex ? "interaction-option--active" : ""}`}
                    >
                        <i className={`fa-solid ${opt.icon}`} />
                        <span>{opt.label}</span>
                    </div>
                ))}
            </div>
        </div>
    );
};

export default Interaction3D;