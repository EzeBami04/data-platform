FROM apache/airflow:3.2.0-python3.12

USER root

# Install OS packages if needed
RUN apt-get update && apt-get install -y \
    git \
    gcc \
    g++ \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Install Python dependencies
COPY requirements.txt /tmp/requirements.txt

RUN pip install --no-cache-dir \
    --upgrade pip \
    -r /tmp/requirements.txt

# Copy project code
COPY airflow/dags /opt/airflow/dags
# COPY airflow/plugins /opt/airflow/plugins
# COPY airflow/include /opt/airflow/include
COPY python /opt/python
COPY sql/qntplatform /opt/airflow/dbt
COPY infrastructure/docker/entrypoint.sh /opt/airflow/entrypoint.sh
RUN chmod +x /opt/airflow/entrypoint.sh


ENV PYTHONPATH="/opt/airflow/python:${PYTHONPATH}"
ENTRYPOINT ["/opt/airflow/entrypoint.sh"]

WORKDIR /opt/airflow
