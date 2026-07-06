import { Controller } from "@hotwired/stimulus";

const RECOVERY_KEY = "etm-session-recovery";
const REFRESH_URL = "/session/refresh";

// Connects to data-controller="session-keeper". Keeps the shared JWT session cookie (etm_session,
// 10 min) alive for as long as this tab stays open: MyETM's own UI now reads identity from that
// cookie (see ApplicationController#current_user), so — like every other ETM app — it needs to
// refresh the cookie before it expires, or a long-idle tab silently signs itself out mid-session.
export default class extends Controller {
  connect() {
    this.schedule();
  }

  disconnect() {
    window.clearTimeout(this.timer);
  }

  schedule() {
    const expiryMs = this.readExpiryMs();

    if (expiryMs) {
      window.sessionStorage.removeItem(RECOVERY_KEY);
      const delay = Math.max(expiryMs - Date.now() - 60_000, 0);
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
    const match = document.cookie.match(/(?:^|;\s*)etm_session_exp=([^;]+)/);
    if (!match) return null;

    const exp = parseInt(decodeURIComponent(match[1]), 10);
    return Number.isFinite(exp) ? exp * 1000 : null;
  }
}
