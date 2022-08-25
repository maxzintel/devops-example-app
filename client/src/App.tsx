import React, { useContext, useEffect, useState } from "react";
import { Api, User } from "./services/api";
// import dotenv from 'dotenv';
// dotenv.config();


// declare var process : {
//   env: {
//     REACT_APP_BACKEND_URL: string
//   }
// }

/**
 * Returns value stored in environment variable with the given `name`.
 * Throws Error if no such variable or if variable undefined; thus ensuring type-safety.
 * @param name - name of variable to fetch from this process's environment.
 */
export function env(name: string): string {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing: process.env['${name}'].`);
  }

  return value;
}

let REACT_APP_BACKEND_URL = env('REACT_APP_BACKEND_URL');

function Visitor() {
  console.log(process.env.REACT_APP_BACKEND_URL);
  const { api } = useContext(appContext);
  const [visitors, setVisitors] = useState(0);
  async function effect() {
    const numVisitors = await api.getVisited();
    setVisitors(numVisitors.visited);
  }

  useEffect(() => {
    effect();
  }, []);

  return (
    <div>
      <p>Number of visitors: {visitors} </p>
      <button
        onClick={() => {
          effect();
        }}
      >
        Increase visitors
      </button>
      <button
        onClick={async () => {
          const numVisitors = await api.clearVisited();
          setVisitors(numVisitors.visited);
        }}
      >
        Clear visitors
      </button>
    </div>
  );
}

function Users() {
  const { api } = useContext(appContext);
  const [users, setUsers] = useState<User[]>([]);
  async function effect() {
    const users = await api.getUsers();
    setUsers(users);
  }
  useEffect(() => {
    effect();
  }, []);

  return (
    <div>
      <p>Users {JSON.stringify(users, null, 1)}</p>
      <button
        onClick={async () => {
          await api.makeUser();
          effect();
        }}
      >
        Make User
      </button>
      <button
        onClick={async () => {
          await api.clearUsers();
          effect();
        }}
      >
        Clear users
      </button>
    </div>
  );
}

const appContext = React.createContext({
  api: new Api(REACT_APP_BACKEND_URL || "asdasd"),
});

function App() {
  return (
    <div className="App">
      <Visitor />
      <Users />
    </div>
  );
}

export default App;
