export default interface PlayerData {
  health: number;
  hunger: number;
  thirst: number;
  stamina: number;
  armor: number;
  oxygen: number;
  speed?: number;
  rpm?: number;
  gear?: number;
  fuel?: number;
  isInVehicle?: boolean;
  engineHealth?: number;
  isUnderwater?: boolean;
}

export interface HudComponent {
  name: string;
  icon: string;
  defaultValue: number;
  color: string;
  event: string;
  order: number;
  row?: number;
  hideWhenZero?: boolean;
  showOnlyUnderwater?: boolean;
  showOnlyInCar?: boolean;
}



export interface Notification {
  id: string;
  text: string;
  icon: string;
  iconColor: string;
  duration: number;
}

export interface ProgressbarData {
  label: string;
  duration: number;
  icon?: string;
  color?: string;
  canCancel?: boolean;
  canMove?: boolean;
}