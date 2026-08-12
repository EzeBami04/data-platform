from airflow import DAG
from airflow.providers.standard.operators.bash import BashOperator

from datetime import datetime, timedelta

with DAG(
    dag_id='dbt_transformations',
    schedule='@daily',                          
    start_date=datetime(2025, 1, 1),  
    catchup=False,
    tags=['dbt', 'transform'],
    ) as dag:
    install_deps = BashOperator(
        task_id='dbt_deps',
        bash_command='cd /opt/sql/qntplatform && dbt deps',
    )

    run_dbt = BashOperator(
        task_id='dbt_run',
        bash_command='cd /opt/sql/qntplatform && dbt run --profiles-dir /opt/sql/qntplatform',
    )

    test_dbt = BashOperator(
        task_id='dbt_test',
        bash_command='cd /opt/sql/qntplatform && dbt test --profiles-dir /opt/sql/qntplatform',
    )

    install_deps >> run_dbt >> test_dbt