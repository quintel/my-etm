import { Controller } from "@hotwired/stimulus";

const RECOVERY_KEY = "etm-session-recovery";
const REFRESH_URL = "/session/refresh";

// Connects to data-controller="session-keeper". Keeps the shared JWT session cookie (etm_session,
// JwtSessionCookies::ACCESS_TTL) alive for as long as this tab stays open: MyETM's own UI now reads
// identity from that cookie (see ApplicationController#current_user), so — like every other ETM app
// — it needs to refresh the cookie before it expires, or a long-idle tab silently signs itself out
// mid-session. The exact lifetime is read at runtime from the etm_session_exp hint cookie, so it is
// deliberately not restated here.
//
// Deliberately in step with identity/session_keeper.js in the identity gem (and its mirror,
// multi-year-charts/utils/useSessionKeeper.ts). MyETM cannot import the gem's module — it is the
// provider and does not depend on the gem — so this stays a copy; keep the three behaviours below
// (lead time, jitter, visibility re-schedule) aligned with it.
export default class extends Controller {
  // Which hint cookie to time off. Deployments sharing a cookie domain suffix their cookie names,
  // so the name comes from the server rather than being assumed here.
  static values = { expCookie: { type: String, default: "etm_session_exp" } };

  connect() {
    this.onVisible = () =>
      document.visibilityState === "visible" && this.schedule();

    this.schedule();
    document.addEventListener("visibilitychange", this.onVisible);
  }

  disconnect() {
    window.clearTimeout(this.timer);
    document.removeEventListener("visibilitychange", this.onVisible);
  }

  schedule() {
    window.clearTimeout(this.timer);
    const expiryMs = this.readExpiryMs();

    if (expiryMs) {
      window.sessionStorage.removeItem(RECOVERY_KEY);

      // Refresh a minute before expiry, or halfway through the remaining life when the session is
      // shorter than that — a minute's lead on a 30-second ACCESS_TTL would otherwise mean
      // refreshing on a zero delay, forever.
      //
      // Plus 0-10s of jitter: without it every open tab, in every ETM app, refreshes on the same
      // tick, and the ones whose request was already in flight when the winner rotated the refresh
      // token present a token that has just been revoked.
      const remaining = expiryMs - Date.now();
      const lead = Math.min(60_000, Math.max(remaining / 2, 0));
      const delay = Math.max(remaining - lead + Math.random() * 10_000, 0);

      this.timer = window.setTimeout(() => {
        this.refresh().then((ok) => ok && this.schedule());
      }, delay);
    } else if (!window.sessionStorage.getItem(RECOVERY_KEY)) {
      window.sessionStorage.setItem(RECOVERY_KEY, "1");
      this.refresh().then((ok) => {
        if (ok) {
          window.sessionStorage.removeItem(RECOVERY_KEY);
          window.location.reload();
        }
      });
    }
  }

  refresh() {
    return fetch(REFRESH_URL, { method: "POST", credentials: "same-origin" })
      .then((response) => response.ok)
      .catch(() => false);
  }

  readExpiryMs() {
    const match = document.cookie.match(
      new RegExp(`(?:^|;\\s*)${this.expCookieValue}=([^;]+)`)
    );
    if (!match) return null;

    const exp = parseInt(decodeURIComponent(match[1]), 10);
    return Number.isFinite(exp) ? exp * 1000 : null;
  }
}
