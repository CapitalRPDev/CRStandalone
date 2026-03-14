import React, { useState, useEffect, useRef } from "react";

interface Props {
    onLogin: (username: string, password: string) => boolean;
}

const LoginPage: React.FC<Props> = ({ onLogin }) => {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");
    const [error, setError] = useState("");
    const usernameRef = useRef("");
    const passwordRef = useRef("");
    const onLoginRef = useRef(onLogin);
    const isDui = new URLSearchParams(window.location.search).get('mode') === 'dui';

    useEffect(() => { onLoginRef.current = onLogin; }, [onLogin]);
    useEffect(() => { usernameRef.current = username; }, [username]);
    useEffect(() => { passwordRef.current = password; }, [password]);

    const handleKeyDown = isDui ? undefined : (e: React.KeyboardEvent) => {
        if (e.key === 'Enter') {
            if (!username || !password) { setError("Please enter both fields."); return; }
            const success = onLoginRef.current(username, password);
            if (!success) setError("Incorrect username or password.");
        }
    };

    useEffect(() => {
        const handler = (e: Event) => {
            const { key, field } = (e as CustomEvent).detail;
            if (!field) return;

            if (key === 'Backspace') {
                if (field === 'username') setUsername(p => p.slice(0, -1));
                else setPassword(p => p.slice(0, -1));
            } else if (key === 'Enter') {
                const u = usernameRef.current;
                const p = passwordRef.current;
                if (!u || !p) { setError("Please enter both fields."); return; }
                const success = onLoginRef.current(u, p);
                if (!success) setError("Incorrect username or password.");
            } else if (key.length === 1) {
                if (field === 'username') setUsername(p => p + key);
                else setPassword(p => p + key);
            }
        };

        window.addEventListener('dui:key', handler);
        return () => window.removeEventListener('dui:key', handler);
    }, []);

    return (
        <div className="login-page">
            <div className="input-row">
                <label>Username</label>
                <input
                    type="text"
                    value={username}
                    onChange={isDui ? () => {} : (e) => setUsername(e.target.value)}
                    onKeyDown={handleKeyDown}
                />
            </div>
            <div className="input-row">
                <label>Password</label>
                <input
                    type="password"
                    value={password}
                    onChange={isDui ? () => {} : (e) => setPassword(e.target.value)}
                    onKeyDown={handleKeyDown}
                />
            </div>
            {error && <p className="login-error">{error}</p>}
        </div>
    );
};

export default LoginPage;