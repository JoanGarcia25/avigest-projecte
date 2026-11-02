FROM python:3.12-alpine
WORKDIR /app
RUN pip install --no-cache-dir paho-mqtt==2.1.0 psycopg2-binary==2.9.10
COPY mqtt_a_postgres.py /app/mqtt_a_postgres.py
CMD ["python", "-u", "/app/mqtt_a_postgres.py"]
