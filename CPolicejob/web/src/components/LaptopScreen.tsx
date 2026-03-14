import React, { useState, useCallback } from "react";
import LoginPage from "./LoginPage";
import LaptopHome from "./LaptopHome";
import { LoginDetails, Officer, PlayerData } from "./types";
import serverLogo from "./serverLogo.png";

interface Props {
    correctLoginDetails: LoginDetails | null;
    activeOfficers: Officer[];
    allOfficers: Officer[];
    playerData: PlayerData | null;
    onDuty: boolean;
    onToggleDuty: () => void;
}

const LaptopScreen: React.FC<Props> = ({ correctLoginDetails, activeOfficers, allOfficers, playerData, onDuty, onToggleDuty }) => {
  const [loggedIn, setLoggedIn] = useState(false);
  const [activePage, setActivePage] = useState("home");

  const onPageChange = (page: string) => setActivePage(page);

  const handleLogin = useCallback((username: string, password: string): boolean => {
    if (
        correctLoginDetails &&
        username === correctLoginDetails.username &&
        password === correctLoginDetails.password
    ) {
        setLoggedIn(true);
        return true;
    }
    return false;
  }, [correctLoginDetails]);

  if (loggedIn) {
    return (
      <LaptopHome
        onPageChange={onPageChange}
        activePage={activePage}
        activeOfficers={activeOfficers}
        allOfficers={allOfficers}
        playerData={playerData}
        onDuty={onDuty}
        onToggleDuty={onToggleDuty}
      />
    );
  }

  return (
    <div className="laptop-screen">
      <h1>Welcome to Capital Police</h1>
      <div className="profile-circle">
        <img src={serverLogo} alt="Server Logo" />
      </div>
      <LoginPage onLogin={handleLogin} />
    </div>
  );
};

export default LaptopScreen;