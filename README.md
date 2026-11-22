# SPELUNKR (Unofficial)

An unofficial iPhone and iPad app for [SPELUNKR](https://spelunkr.tv/), the 24/7 channels of forgotten Internet Archive video. It's the same site you'd open in Safari, as a real app on your home screen.

> **Unofficial fan project.** Not affiliated with, endorsed by or connected to SPELUNKR or the Internet Archive. The app shows the official site; all videos belong to their owners. No ads, accounts or tracking.

## Download

**[Download SPELUNKR](https://github.com/hotwheelz3000/spelunkr-app/releases/latest)**: open the link, then tap the `.ipa` file under **Assets** (named with the version, e.g. `SPELUNKR-1.0.ipa`; later builds of a version add a build number, e.g. `SPELUNKR-1.0-2.ipa`).

## How to install

The app isn't on the App Store, so you install it yourself (iOS 17 or later):

1. **Download the `.ipa`** from the link above.
2. **Install it** with [Sideloadly](https://sideloadly.io), [AltStore](https://altstore.io) or a signing service such as Signulous.
3. **Trust it:** Settings → General → VPN & Device Management → your Apple ID → **Trust**.

## What it does

- **Full-screen site** with no Safari bars, and the site's purple instead of a white flash while it loads.
- **Videos play in the page**, with fullscreen, rotation to landscape, AirPlay and Picture in Picture.
- **Sound keeps going** with the screen locked, and plays with the silent switch on.
- **Swipe from the edge** to go back or forward.
- **Links that leave SPELUNKR** (an Internet Archive page, say) open in Safari.
- **No connection when it opens?** It tries again by itself.

## Building

Every push to `main` builds an unsigned IPA with [xtool](https://xtool.sh) on GitHub Actions and publishes it as the `latest` release. The icon is drawn by `scripts/make-app-icon.py`.
