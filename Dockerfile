FROM python:3.11-slim

WORKDIR /app

# Installera systempaket
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Kopiera requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopiera applikationskod
COPY . .

EXPOSE 5000

# Vänta på databas och starta sedan appen
CMD ["python", "webhook_receiver.py"]


