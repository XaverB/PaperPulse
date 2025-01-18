declare global {
  namespace NodeJS {
    interface ProcessEnv {
      REACT_APP_API_BASE_URL: string;
      REACT_APP_FUNCTION_KEY: string;
      NODE_ENV: 'development' | 'production' | 'test';
    }
  }
}

export {}