"""
Veille de prix billets Business au départ de Paris (CDG / ORY).

Source : Google Flights, via la lib `fast-flights`. Aucune clé API, aucun quota.

DEUX MODES, selon ce que contient routes.json :

1. MODE VEILLE (pas de champ "depart")
   On échantillonne des dates sur 10 mois et on alerte quand un prix est
   ANORMALEMENT bas par rapport à la médiane historique de la route.
   Sert à repérer les opportunités quand on n'a pas de projet précis.

2. MODE VOYAGE PRECIS (champ "depart" présent)
   On surveille des dates fixes (± flexibilité) et on alerte dès que le prix
   passe sous "prix_max". Sert quand on sait où et quand on veut partir.
"""

import json
import os
import statistics
import time
from datetime import date, datetime, timedelta
from pathlib import Path

import requests
from fast_flights import FlightQuery, Passengers, create_query, get_flights

# --- Configuration ---------------------------------------------------------

ROOT = Path(__file__).parent
ROUTES_FILE = ROOT / "routes.json"
HISTORY_FILE = ROOT / "data" / "prices.json"

TELEGRAM_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "").strip()


def env_float(name, default):
    """Lit une variable d'environnement en tolérant qu'elle soit vide."""
    raw = os.environ.get(name, "").strip()
    try:
        return float(raw)
    except (TypeError, ValueError):
        return default


# Mode veille : alerte si prix < 60 % de la médiane de la route
ANOMALY_RATIO = env_float("ANOMALY_RATIO", 0.60)
MIN_OBSERVATIONS = 12          # observations requises avant de juger
SCAN_START_DAYS = 21           # on commence à J+21
SCAN_HORIZON_DAYS = 300        # jusqu'à J+300
SCAN_STEP_DAYS = 21            # une date tous les 21 jours
DELAY_SECONDS = env_float("DELAY_SECONDS", 4)


# --- Récupération des prix -------------------------------------------------

def search_offer(origin, destination, depart, retour=None):
    """Meilleure offre business pour une date (ou un aller-retour). None si rien."""
    legs = [FlightQuery(date=depart, from_airport=origin, to_airport=destination)]
    trip = "one-way"
    if retour:
        legs.append(FlightQuery(date=retour, from_airport=destination, to_airport=origin))
        trip = "round-trip"

    try:
        results = get_flights(create_query(
            flights=legs,
            trip=trip,
            seat="business",
            passengers=Passengers(adults=1),
            currency="EUR",
            language="fr",
        ))
    except Exception as exc:
        print(f"  ! {origin}->{destination} {depart} : {type(exc).__name__} {exc}")
        return None

    offers = [f for f in results if getattr(f, "price", None)]
    if not offers:
        return None

    best = min(offers, key=lambda f: f.price)
    segments = best.flights
    return {
        "price": float(best.price),
        "airlines": ", ".join(best.airlines) if best.airlines else "?",
        "stops": max(len(segments) - 1, 0),
    }


# --- Historique ------------------------------------------------------------

def load_history():
    if HISTORY_FILE.exists():
        return json.loads(HISTORY_FILE.read_text())
    return {}


def save_history(history):
    HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    HISTORY_FILE.write_text(json.dumps(history, indent=2, ensure_ascii=False))


# --- Notification ----------------------------------------------------------

def notify(message):
    print(message)
    if not TELEGRAM_TOKEN or not TELEGRAM_CHAT_ID:
        print("  (Telegram non configuré — alerte visible dans les logs seulement)")
        return
    try:
        requests.post(
            f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
            json={
                "chat_id": TELEGRAM_CHAT_ID,
                "text": message,
                "parse_mode": "Markdown",
                "disable_web_page_preview": True,
            },
            timeout=30,
        )
    except requests.RequestException as exc:
        print(f"  ! Telegram injoignable : {exc}")


def google_link(origin, destination, depart):
    return (
        f"https://www.google.com/travel/flights?q=Flights%20to%20{destination}"
        f"%20from%20{origin}%20on%20{depart}%20business"
    )


# --- Mode 1 : veille sur anomalie -----------------------------------------

def scan_dates():
    today = date.today()
    d = today + timedelta(days=SCAN_START_DAYS)
    end = today + timedelta(days=SCAN_HORIZON_DAYS)
    while d <= end:
        yield d.isoformat()
        d += timedelta(days=SCAN_STEP_DAYS)


