import { useEffect } from "react";
import { fetchNui } from "../utils/fetchNui";

const isDui = new URLSearchParams(window.location.search).get('mode') === 'dui';

export const useDuiKeyRelay = () => {
    useEffect(() => {
        if (isDui) return;

        const keyHandler = (e: KeyboardEvent) => {
            if (e.key === 'Escape') {
                fetchNui('duiEscape', {}).catch(() => {});
                return;
            }
            const key = e.key === 'Backspace' ? 'Backspace'
                : e.key === 'Enter' ? 'Enter'
                : e.key === ' ' ? ' '
                : e.key.length === 1 ? e.key
                : null;
            if (key) fetchNui('duiKey', { key });
        };

        window.addEventListener('keydown', keyHandler);
        return () => {
            window.removeEventListener('keydown', keyHandler);
        };
    }, []);
};