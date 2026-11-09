FROM python:3.12-alpine
WORKDIR /app
RUN pip install --no-cache-dir paho-mqtt==2.1.0 pymysql==1.1.1 cryptography==43.0.3
COPY mqtt_a_mariadb.py /app/mqtt_a_mariadb.py
CMD ["python", "-u", "/app/mqtt_a_mariadb.py"]