def run_veille(route, history):
    origin, destination = route["origin"], route["destination"]
    key = f"{origin}-{destination}"
    history.setdefault(key, {"observations": []})
    prices = [o["price"] for o in history[key]["observations"]]
    found = alerts = 0

    print(f"\n=== VEILLE {key} ({route.get('label', '')}) ===")
    for depart in scan_dates():
        offer = search_offer(origin, destination, depart)
        time.sleep(DELAY_SECONDS)
        if not offer:
            continue

        found += 1
        print(f"  {depart} : {offer['price']:.0f} € ({offer['airlines']})")

        if len(prices) >= MIN_OBSERVATIONS:
            median = statistics.median(prices)
            if offer["price"] < median * ANOMALY_RATIO:
                reduction = round((1 - offer["price"] / median) * 100)
                stops = "direct" if offer["stops"] == 0 else f"{offer['stops']} escale(s)"
                notify(
                    f"*Prix anormal — {origin} → {destination}*\n"
                    f"*{offer['price']:.0f} €* (médiane {median:.0f} €, -{reduction} %)\n"
                    f"Départ {depart} · {offer['airlines']} · {stops}\n\n"
                    f"[Vérifier sur Google Flights]({google_link(origin, destination, depart)})\n"
                    f"_Un tarif anormal tient rarement plus de quelques heures._"
                )
                alerts += 1

        history[key]["observations"].append({
            "date": datetime.utcnow().isoformat(timespec="seconds"),
            "departure_date": depart,
            "price": offer["price"],
            "airlines": offer["airlines"],
        })

    history[key]["observations"] = history[key]["observations"][-400:]
    return found, alerts


# --- Mode 2 : voyage précis -----------------------------------------------

def date_window(iso_date, flex):
    """Génère les dates autour d'une date cible."""
    base = datetime.fromisoformat(iso_date).date()
    for delta in range(-flex, flex + 1):
        d = base + timedelta(days=delta)
        if d > date.today():
            yield d.isoformat(), delta


def run_voyage(route, history):
    origin, destination = route["origin"], route["destination"]
    label = route.get("label", f"{origin}-{destination}")
    depart_cible = route["depart"]
    retour_cible = route.get("retour")
    flex = int(route.get("flex_jours", 0))
    prix_max = float(route["prix_max"])

    key = f"voyage:{origin}-{destination}:{depart_cible}"
    history.setdefault(key, {"meilleure_alerte": None})
    found = alerts = 0

    print(f"\n=== VOYAGE {label} (cible ≤ {prix_max:.0f} €) ===")
    for depart, delta in date_window(depart_cible, flex):
        retour = None
        if retour_cible:
            r = datetime.fromisoformat(retour_cible).date() + timedelta(days=delta)
            retour = r.isoformat()

        offer = search_offer(origin, destination, depart, retour)
        time.sleep(DELAY_SECONDS)
        if not offer:
            continue

        found += 1
        trajet = f"{depart}" + (f" → {retour}" if retour else "")
        print(f"  {trajet} : {offer['price']:.0f} € ({offer['airlines']})")

        if offer["price"] > prix_max:
            continue

        # On n'alerte que si c'est mieux que la dernière alerte envoyée,
        # sinon on recevrait le même message tous les jours.
        deja = history[key]["meilleure_alerte"]
        if deja is not None and offer["price"] >= deja * 0.97:
            continue

        stops = "direct" if offer["stops"] == 0 else f"{offer['stops']} escale(s)"
        notify(
            f"*Objectif atteint — {label}*\n"
            f"*{offer['price']:.0f} €* (cible : {prix_max:.0f} €)\n"
            f"{trajet} · {offer['airlines']} · {stops}\n\n"
            f"[Réserver via Google Flights]({google_link(origin, destination, depart)})"
        )
        history[key]["meilleure_alerte"] = offer["price"]
        alerts += 1

    return found, alerts


# --- Boucle principale -----------------------------------------------------

def main():
    routes = json.loads(ROUTES_FILE.read_text())
    history = load_history()
    total_found = total_alerts = 0

    for route in routes:
        if route.get("depart"):
            f, a = run_voyage(route, history)
        else:
            f, a = run_veille(route, history)
        total_found += f
        total_alerts += a

    save_history(history)
    print(f"\nTerminé : {total_found} prix relevés, {total_alerts} alerte(s).")

    if total_found == 0:
        print("Aucun prix relevé — Google a probablement bloqué les requêtes. "
              "Augmente DELAY_SECONDS ou réduis le nombre de routes.")


if __name__ == "__main__":
    main()
