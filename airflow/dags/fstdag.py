from airflow import DAG
from airflow.operators import BashOperator
from airflow.utils.dates import days_ago

with DAG(
    dag_id='dbt_transformations',
    schedule_interval='@daily',
    start_date=days_ago(1),
    catchup=False,
    tags=['dbt', 'transform'],
) as dag:
    install_deps = BashOperator(
        task_id='dbt_deps',
        bash_command='cd /opt/airflow/dbt && dbt deps',
    )

    run_dbt = BashOperator(
        task_id='dbt_run',
        bash_command='cd /opt/airflow/dbt && dbt run --profiles-dir /opt/airflow/dbt',
    )

    test_dbt = BashOperator(
        task_id='dbt_test',
        bash_command='cd /opt/airflow/dbt && dbt test --profiles-dir /opt/airflow/dbt',
    )

    install_deps >> run_dbt >> test_dbt

