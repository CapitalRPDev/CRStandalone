import { useEffect } from "react";
import { fetchNui } from "../utils/fetchNui";

const isDui = new URLSearchParams(window.location.search).get('mode') === 'dui';

export const useDuiKeyRelay = () => {
    useEffect(() => {
        if (isDui) return;

        let ctrlHeld = false;

        const keyHandler = (e: KeyboardEvent) => {
            if (e.key === 'Control') {
                ctrlHeld = true;
                return;
            }

            if (e.key === 'Escape') {
                fetchNui('duiEscape', {}).catch(() => {});
                return;
            }

            if (ctrlHeld && e.key === 'v') {
                navigator.clipboard.readText().then(text => {
                    if (text) fetchNui('duiKey', { key: `PASTE:${text.trim()}` });
                }).catch(() => {});
                return;
            }

            const key = e.key === 'Backspace' ? 'Backspace'
                : e.key === 'Enter' ? 'Enter'
                : e.key === ' ' ? ' '
                : e.key.length === 1 ? e.key
                : null;
            if (key) fetchNui('duiKey', { key });
        };

        const keyUpHandler = (e: KeyboardEvent) => {
            if (e.key === 'Control') ctrlHeld = false;
        };

        window.addEventListener('keydown', keyHandler);
        window.addEventListener('keyup', keyUpHandler);
        return () => {
            window.removeEventListener('keydown', keyHandler);
            window.removeEventListener('keyup', keyUpHandler);
        };
    }, []);
};