import React from "react";
import { CharacterData } from "./types";

interface CharacterListProps {
    onPageChange: (page: string, data?: CharacterData) => void;
    characters: CharacterData[];
    maxCharacters: number;
}

const CharacterList: React.FC<CharacterListProps> = ({ onPageChange, characters = [], maxCharacters }) => {
    const emptySlots = maxCharacters - (characters?.length ?? 0);

    return (
        <div className="characters-container">
            {characters.map((character) => (
                <div className="character-box" key={character.citizenid} onClick={() => onPageChange("select-character", character)}>
                    <div className="character-box-header">
                        <div className="character-avatar">
                            {character.charinfo.firstname.charAt(0)}{character.charinfo.lastname.charAt(0)}
                        </div>
                        <div className="character-name-block">
                            <h3>{character.charinfo.firstname} {character.charinfo.lastname}</h3>
                            <span className="character-job">{character.job?.label ?? "Unemployed"}</span>
                        </div>
                    </div>
                    <div className="character-box-divider" />
                    <div className="character-box-details">
                        <div className="character-detail">
                            <span className="detail-label">DOB</span>
                            <span className="detail-value">{character.charinfo.birthdate}</span>
                        </div>
                        <div className="character-box-divider" />
                        <div className="character-detail">
                            <span className="detail-label">BANK</span>
                            <span className="detail-value">£{character.money?.bank?.toLocaleString() ?? 0}</span>
                        </div>
                        <div className="character-box-divider" />
                        <div className="character-detail">
                            <span className="detail-label">NATIONALITY</span>
                            <span className="detail-value">{character.charinfo.nationality}</span>
                        </div>
                    </div>
                </div>
            ))}
            {Array.from({ length: emptySlots }).map((_, i) => (
                <div className="character-box character-box--empty" key={`empty-${i}`} onClick={() => onPageChange("new-character")}>
                    <span className="empty-pluss">+</span>
                    <p>New Character</p>
                </div>
            ))}
        </div>
    );
};

export default CharacterList;