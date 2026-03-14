import React, { useState, useEffect, useRef } from "react";
import { Officer } from "./types";

const isDui = new URLSearchParams(window.location.search).get('mode') === 'dui';

const GRADES = [
    'Probationary Constable',
    'Constable',
    'Sergeant',
    'Inspector',
    'Chief Inspector',
    'Superintendent',
    'Chief Superintendent',
    'Commander',
    'Deputy Commissioner',
    'Commissioner',
];

const DIVISIONS = [
    'Armed Response',
    'Traffic',
    'CID',
    'Firearms',
    'Counter Terrorism',
    'Dog Unit',
    'Marine Unit',
    'Mounted Branch',
];

interface BossPageProps {
    onPageChange: (page: string) => void;
    allOfficers: Officer[];
    playerGrade: number;
}

type Modal = 'hire' | 'edit' | 'fire' | null;

const Dropdown: React.FC<{
    value: string;
    options: string[];
    onChange: (val: string) => void;
    name: string;
}> = ({ value, options, onChange }) => {
    const [open, setOpen] = useState(false);
    const ref = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const handler = (e: MouseEvent) => {
            if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
        };
        document.addEventListener('mousedown', handler);
        return () => document.removeEventListener('mousedown', handler);
    }, []);

    return (
        <div className="dropdown" ref={ref}>
            <div className="dropdown-selected" onClick={() => setOpen(p => !p)}>
                <span>{value || 'Select...'}</span>
                <i className={`fa-solid fa-chevron-${open ? 'up' : 'down'}`}></i>
            </div>
            {open && (
                <div className="dropdown-options">
                    {options.map(opt => (
                        <div
                            key={opt}
                            className={`dropdown-option ${value === opt ? 'selected' : ''}`}
                            onClick={() => { onChange(opt); setOpen(false); }}
                        >
                            {opt}
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};

const BossPage: React.FC<BossPageProps> = ({ onPageChange, allOfficers, playerGrade }) => {
    const [officers, setOfficers] = useState<Officer[]>(allOfficers);
    const [modal, setModal] = useState<Modal>(null);
    const [selectedOfficer, setSelectedOfficer] = useState<Officer | null>(null);
    const [hireForm, setHireForm] = useState({ citizenid: '', name: '', callsign: '', division: '', grade: '', password: '' });
    const [editForm, setEditForm] = useState({ callsign: '', division: '', grade: '', password: '' });

    const availableGrades = GRADES.filter((_, index) => index < playerGrade);

    useEffect(() => { setOfficers(allOfficers); }, [allOfficers]);

    useEffect(() => {
        if (!isDui) {
            setOfficers([
                { id: 1, name: "John Smith",    callsign: "MP1", division: "Armed Response", grade: "Sergeant"  },
                { id: 2, name: "Sarah Johnson", callsign: "MP2", division: "Traffic",        grade: "Constable" },
                { id: 3, name: "James Brown",   callsign: "MP3", division: "CID",            grade: "Inspector" },
            ]);
        }
    }, []);

    useEffect(() => {
        const handler = (e: MessageEvent) => {
            if (e.data?.type === 'setAllOfficers') setOfficers(e.data.data);
            if (e.data?.type === 'bossActionResult' && e.data.success) {
                setModal(null);
                setSelectedOfficer(null);
            }
        };
        window.addEventListener('message', handler);
        return () => window.removeEventListener('message', handler);
    }, []);

    useEffect(() => {
        const handler = (e: Event) => {
            const { key, field } = (e as CustomEvent).detail;
            if (!field) return;
            const textFields = ['citizenid', 'name', 'callsign', 'password'];
            if (!textFields.includes(field)) return;

            if (key === 'Backspace') {
                if (modal === 'hire') setHireForm(p => ({ ...p, [field]: p[field as keyof typeof p].slice(0, -1) }));
                else if (modal === 'edit') setEditForm(p => ({ ...p, [field]: p[field as keyof typeof p].slice(0, -1) }));
            } else if (key === 'Enter') {
                if (modal === 'hire') submitHire();
                else if (modal === 'edit') submitEdit();
            } else if (key.length === 1) {
                if (modal === 'hire') setHireForm(p => ({ ...p, [field]: p[field as keyof typeof p] + key }));
                else if (modal === 'edit') setEditForm(p => ({ ...p, [field]: p[field as keyof typeof p] + key }));
            }
        };

        window.addEventListener('dui:key', handler);
        return () => window.removeEventListener('dui:key', handler);
    }, [modal, hireForm, editForm]);

    const sendAction = (action: string, payload: object) => {
        const resourceName = (window as any).GetParentResourceName?.() ?? 'CPolicejob';
        const xhr = new XMLHttpRequest();
        xhr.open('POST', `https://${resourceName}/duiAction`, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.send(JSON.stringify({ action, ...payload }));
    };

    const openEdit = (officer: Officer) => {
        setSelectedOfficer(officer);
        setEditForm({ callsign: officer.callsign, division: officer.division, grade: officer.grade, password: '' });
        setModal('edit');
    };

    const openFire = (officer: Officer) => {
        setSelectedOfficer(officer);
        setModal('fire');
    };

    const submitHire = () => {
        console.log('[HIRE] form data:', hireForm);
        if (!hireForm.citizenid || !hireForm.name || !hireForm.callsign || !hireForm.division || !hireForm.grade || !hireForm.password) {
            console.log('[HIRE] missing fields, aborting');
            return;
        }
        sendAction('hireOfficer', { ...hireForm });
        setHireForm({ citizenid: '', name: '', callsign: '', division: '', grade: '', password: '' });
        setModal(null);
    };
    const submitEdit = () => {
        if (!selectedOfficer) return;
        sendAction('editOfficer', { id: selectedOfficer.id, ...editForm });
        setModal(null);
    };

    const submitFire = () => {
        if (!selectedOfficer) return;
        sendAction('fireOfficer', { id: selectedOfficer.id });
        setModal(null);
    };

    return (
        <div className="app-page">
            <div className="app-page-header">
                <span className="app-page-header-title">Boss Panel</span>
                <div className="app-page-header-actions">
                    <i className="fa-solid fa-minus" onClick={() => onPageChange("home")}></i>
                    <i className="fa-solid fa-x" onClick={() => onPageChange("home")}></i>
                </div>
            </div>
            <div className="app-page-content">
                <div className="duty-actions">
                    <button className="duty-btn duty-btn-on" onClick={() => setModal('hire')}>Hire Officer</button>
                    <span className="officer-count">{officers.length} officer{officers.length !== 1 ? 's' : ''}</span>
                </div>
                <table className="officers-table">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Callsign</th>
                            <th>Division</th>
                            <th>Grade</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {officers.map((officer) => (
                            <tr key={officer.id}>
                                <td>{officer.name}</td>
                                <td>{officer.callsign}</td>
                                <td>{officer.division}</td>
                                <td><span className="officer-grade">{officer.grade}</span></td>
                                <td>
                                    <div className="officer-actions">
                                        <button className="action-btn action-btn-edit" onClick={() => openEdit(officer)}>
                                            <i className="fa-solid fa-pen"></i>
                                        </button>
                                        <button className="action-btn action-btn-fire" onClick={() => openFire(officer)}>
                                            <i className="fa-solid fa-user-minus"></i>
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {modal === 'hire' && (
                <div className="modal-overlay">
                    <div className="modal">
                        <div className="modal-header">
                            <span>Hire Officer</span>
                            <i className="fa-solid fa-x" onClick={() => setModal(null)}></i>
                        </div>
                        <div className="modal-body">
                            <div className="modal-field">
                                <label>Citizen ID</label>
                                <input name="citizenid" type="text" value={hireForm.citizenid}
                                    onChange={isDui ? () => {} : e => setHireForm(p => ({ ...p, citizenid: e.target.value }))} />
                            </div>
                            <div className="modal-field">
                                <label>Full Name</label>
                                <input name="name" type="text" value={hireForm.name}
                                    onChange={isDui ? () => {} : e => setHireForm(p => ({ ...p, name: e.target.value }))} />
                            </div>
                            <div className="modal-field">
                                <label>Callsign</label>
                                <input name="callsign" type="text" value={hireForm.callsign}
                                    onChange={isDui ? () => {} : e => setHireForm(p => ({ ...p, callsign: e.target.value }))} />
                            </div>
                            <div className="modal-field">
                                <label>Division</label>
                                <Dropdown
                                    name="division"
                                    value={hireForm.division}
                                    options={DIVISIONS}
                                    onChange={val => setHireForm(p => ({ ...p, division: val }))}
                                />
                            </div>
                            <div className="modal-field">
                                <label>Grade</label>
                                <Dropdown
                                    name="grade"
                                    value={hireForm.grade}
                                    options={availableGrades}
                                    onChange={val => setHireForm(p => ({ ...p, grade: val }))}
                                />
                            </div>
                            <div className="modal-field">
                                <label>Password</label>
                                <input name="password" type="password" value={hireForm.password}
                                    onChange={isDui ? () => {} : e => setHireForm(p => ({ ...p, password: e.target.value }))} />
                            </div>
                        </div>
                        <div className="modal-footer">
                            <button className="duty-btn duty-btn-off" onClick={() => setModal(null)}>Cancel</button>
                            <button className="duty-btn duty-btn-on" onClick={submitHire}>Hire</button>
                        </div>
                    </div>
                </div>
            )}

            {modal === 'edit' && selectedOfficer && (
                <div className="modal-overlay">
                    <div className="modal">
                        <div className="modal-header">
                            <span>Edit — {selectedOfficer.name}</span>
                            <i className="fa-solid fa-x" onClick={() => setModal(null)}></i>
                        </div>
                        <div className="modal-body">
                            <div className="modal-field">
                                <label>Callsign</label>
                                <input name="callsign" type="text" value={editForm.callsign}
                                    onChange={isDui ? () => {} : e => setEditForm(p => ({ ...p, callsign: e.target.value }))} />
                            </div>
                            <div className="modal-field">
                                <label>Division</label>
                                <Dropdown
                                    name="division"
                                    value={editForm.division}
                                    options={DIVISIONS}
                                    onChange={val => setEditForm(p => ({ ...p, division: val }))}
                                />
                            </div>
                            <div className="modal-field">
                                <label>Grade</label>
                                <Dropdown
                                    name="grade"
                                    value={editForm.grade}
                                    options={availableGrades}
                                    onChange={val => setEditForm(p => ({ ...p, grade: val }))}
                                />
                            </div>
                            <div className="modal-field">
                                <label>New Password</label>
                                <input name="password" type="password" value={editForm.password}
                                    onChange={isDui ? () => {} : e => setEditForm(p => ({ ...p, password: e.target.value }))}
                                    placeholder="Leave blank to keep current" />
                            </div>
                        </div>
                        <div className="modal-footer">
                            <button className="duty-btn duty-btn-off" onClick={() => setModal(null)}>Cancel</button>
                            <button className="duty-btn duty-btn-on" onClick={submitEdit}>Save</button>
                        </div>
                    </div>
                </div>
            )}

            {modal === 'fire' && selectedOfficer && (
                <div className="modal-overlay">
                    <div className="modal">
                        <div className="modal-header">
                            <span>Fire Officer</span>
                            <i className="fa-solid fa-x" onClick={() => setModal(null)}></i>
                        </div>
                        <div className="modal-body">
                            <p className="modal-confirm-text">Are you sure you want to fire <strong>{selectedOfficer.name}</strong>?</p>
                        </div>
                        <div className="modal-footer">
                            <button className="duty-btn duty-btn-off" onClick={() => setModal(null)}>Cancel</button>
                            <button className="duty-btn duty-btn-on" onClick={submitFire}>Confirm</button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default BossPage;