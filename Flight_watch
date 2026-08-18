"""
Veille de prix billets Business au départ de Paris (CDG / ORY).

Source : Google Flights, via la lib `fast-flights`. Aucune clé API, aucun quota.

Principe : on relève les prix tous les jours pour un échantillon de dates de
départ, on stocke l'historique, et on alerte uniquement quand le prix est
ANORMALEMENT bas par rapport à la médiane historique de la route.

Un prix bas ne vaut rien en soi. Ce qui compte, c'est l'écart à la normale.
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

TELEGRAM_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID")

# Seuil de déclenchement : alerte si prix < 60 % de la médiane de la route
ANOMALY_RATIO = float(os.environ.get("ANOMALY_RATIO", "0.60"))
# Nombre minimum d'observations avant de pouvoir juger d'une anomalie
MIN_OBSERVATIONS = 12
# Fenêtre de scan : dates de départ échantillonnées
SCAN_START_DAYS = 21        # on commence à J+21
SCAN_HORIZON_DAYS = 300     # jusqu'à J+300
SCAN_STEP_DAYS = 21         # une date tous les 21 jours
# Pause entre deux requêtes, pour ne pas se faire bloquer par Google
DELAY_SECONDS = float(os.environ.get("DELAY_SECONDS", "4"))


# --- Récupération des prix -------------------------------------------------

def search_offer(origin, destination, departure_date):
    """Retourne la meilleure offre business trouvée, ou None."""
    try:
        query = create_query(
            flights=[FlightQuery(
                date=departure_date,
                from_airport=origin,
                to_airport=destination,
            )],
            trip="one-way",
            seat="business",
            passengers=Passengers(adults=1),
            currency="EUR",
            language="fr",
        )
        results = get_flights(query)
    except Exception as exc:
        print(f"  ! {origin}->{destination} {departure_date} : {type(exc).__name__} {exc}")
        return None

    offers = [f for f in results if getattr(f, "price", None)]
    if not offers:
        return None

    best = min(offers, key=lambda f: f.price)
    legs = best.flights
    return {
        "price": float(best.price),
        "airlines": ", ".join(best.airlines) if best.airlines else "?",
        "stops": max(len(legs) - 1, 0),
        "duration": legs[0].duration if legs else "?",
    }


# --- Historique et détection ----------------------------------------------

def load_history():
    if HISTORY_FILE.exists():
        return json.loads(HISTORY_FILE.read_text())
    return {}


def save_history(history):
    HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    HISTORY_FILE.write_text(json.dumps(history, indent=2, ensure_ascii=False))


def is_anomaly(history_prices, price):
    """Un prix est une anomalie s'il casse nettement la médiane historique."""
    if len(history_prices) < MIN_OBSERVATIONS:
        return False, None
    median = statistics.median(history_prices)
    return price < median * ANOMALY_RATIO, median


# --- Notification ----------------------------------------------------------

def notify(message):
    print(message)
    if not TELEGRAM_TOKEN or not TELEGRAM_CHAT_ID:
        print("  (Telegram non configuré — alerte affichée dans les logs uniquement)")
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


def build_alert(origin, destination, dep_date, offer, median):
    reduction = round((1 - offer["price"] / median) * 100)
    gflights = (
        f"https://www.google.com/travel/flights?q=Flights%20to%20{destination}"
        f"%20from%20{origin}%20on%20{dep_date}%20business"
    )
    stops = "direct" if offer["stops"] == 0 else f"{offer['stops']} escale(s)"
    return (
        f"*Alerte Business — {origin} → {destination}*\n"
        f"Prix : *{offer['price']:.0f} €* (médiane : {median:.0f} €, soit -{reduction} %)\n"
        f"Départ : {dep_date} · {offer['airlines']} · {stops}\n\n"
        f"[Vérifier sur Google Flights]({gflights})\n"
        f"_Les tarifs anormaux tiennent rarement plus de quelques heures._"
    )


# --- Boucle principale -----------------------------------------------------

def scan_dates():
    today = date.today()
    d = today + timedelta(days=SCAN_START_DAYS)
    end = today + timedelta(days=SCAN_HORIZON_DAYS)
    while d <= end:
        yield d.isoformat()
        d += timedelta(days=SCAN_STEP_DAYS)


def main():
    routes = json.loads(ROUTES_FILE.read_text())
    history = load_history()
    alerts = 0
    found = 0

    for route in routes:
        origin = route["origin"]
        destination = route["destination"]
        key = f"{origin}-{destination}"
        history.setdefault(key, {"observations": []})
        prices = [o["price"] for o in history[key]["observations"]]

        print(f"\n=== {key} ({route.get('label', '')}) ===")
        for dep_date in scan_dates():
            offer = search_offer(origin, destination, dep_date)
            time.sleep(DELAY_SECONDS)
            if not offer:
                continue

            found += 1
            print(f"  {dep_date} : {offer['price']:.0f} € ({offer['airlines']})")

            anomaly, median = is_anomaly(prices, offer["price"])
            if anomaly:
                notify(build_alert(origin, destination, dep_date, offer, median))
                alerts += 1

            history[key]["observations"].append({
                "date": datetime.utcnow().isoformat(timespec="seconds"),
                "departure_date": dep_date,
                "price": offer["price"],
                "airlines": offer["airlines"],
                "stops": offer["stops"],
            })

        # On ne garde que les 400 dernières observations par route
        history[key]["observations"] = history[key]["observations"][-400:]

    save_history(history)
    print(f"\nTerminé : {found} prix relevés, {alerts} alerte(s).")

    if found == 0:
        print("Aucun prix relevé — Google a probablement bloqué les requêtes. "
              "Augmente DELAY_SECONDS ou réduis le nombre de routes.")


if __name__ == "__main__":
    main()
