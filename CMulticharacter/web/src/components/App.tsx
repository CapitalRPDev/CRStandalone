import React, { useState } from "react";
import "./App.css";
import { fetchNui } from "../utils/fetchNui";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { debugData } from "../utils/debugData";
import CharacterList from "./CharacterList";
import SelectCharacter from "./SelectCharacter";
import NewCharacter from "./NewCharacter";
import { CharacterData } from "./types";

 debugData<any>([
  {
    action: "ui",
    data: {
      toggle: true,
      nChar: 4,
      enableDeleteButton: true,
    }
  },
  {
    action: "setupCharacters",
    data: {
      characters: [
        {
          citizenid: "ABC123",
          name: "Marius Hanssen",
          csn: 102938,
          job: "Unemployed",
          dob: "09.02.2004",
          bank: 5000,
          charinfo: {
            firstname: "Marius",
            lastname: "Hanssen",
            birthdate: "09.02.2004",
            nationality: "Norwegian",
            gender: 0,
          },
          money: {
            bank: 5000,
            cash: 500,
          },
        },
        {
          citizenid: "DEF456",
          name: "John Doe",
          csn: 847291,
          job: "Police Officer",
          dob: "14.06.1990",
          bank: 12500,
          charinfo: {
            firstname: "John",
            lastname: "Doe",
            birthdate: "14.06.1990",
            nationality: "British",
            gender: 0,
          },
          money: {
            bank: 12500,
            cash: 1200,
          },
        },
        {
          citizenid: "GHI789",
          name: "James Wright",
          csn: 334521,
          job: "Mechanic",
          dob: "22.11.1985",
          bank: 3200,
          charinfo: {
            firstname: "James",
            lastname: "Wright",
            birthdate: "22.11.1985",
            nationality: "American",
            gender: 0,
          },
          money: {
            bank: 3200,
            cash: 300,
          },
        },
      ]
    }
  }
]); 

const App: React.FC = () => {
  const [visible, setVisible] = useState(true);
  const [active, setActive] = useState<string>("home");
  const [characters, setCharacters] = useState<CharacterData[]>([]);
  const [selectedCharacter, setSelectedCharacter] = useState<CharacterData | null>(null);
  const [maxCharacters, setMaxCharacters] = useState<number>(3);

useNuiEvent<any>("ui", (data) => {
    setMaxCharacters(data.nChar);
    if (data.toggle) {
        setActive("home");
        setSelectedCharacter(null);
        fetchNui("setupCharacters", {});
    }
    setTimeout(() => setVisible(data.toggle), 100);
});

  useNuiEvent<any>("setupCharacters", (data) => {
    console.log("setupCharacters data:", JSON.stringify(data));
    const chars = Array.isArray(data) ? data : (data?.characters ?? []);
    setCharacters(chars);
  });


const onPageChange = (page: string, data?: CharacterData) => {
  setActive(page);
  setSelectedCharacter(data || null);

  if (page === "select-character" && data) {
    fetchNui("previewPed", { Data: { citizenid: data.citizenid } });
    fetchNui("removeBlur", {}); 
  }

  if (page === "home") {
    fetchNui("reapplyBlur", {});
  }
};

  if (!visible) return null;

  return (
    <div className="nui-wrapper">
      <div className="multichar-container">

        <div className="multichar-header">
          <img src="./logo.png" alt="logo" className="multichar-logo" />
          <span className="multichar-title">Multicharacter</span>
        </div>

        {active === "select-character" && (
          <SelectCharacter onPageChange={onPageChange} character={selectedCharacter} />
        )}
        {active === "new-character" && (
          <NewCharacter onPageChange={onPageChange} />
        )}
        {active === "home" && (
          <CharacterList onPageChange={onPageChange} characters={characters} maxCharacters={maxCharacters} />
        )}

      </div>
    </div>
  );
};

export default App;