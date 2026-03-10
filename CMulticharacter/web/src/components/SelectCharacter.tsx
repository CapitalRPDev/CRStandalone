import React from "react";
import { CharacterData } from "./types";
import { fetchNui } from "../utils/fetchNui";

interface SelectCharacterProps {
  onPageChange: (page: string, data?: CharacterData) => void;
  character: CharacterData | null;
}

const SelectCharacter: React.FC<SelectCharacterProps> = ({ onPageChange, character }) => {
  if (!character) return null;

  const handlePlay = () => {
    fetchNui("selectCharacter", { cData: { citizenid: character.citizenid } });
  };

  const handleDelete = () => {
    fetchNui("removeCharacter", { citizenid: character.citizenid });
    onPageChange("home");
  };

  return (
    <div className="selected-character-container">
      <div className="selected-character-info">
        <h2>{character.charinfo.firstname} {character.charinfo.lastname}</h2>
        <p><span>DOB</span>{character.charinfo.birthdate}</p>
        <p><span>CSN</span>{character.citizenid}</p>
        <p><span>JOB</span>{character.job?.label ?? "Unemployed"}</p>
        <p><span>BANK</span>£{character.money?.bank?.toLocaleString() ?? 0}</p>
      </div>
      <div className="selected-character-actions">
        <button onClick={() => onPageChange("home")}>Back</button>
        <button onClick={handleDelete}>Delete</button>
        <button onClick={handlePlay}>Play</button>
      </div>
    </div>
  );
};

export default SelectCharacter;