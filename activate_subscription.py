import os
import requests

# Hämta access token med OAuth2 client credentials
def get_access_token():
    token_url = 'https://api.awaio.com/auth/token'
    client_id = os.getenv('AWAIO_CLIENT_ID', 'din_client_id')
    client_secret = os.getenv('AWAIO_CLIENT_SECRET', 'ditt_client_secret')
    data = {
        'grant_type': 'client_credentials'
    }
    response = requests.post(token_url, data=data, auth=(client_id, client_secret))
    response.raise_for_status()
    token = response.json().get("access_token")
    if not token:
        raise Exception("Ingen access token returnerad!")
    return token

# Aktivera Awaios subscription
def activate_subscription(channel, notification_url, time_limit=86400):
    access_token = get_access_token()
    api_url = 'https://api.awaio.com/v1.0.0/subscriptions'
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    payload = {
        'channel': channel,
        'notificationUrl': notification_url,
        'timeLimit': time_limit  # sekunder, max 259200 (= 3 dagar) utan alias
    }
    response = requests.post(api_url, json=payload, headers=headers)
    print("Status:", response.status_code)
    print("Response:", response.text)
    if response.ok:
        print("Prenumeration aktiverad – webhook är nu live!")
    else:
        print("Fel: Kontrollera inställningar och API-behörigheter.")

if __name__ == "__main__":
    # Anpassa dessa variabler!
    channel = 'entities/123456'                # Byt till rätt kanal/resurs
    notification_url = 'https://din-domän.se/webhook/awaio'  # Byt till din webhook-URL
    time_limit = 86400                         # 1 dag (kan ändras)
    activate_subscription(channel, notification_url, time_limit)

