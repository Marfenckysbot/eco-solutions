import React from "react";
import { createRoot } from "react-dom/client";
function App() {
  return (
    <div style={{ padding: 24, fontFamily: "system-ui" }}>
      <h1>Eco Admin</h1>
      <p>Manage content, users, and subscriptions here.</p>
    </div>
  );
}
createRoot(document.getElementById("root")).render(<App />);