import React, { useState } from "react";
import { fetchNui } from "../utils/fetchNui";

interface NewCharacterProps {
    onPageChange: (page: string) => void;
}

const nationalities = [
    "British", "American", "Norwegian", "German", "French",
    "Italian", "Spanish", "Polish", "Russian", "Australian"
];

const NewCharacter: React.FC<NewCharacterProps> = ({ onPageChange }) => {
    const [firstname, setFirstname] = useState("");
    const [lastname, setLastname] = useState("");
    const [dob, setDob] = useState("");
    const [height, setHeight] = useState(170);
    const [nationality, setNationality] = useState("British");
    const [gender, setGender] = useState<string>("Male");

const handleCreate = () => {
    fetchNui("createNewCharacter", {
        firstname: firstname,
        lastname: lastname,
        birthdate: dob,
        height: height,
        nationality: nationality,
        gender: gender,
    });
};

    return (
        <div className="new-character-container">
            <div className="new-character-info">
                <h2>Create Character</h2>

                <div className="new-character-field">
                    <span>FIRST NAME</span>
                    <input
                        type="text"
                        placeholder="John"
                        value={firstname}
                        onChange={(e) => setFirstname(e.target.value)}
                    />
                </div>

                <div className="new-character-field">
                    <span>LAST NAME</span>
                    <input
                        type="text"
                        placeholder="Doe"
                        value={lastname}
                        onChange={(e) => setLastname(e.target.value)}
                    />
                </div>

                <div className="new-character-field">
                    <span>DATE OF BIRTH</span>
                    <input
                        type="date"
                        value={dob}
                        onChange={(e) => setDob(e.target.value)}
                    />
                </div>

                <div className="new-character-field">
                    <span>GENDER</span>
                    <select value={gender} onChange={(e) => setGender(e.target.value)}>
                        <option value="Male">Male</option>
                        <option value="Female">Female</option>
                    </select>
                </div>

                <div className="new-character-field">
                    <span>HEIGHT — {height}cm</span>
                    <input
                        type="range"
                        min={150}
                        max={210}
                        value={height}
                        onChange={(e) => setHeight(Number(e.target.value))}
                    />
                    <div className="new-character-range-labels">
                        <p>150cm</p>
                        <p>210cm</p>
                    </div>
                </div>

                <div className="new-character-field">
                    <span>NATIONALITY</span>
                    <select value={nationality} onChange={(e) => setNationality(e.target.value)}>
                        {nationalities.map((n) => (
                            <option key={n} value={n}>{n}</option>
                        ))}
                    </select>
                </div>
            </div>

            <div className="selected-character-actions">
                <button onClick={() => onPageChange("home")}>Cancel</button>
                <button onClick={handleCreate}>Create</button>
            </div>
        </div>
    );
};

export default NewCharacter;