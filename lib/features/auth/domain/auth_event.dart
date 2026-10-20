/// Peristiwa autentikasi yang relevan bagi router (dipetakan dari
/// `AuthChangeEvent` Supabase di repository).
enum AuthEvent { signedIn, signedOut, passwordRecovery, userUpdated, other }
