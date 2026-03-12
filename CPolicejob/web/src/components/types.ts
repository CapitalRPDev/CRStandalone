export interface SpawnLocation {
    label: string;
    index: number;
    jobLock: string | false;
    coords: {
        x: number;
        y: number;
        z: number;
        w: number;
    };
}