import React from "react";
import { Officer } from "./types";

interface DutyPageProps {
    activeOfficers: Officer[];
    onDuty: boolean;
    onToggleDuty: () => void;
    onPageChange: (page: string) => void;
    
}

const DutyPage: React.FC<DutyPageProps> = ({ activeOfficers, onDuty, onToggleDuty, onPageChange }) => {
    return (
        <div className="app-page">
            <div className="app-page-header">
                <span className="app-page-header-title">Duty Roster</span>
                <div className="app-page-header-actions">
                    <i className="fa-solid fa-minus" onClick={() => onPageChange("home")}></i>
                    <i className="fa-solid fa-x" onClick={() => onPageChange("home")}></i>
                </div>
            </div>
            <div className="app-page-content">
                <div className="duty-actions">
                    <button
                        className={`duty-btn ${onDuty ? 'duty-btn-off' : 'duty-btn-on'}`}
                        onClick={onToggleDuty}
                        data-action="toggleDuty"
                    >
                        {onDuty ? 'Book Off Duty' : 'Book On Duty'}
                    </button>
                    <span className="officer-count">{activeOfficers.length} officer{activeOfficers.length !== 1 ? 's' : ''} on duty</span>
                </div>
                <table className="officers-table">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Callsign</th>
                            <th>Division</th>
                            <th>Grade</th>
                        </tr>
                    </thead>
                    <tbody>
                        {activeOfficers.map((officer, i) => (
                            <tr key={i}>
                                <td>{officer.name}</td>
                                <td>{officer.callsign}</td>
                                <td>{officer.division}</td>
                                <td><span className="officer-grade">{officer.grade}</span></td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
};

export default DutyPage;