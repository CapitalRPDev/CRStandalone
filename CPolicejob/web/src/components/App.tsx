import React, { useState, useEffect } from "react";
import "./App.css";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { debugData } from "../utils/debugData";
import LaptopScreen from "./LaptopScreen";
import { LoginDetails, PlayerData } from "./types";
import { useDuiKeyRelay } from "../hooks/useDuiKeyRelay";

debugData<any>([
  { action: "setPlayerData", data: { job: "police", grade: 1 } },
  { action: "setCorrectLoginDetails", data: { username: "2043T", password: "admin" } }
]);

const isDui = new URLSearchParams(window.location.search).get('mode') === 'dui';
(window as any)._duiActiveField = null;

const App: React.FC = () => {
  useDuiKeyRelay();

  const [correctLoginDetails, setCorrectLoginDetails] = useState<LoginDetails | null>(null);
  const [playerData, setPlayerData] = useState<PlayerData | null>(null);
  const [cursorPos, setCursorPos] = useState({ x: 0, y: 0 });

  useNuiEvent<LoginDetails>("setCorrectLoginDetails", setCorrectLoginDetails);
  useNuiEvent<PlayerData>("setPlayerData", setPlayerData);

  useEffect(() => {
    const handler = (e: MessageEvent) => {
      const data = e.data;

      if (data?.type === 'setCorrectLoginDetails') setCorrectLoginDetails(data.data);
      if (data?.type === 'setPlayerData') setPlayerData(data.data);

      if (data?.type === 'cursor') {
        setCursorPos({ x: data.x, y: data.y });
      }

      if (data?.type === 'click') {
        setCursorPos({ x: data.x, y: data.y });
        const el = document.elementFromPoint(data.x, data.y) as HTMLElement;
        if (!el) return;

        if (data.pressed) {
          if (el.tagName === 'INPUT') {
            (window as any)._duiActiveField = (el as HTMLInputElement).type === 'password' ? 'password' : 'username';
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
      <LaptopScreen correctLoginDetails={correctLoginDetails} />
      {isDui && (
        <div className="dui-cursor" style={{ left: cursorPos.x, top: cursorPos.y }} />
      )}
    </div>
  );
};

export default App;