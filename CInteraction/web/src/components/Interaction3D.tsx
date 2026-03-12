import React from "react";

interface Option {
    label: string;
    sublabel?: string;
    icon: string;
}

interface Interaction3DProps {
    options: Option[];
    selectedIndex: number;
    visible: boolean;
}

const Interaction3D: React.FC<Interaction3DProps> = ({ options, selectedIndex, visible }) => {
    if (!visible || options.length === 0) return null;

    const selected = options[selectedIndex - 1];

    return (
        <div className="interaction-wrapper">
            <div className="interaction-selected">
                <div className="interaction-key">E</div>
                <div className="interaction-selected-text">
                    <span className="interaction-selected-label">{selected?.label}</span>
                </div>
            </div>

            <div className="interaction-options">
                {options.map((opt, i) => (
                    <div
                        key={i}
                        className={`interaction-option ${i + 1 === selectedIndex ? "interaction-option--active" : ""}`}
                    >
                        <i className={opt.icon} />
                        <div className="interaction-option-text">
                            <span className="interaction-option-sublabel">{opt.sublabel || ""}</span>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
};

export default Interaction3D;