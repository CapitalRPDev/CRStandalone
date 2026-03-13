import { useEffect } from "react";
import { fetchNui } from "../utils/fetchNui";

const isDui = new URLSearchParams(window.location.search).get('mode') === 'dui';

export const useDuiKeyRelay = () => {
    useEffect(() => {
        if (isDui) return;

        const handler = (e: KeyboardEvent) => {
if (e.key === 'Escape') {
    console.log('[NUI RELAY] ESC pressed');
    fetchNui('duiEscape', {}).catch(() => {});
    return;
}
            const key = e.key === 'Backspace' ? 'Backspace'
                : e.key === 'Enter' ? 'Enter'
                : e.key === ' ' ? ' '
                : e.key.length === 1 ? e.key
                : null;

            if (key) {
                fetchNui('duiKey', { key });
            }
        };

        window.addEventListener('keydown', handler);
        return () => window.removeEventListener('keydown', handler);
    }, []);
};