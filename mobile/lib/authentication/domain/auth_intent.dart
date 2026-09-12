/// Which button the user tapped on the Welcome screen — disambiguates the
/// email path's register-vs-login call (the backend can't tell them apart
/// from a shared "continue" action; the phone/OTP path doesn't need this,
/// it's register-or-login-in-one by design).
enum AuthIntent { register, signIn }
