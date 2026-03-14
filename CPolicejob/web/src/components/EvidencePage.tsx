import React, { useState, useEffect } from "react";

const isDui = new URLSearchParams(window.location.search).get('mode') === 'dui';

interface EvidenceForm {
    cadReference: string;
    callsign: string;
    material: string;
    packId: string;
    comment: string;
}

const EvidencePage: React.FC = () => {
    const [form, setForm] = useState<EvidenceForm>({
        cadReference: '',
        callsign: '',
        material: '',
        packId: '',
        comment: '',
    });
    const [generatedCode, setGeneratedCode] = useState<string | null>(null);
    const [copied, setCopied] = useState(false);

    useEffect(() => {
        const handler = (e: Event) => {
            const { key, field } = (e as CustomEvent).detail;
            if (!field) return;
            const textFields = ['cadReference', 'callsign', 'material', 'packId', 'comment'];
            if (!textFields.includes(field)) return;

            if (key === 'Backspace') {
                setForm(p => ({ ...p, [field]: p[field as keyof EvidenceForm].slice(0, -1) }));
            } else if (key.length === 1) {
                setForm(p => ({ ...p, [field]: p[field as keyof EvidenceForm] + key }));
            }
        };

        window.addEventListener('dui:key', handler);
        return () => window.removeEventListener('dui:key', handler);
    }, []);

    useEffect(() => {
        const handler = (e: MessageEvent) => {
            if (e.data?.type === 'evidenceCodeGenerated') {
                setGeneratedCode(e.data.code);
            }
        };
        window.addEventListener('message', handler);
        return () => window.removeEventListener('message', handler);
    }, []);

    const generateCode = () => {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let code = 'EV-';
        for (let i = 0; i < 8; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return code;
    };

    const sendAction = (action: string, payload: object) => {
        const resourceName = (window as any).GetParentResourceName?.() ?? 'CPolicejob';
        const xhr = new XMLHttpRequest();
        xhr.open('POST', `https://${resourceName}/duiAction`, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.send(JSON.stringify({ action, ...payload }));
    };

    const handleSubmit = () => {
        if (!form.cadReference || !form.callsign || !form.material || !form.packId) return;
        const code = generateCode();
        setGeneratedCode(code);
        sendAction('logEvidence', { ...form, code });
        setForm({ cadReference: '', callsign: '', material: '', packId: '', comment: '' });
    };

    const handleCopy = () => {
        if (!generatedCode) return;
        navigator.clipboard.writeText(generatedCode);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
    };

    return (
        <div className="app-page">
            <div className="app-page-header">
                <span className="app-page-header-title">Evidence Log</span>
                <div className="app-page-header-actions">
                    <i className="fa-solid fa-minus"></i>
                    <i className="fa-solid fa-x"></i>
                </div>
            </div>
            <div className="app-page-content">
                {generatedCode ? (
                    <div className="evidence-result">
                        <div className="evidence-result-icon">
                            <i className="fa-solid fa-check-circle"></i>
                        </div>
                        <p className="evidence-result-label">Evidence Logged Successfully</p>
                        <p className="evidence-result-sublabel">Your evidence reference code:</p>
                        <div className="evidence-code">
                            <span>{generatedCode}</span>
                            <button className="evidence-copy-btn" onClick={handleCopy}>
                                <i className={`fa-solid ${copied ? 'fa-check' : 'fa-copy'}`}></i>
                                {copied ? 'Copied!' : 'Copy'}
                            </button>
                        </div>
                        <button className="duty-btn duty-btn-on" style={{ marginTop: '16px' }} onClick={() => setGeneratedCode(null)}>
                            Log New Evidence
                        </button>
                    </div>
                ) : (
                    <div className="evidence-form">
                        <div className="evidence-form-grid">
                            <div className="modal-field">
                                <label>CAD Reference</label>
                                <input name="cadReference" type="text" value={form.cadReference}
                                    onChange={isDui ? () => {} : e => setForm(p => ({ ...p, cadReference: e.target.value }))} />
                            </div>
                            <div className="modal-field">
                                <label>Your Callsign</label>
                                <input name="callsign" type="text" value={form.callsign}
                                    onChange={isDui ? () => {} : e => setForm(p => ({ ...p, callsign: e.target.value }))} />
                            </div>
                            <div className="modal-field">
                                <label>Evidence Material</label>
                                <input name="material" type="text" value={form.material}
                                    onChange={isDui ? () => {} : e => setForm(p => ({ ...p, material: e.target.value }))} />
                            </div>
                        <div className="modal-field">
                            <label>Evidence Pack ID</label>
                            <div className="input-with-btn">
                                <input name="packId" type="text" value={form.packId}
                                    onChange={isDui ? () => {} : e => setForm(p => ({ ...p, packId: e.target.value }))} />
                                <button className="input-side-btn" onClick={async () => {
                                    const text = await navigator.clipboard.readText();
                                    if (text) setForm(p => ({ ...p, packId: text.trim() }));
                                }}>
                                    <i className="fa-solid fa-clipboard"></i>
                                </button>
                            </div>
                        </div>
                        </div>
                        <div className="modal-field">
                            <label>Comment</label>
                            <input name="comment" type="text" value={form.comment}
                                onChange={isDui ? () => {} : e => setForm(p => ({ ...p, comment: e.target.value }))} />
                        </div>
                        <button className="duty-btn duty-btn-on evidence-submit-btn" onClick={handleSubmit}>
                            Submit Evidence
                        </button>
                    </div>
                )}
            </div>
        </div>
    );
};

export default EvidencePage;