import React, { useState, useEffect } from "react";
import "./App.css";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { debugData } from "../utils/debugData";
import LaptopScreen from "./LaptopScreen";
import { LoginDetails, PlayerData, Officer } from "./types";
import { useDuiKeyRelay } from "../hooks/useDuiKeyRelay";

debugData<any>([
  { action: "setPlayerData", data: { job: "police", grade: 4, gradeName: "Chief Inspector" } },
  { action: "setCorrectLoginDetails", data: { username: "2043T", password: "admin" } },
  {
    action: "setActiveOfficers",
    data: [
      { id: 1, name: "John Smith",     callsign: "MP1", division: "Armed Response", grade: "Sergeant"   },
      { id: 2, name: "Sarah Johnson",  callsign: "MP2", division: "Traffic",        grade: "Constable"  },
      { id: 3, name: "James Brown",    callsign: "MP3", division: "CID",            grade: "Inspector"  },
      { id: 4, name: "Emily Davis",    callsign: "MP4", division: "Armed Response", grade: "Constable"  },
      { id: 5, name: "Michael Wilson", callsign: "MP5", division: "Traffic",        grade: "Sergeant"   },
    ]
  },
  {
    action: "setAllOfficers",
    data: [
      { id: 1, name: "John Smith",     callsign: "MP1", division: "Armed Response", grade: "Sergeant"   },
      { id: 2, name: "Sarah Johnson",  callsign: "MP2", division: "Traffic",        grade: "Constable"  },
      { id: 3, name: "James Brown",    callsign: "MP3", division: "CID",            grade: "Inspector"  },
      { id: 4, name: "Emily Davis",    callsign: "MP4", division: "Armed Response", grade: "Constable"  },
      { id: 5, name: "Michael Wilson", callsign: "MP5", division: "Traffic",        grade: "Sergeant"   },
    ]
  }
]);

const isDui = new URLSearchParams(window.location.search).get('mode') === 'dui';
(window as any)._duiActiveField = null;

const sendDuiAction = (action: string) => {
    const resourceName = (window as any).GetParentResourceName?.() ?? 'CPolicejob';
    const xhr = new XMLHttpRequest();
    xhr.open('POST', `https://${resourceName}/duiAction`, true);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.send(JSON.stringify({ action }));
};

const App: React.FC = () => {
  useDuiKeyRelay();

  const [correctLoginDetails, setCorrectLoginDetails] = useState<LoginDetails | null>(null);
  const [playerData, setPlayerData] = useState<PlayerData | null>(null);
  const [cursorPos, setCursorPos] = useState({ x: 0, y: 0 });
  const [activeOfficers, setActiveOfficers] = useState<Officer[]>([]);
  const [allOfficers, setAllOfficers] = useState<Officer[]>([]);
  const [onDuty, setOnDuty] = useState<boolean>(false);

  useNuiEvent<Officer[]>("setActiveOfficers", setActiveOfficers);
  useNuiEvent<Officer[]>("setAllOfficers", setAllOfficers);
  useNuiEvent<LoginDetails>("setCorrectLoginDetails", setCorrectLoginDetails);
  useNuiEvent<PlayerData>("setPlayerData", setPlayerData);
  useNuiEvent<boolean>("setOnDuty", setOnDuty);

  const handleToggleDuty = () => {
    setOnDuty(p => !p);
    sendDuiAction('toggleDuty');
  };

  useEffect(() => {
    const handler = (e: MessageEvent) => {
      const data = e.data;

      if (data?.type === 'setCorrectLoginDetails') setCorrectLoginDetails(data.data);
      if (data?.type === 'setPlayerData') setPlayerData(data.data);
      if (data?.type === 'setActiveOfficers') setActiveOfficers(data.data);
      if (data?.type === 'setAllOfficers') setAllOfficers(data.data);

      if (data?.type === 'cursor') {
        setCursorPos({ x: data.x, y: data.y });
      }

      if (data?.type === 'click') {
        setCursorPos({ x: data.x, y: data.y });
        const el = document.elementFromPoint(data.x, data.y) as HTMLElement;
        if (!el) return;

        if (data.pressed) {
          if (el.tagName === 'INPUT') {
            const inputEl = el as HTMLInputElement;
            const fieldName = inputEl.getAttribute('name') || (inputEl.type === 'password' ? 'password' : 'username');
            (window as any)._duiActiveField = fieldName;
          }
          el.dispatchEvent(new MouseEvent('mousedown', { clientX: data.x, clientY: data.y, bubbles: true }));
        } else {
          el.dispatchEvent(new MouseEvent('mouseup', { clientX: data.x, clientY: data.y, bubbles: true }));
          el.dispatchEvent(new MouseEvent('click', { clientX: data.x, clientY: data.y, bubbles: true }));
          if (el.tagName === 'INPUT') {
            el.focus();
            el.dispatchEvent(new FocusEvent('focus', { bubbles: true }));
          }
        }
      }

      if (data?.type === 'key') {
        window.dispatchEvent(new CustomEvent('dui:key', {
          detail: { key: data.key, field: (window as any)._duiActiveField }
        }));
      }

      if (data?.type === 'scroll') {
        let el = document.elementFromPoint(data.x, data.y) as HTMLElement | null;
        while (el && el !== document.body) {
          const overflow = window.getComputedStyle(el).overflowY;
          if ((overflow === 'auto' || overflow === 'scroll') && el.scrollHeight > el.clientHeight) {
            el.scrollTop -= data.dy * 40;
            break;
          }
          el = el.parentElement;
        }
      }
    };

    window.addEventListener('message', handler);
    return () => window.removeEventListener('message', handler);
  }, []);

  return (
    <div className={`nui-wrapper ${isDui ? 'dui-mode' : ''}`}>
      <LaptopScreen
        correctLoginDetails={correctLoginDetails}
        activeOfficers={activeOfficers}
        allOfficers={allOfficers}
        playerData={playerData}
        onDuty={onDuty}
        onToggleDuty={handleToggleDuty}
      />
      {isDui && (
        <div className="dui-cursor" style={{ left: cursorPos.x, top: cursorPos.y }} />
      )}
    </div>
  );
};

export default App;