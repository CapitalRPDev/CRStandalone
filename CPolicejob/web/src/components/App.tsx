import React, { useState } from "react";
import "./App.css";
import { useNuiEvent } from "../hooks/useNuiEvent";

import { debugData } from "../utils/debugData";

 debugData<any>([
  {
    action: "setPlayerData",
    data: {
      job: "police",
      grade: 1,
    }
  },
]);



const App: React.FC = () => {

return (
    <div className="nui-wrapper">
      <h1>Tester</h1>
    </div>
);
};

export default App;