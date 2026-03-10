export interface CharacterData {
  citizenid: string;
  name: string;
  csn: number;
  charinfo: {
    firstname: string;
    lastname: string;
    birthdate: string;
    nationality: string;
    gender: number;
  };
  job: {
    name: string;
    label: string;
    grade: {
      name: string;
      level: number;
    };
  };
  money: {
    bank: number;
    cash: number;
  };
}