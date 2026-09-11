"use client";

import {
  createContext,
  useActionState,
  useContext,
  type ReactNode,
} from "react";

import type { AuthActionState } from "@/app/auth/actions";

import styles from "./auth.module.css";

type AuthAction = (
  previousState: AuthActionState,
  formData: FormData,
) => Promise<AuthActionState>;

const AuthErrorDescriptionContext = createContext<string | undefined>(undefined);

export function useAuthErrorDescription() {
  return useContext(AuthErrorDescriptionContext);
}

export function AuthForm({
  action,
  children,
}: {
  action: AuthAction;
  children: ReactNode;
}) {
  const [state, formAction] = useActionState(action, {});

  return (
    <form className={styles.form} action={formAction} noValidate>
      {state.error ? (
        <p className={styles.error} id="auth-form-error" role="alert">
          {state.error}
        </p>
      ) : null}
      <AuthErrorDescriptionContext.Provider
        value={state.error ? "auth-form-error" : undefined}
      >
        {children}
      </AuthErrorDescriptionContext.Provider>
    </form>
  );
}
