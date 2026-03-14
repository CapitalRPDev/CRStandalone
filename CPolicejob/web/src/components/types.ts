export interface LoginDetails { username: string; password: string; }
export interface PlayerData {
    job: string;
    grade: number;
    gradeName: string;
}

export interface Officer {
    id: number;
    name: string;
    callsign: string;
    division: string;
    grade: string;
    password?: string;
}

export interface ActiveOfficers {
    officers: Officer[];
}