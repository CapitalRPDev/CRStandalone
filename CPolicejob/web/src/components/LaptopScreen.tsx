import React, { useState, useCallback } from "react";
import LoginPage from "./LoginPage";
import LaptopHome from "./LaptopHome";
import { LoginDetails } from "./types";
import serverLogo from "./serverLogo.png";

interface Props {
  correctLoginDetails: LoginDetails | null;
}

const LaptopScreen: React.FC<Props> = ({ correctLoginDetails }) => {
  const [loggedIn, setLoggedIn] = useState(false);

  const handleLogin = useCallback((username: string, password: string): boolean => {
    console.log('[LOGIN] Attempting:', username, password, '| correct:', correctLoginDetails);
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
    return <LaptopHome />;
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