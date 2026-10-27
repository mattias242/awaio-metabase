import os
import requests

# Get an access token with OAuth2 client credentials
def get_access_token():
    token_url = 'https://api.awaio.com/auth/token'
    client_id = os.getenv('AWAIO_CLIENT_ID', 'your_client_id')
    client_secret = os.getenv('AWAIO_CLIENT_SECRET', 'your_client_secret')
    data = {
        'grant_type': 'client_credentials'
    }
    response = requests.post(token_url, data=data, auth=(client_id, client_secret))
    response.raise_for_status()
    token = response.json().get("access_token")
    if not token:
        raise Exception("No access token returned!")
    return token

# Activate an Awaio subscription
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
        'timeLimit': time_limit  # seconds, max 259200 (= 3 days) without alias
    }
    response = requests.post(api_url, json=payload, headers=headers)
    print("Status:", response.status_code)
    print("Response:", response.text)
    if response.ok:
        print("Subscription activated - the webhook is now live!")
    else:
        print("Error: check the settings and API permissions.")

if __name__ == "__main__":
    # Adjust these variables!
    channel = 'entities/123456'                # Change to the right channel/resource
    notification_url = 'https://your-domain.example/webhook/awaio'  # Change to your webhook URL
    time_limit = 86400                         # 1 day (can be changed)
    activate_subscription(channel, notification_url, time_limit)

